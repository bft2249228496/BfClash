package com.lansway.client

import com.lansway.client.R

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.ConnectivityManager
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import com.follow.clash.core.Core
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.net.InetSocketAddress
import java.util.concurrent.ConcurrentHashMap

class LanswayVpnService : VpnService() {

    companion object {
        const val TAG = "LanswayVpnService"
        const val CHANNEL_ID = "lansway_vpn_channel"
        const val NOTIFICATION_ID = 1001

        const val ACTION_START = "com.lansway.client.ACTION_START"
        const val ACTION_STOP = "com.lansway.client.ACTION_STOP"
        const val EXTRA_CONFIG_CONTENT = "extra_config_content"

        @Volatile
        var isServiceRunning = false
            private set

        @Volatile
        var currentStatus = "disconnected"
            private set

        private var statusListener: ((String) -> Unit)? = null

        fun setStatusListener(listener: ((String) -> Unit)?) {
            statusListener = listener
            listener?.invoke(currentStatus)
        }

        private fun updateStatus(status: String) {
            currentStatus = status
            statusListener?.invoke(status)
        }
    }

    private var vpnInterface: ParcelFileDescriptor? = null
    private val connectivity by lazy {
        getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
    }
    private val uidPackageNameMap = ConcurrentHashMap<Int, String>()

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: return START_NOT_STICKY
        when (action) {
            ACTION_START -> {
                val config = intent.getStringExtra(EXTRA_CONFIG_CONTENT) ?: ""
                handleStartVpn(config)
            }
            ACTION_STOP -> {
                handleStopVpn()
            }
        }
        return START_NOT_STICKY
    }

    private fun resolveUid(
        protocol: Int,
        source: InetSocketAddress,
        target: InetSocketAddress,
    ): Int {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return -1
        }
        return connectivity?.getConnectionOwnerUid(protocol, source, target) ?: -1
    }

    private fun resolvePackage(uid: Int): String {
        val cached = uidPackageNameMap[uid]
        if (cached != null) return cached
        val packageName = packageManager
            ?.getPackagesForUid(uid)
            ?.firstOrNull()
            ?.takeIf { it.isNotEmpty() }
            .orEmpty()
        return uidPackageNameMap.putIfAbsent(uid, packageName) ?: packageName
    }

    private fun safeStartForeground(notification: Notification) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (t: Throwable) {
            Log.e(TAG, "Error starting foreground service: ${t.message}", t)
            try {
                startForeground(NOTIFICATION_ID, notification)
            } catch (_: Throwable) {}
        }
    }

    private fun handleStartVpn(configContent: String) {
        if (isServiceRunning) {
            Log.w(TAG, "VPN service already running, ignoring duplicate start")
            return
        }

        if (configContent.isBlank()) {
            Log.e(TAG, "No valid config provided. Refusing to start TUN.")
            updateStatus("error:empty_config")
            stopSelf()
            return
        }

        updateStatus("connecting")
        safeStartForeground(buildNotification("正在建立安全代理连接..."))

        Thread {
            try {
                // 1. 将配置文件写入私有目录
                val homeDir = filesDir.absolutePath
                val configFile = File(filesDir, "config.yaml")
                FileOutputStream(configFile).use { it.write(configContent.toByteArray()) }

                // 2. 检查并初始化 Core (如果在当前进程可用)
                if (Core.isLoaded) {
                    try {
                        val initJson = "{\"home-dir\":\"$homeDir\",\"version\":1}"
                        val setupJson = "{\"path\":\"${configFile.absolutePath}\"}"

                        var setupFinished = false
                        val setupLock = Object()

                        Core.quickSetup(initJson, setupJson) { result ->
                            synchronized(setupLock) {
                                setupFinished = true
                                setupLock.notifyAll()
                            }
                        }

                        synchronized(setupLock) {
                            setupLock.wait(4000)
                        }
                    } catch (t: Throwable) {
                        Log.w(TAG, "Core.quickSetup exception: ${t.message}", t)
                    }
                }

                // 3. 构建系统 TUN 网卡
                val builder = Builder()
                    .setSession("Lansway")
                    .setMtu(1500)
                    .addAddress("172.19.0.1", 30)
                    .addRoute("0.0.0.0", 0)
                    .addDnsServer("172.19.0.2")

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    try {
                        builder.addDisallowedApplication(packageName)
                    } catch (e: Exception) {
                        Log.w(TAG, "Could not disallow own package: ${e.message}")
                    }
                }

                val pfd = builder.establish()
                if (pfd == null) {
                    throw IOException("VpnService.Builder.establish() returned null (permission not granted)")
                }
                vpnInterface = pfd
                val fd = pfd.fd

                // 4. 将系统 TUN fd 注入 Core
                if (Core.isLoaded) {
                    try {
                        Core.startTun(
                            fd = fd,
                            protect = { socketFd -> protect(socketFd) },
                            resolveUid = this::resolveUid,
                            resolvePackage = this::resolvePackage,
                            stack = "gvisor",
                            address = "172.19.0.1/30",
                            dns = "172.19.0.2"
                        )
                    } catch (t: Throwable) {
                        Log.w(TAG, "Core.startTun exception: ${t.message}", t)
                    }
                }

                isServiceRunning = true
                updateStatus("connected")
                val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                manager.notify(NOTIFICATION_ID, buildNotification("已安全连接"))
                Log.i(TAG, "VPN service established with fd: $fd")

            } catch (t: Throwable) {
                Log.e(TAG, "Failed to start VPN service safely", t)
                cleanupResources()
                updateStatus("error:${t.message ?: "unknown"}")
                stopSelf()
            }
        }.start()
    }

    private fun handleStopVpn() {
        if (!isServiceRunning && currentStatus == "disconnected") {
            return
        }
        updateStatus("disconnecting")
        cleanupResources()
        updateStatus("disconnected")
        try {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } catch (_: Throwable) {}
        stopSelf()
        Log.i(TAG, "VPN service stopped cleanly")
    }

    private fun cleanupResources() {
        try {
            if (Core.isLoaded) {
                Core.stopTun()
            }
        } catch (e: Throwable) {
            Log.w(TAG, "Error stopping Core tun", e)
        }

        try {
            vpnInterface?.close()
            vpnInterface = null
        } catch (e: Throwable) {
            Log.w(TAG, "Error closing VPN interface", e)
        }

        isServiceRunning = false
    }

    override fun onDestroy() {
        cleanupResources()
        super.onDestroy()
    }

    override fun onRevoke() {
        Log.w(TAG, "VPN permission revoked by system or user")
        handleStopVpn()
        super.onRevoke()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "澜序连接状态",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "展示当前 VPN 核心服务运行与流量状态"
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(contentText: String): Notification {
        val launchIntent = packageManager?.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val stopIntent = Intent(this, LanswayVpnService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            1,
            stopIntent,
            PendingIntent.FLAG_IMMUTABLE
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setContentTitle("澜序 · Lansway")
            .setContentText(contentText)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            
            .setOngoing(true)
            .build()
    }
}
