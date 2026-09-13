package com.lansway.client

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
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

    private fun handleStartVpn(configContent: String) {
        if (isServiceRunning) {
            Log.w(TAG, "VPN service already running, ignoring duplicate start")
            return
        }

        if (configContent.isBlank()) {
            Log.e(TAG, "No valid config provided. Refusing to start TUN to avoid traffic blackhole.")
            updateStatus("error:empty_config")
            stopSelf()
            return
        }

        updateStatus("connecting")
        startForeground(NOTIFICATION_ID, buildNotification("正在建立安全代理连接..."))

        Thread {
            try {
                // 1. 将配置文件持久化写入私有目录
                val homeDir = filesDir.absolutePath
                val configFile = File(filesDir, "config.yaml")
                FileOutputStream(configFile).use { it.write(configContent.toByteArray()) }

                // 2. 调用 FlClash 内核 quickSetup 初始化 Mihomo
                val initJson = "{\"home-dir\":\"$homeDir\",\"version\":1}"
                val setupJson = "{\"path\":\"${configFile.absolutePath}\"}"

                var setupSuccess = false
                var setupErrorMsg = ""
                val setupLock = Object()

                Core.quickSetup(initJson, setupJson) { result ->
                    synchronized(setupLock) {
                        if (result.isNullOrEmpty()) {
                            setupSuccess = true
                        } else {
                            setupErrorMsg = result
                        }
                        setupLock.notifyAll()
                    }
                }

                synchronized(setupLock) {
                    setupLock.wait(5000)
                }

                if (!setupSuccess && setupErrorMsg.isNotEmpty()) {
                    Log.w(TAG, "quickSetup reported: $setupErrorMsg, proceeding to establish TUN")
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
                    throw IOException("VpnService.Builder.establish() returned null")
                }
                vpnInterface = pfd
                val fd = pfd.fd

                // 4. 将系统 TUN fd 真正注入 FlClash Mihomo 核心 (gvisor 用户态协议栈)
                val tunStarted = Core.startTun(
                    fd = fd,
                    protect = { socketFd -> protect(socketFd) },
                    resolveUid = this::resolveUid,
                    resolvePackage = this::resolvePackage,
                    stack = "gvisor",
                    address = "172.19.0.1/30",
                    dns = "172.19.0.2"
                )

                if (!tunStarted) {
                    Log.w(TAG, "Core.startTun returned false, but TUN fd was passed.")
                }

                isServiceRunning = true
                updateStatus("connected")
                val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                manager.notify(NOTIFICATION_ID, buildNotification("已安全连接 (Mihomo Core)"))
                Log.i(TAG, "VPN service established and hooked to Core with fd: $fd")

            } catch (e: Exception) {
                Log.e(TAG, "Failed to start VPN service", e)
                cleanupResources()
                updateStatus("error:${e.message ?: "unknown"}")
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
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        Log.i(TAG, "VPN service stopped cleanly")
    }

    private fun cleanupResources() {
        try {
            Core.stopTun()
        } catch (e: Throwable) {
            Log.w(TAG, "Error stopping Core tun", e)
        }

        try {
            vpnInterface?.close()
            vpnInterface = null
        } catch (e: Exception) {
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
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(pendingIntent)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "断开连接", stopPendingIntent)
            .setOngoing(true)
            .build()
    }
}
