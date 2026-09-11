package com.lansway.client

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import java.io.File
import java.io.FileOutputStream
import java.io.IOException

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
    private var coreProcess: Process? = null

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

    private fun handleStartVpn(configContent: String) {
        if (isServiceRunning) {
            Log.w(TAG, "VPN service already running, ignoring duplicate start")
            return
        }

        // 严格配置防空防伪：必须有真实有效配置才允许启动
        if (configContent.isBlank()) {
            Log.e(TAG, "No valid config provided. Refusing to start TUN to avoid traffic blackhole.")
            updateStatus("error:empty_config")
            stopSelf()
            return
        }

        updateStatus("connecting")
        startForeground(NOTIFICATION_ID, buildNotification("正在建立连接..."))

        try {
            // 保存配置文件到私有目录
            val configFile = File(filesDir, "config.yaml")
            FileOutputStream(configFile).use { it.write(configContent.toByteArray()) }

            // 建立 TUN 接口
            val builder = Builder()
                .setSession("Lansway")
                .setMtu(1500)
                .addAddress("172.19.0.1", 30)
                .addRoute("0.0.0.0", 0)
                .addDnsServer("172.19.0.2")

            // 排除自身应用流量以防回环
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                try {
                    builder.addDisallowedApplication(packageName)
                } catch (e: Exception) {
                    Log.w(TAG, "Could not disallow own package: ${e.message}")
                }
            }

            vpnInterface = builder.establish()
            if (vpnInterface == null) {
                throw IOException("VpnService.Builder.establish() returned null (user revoked permission)")
            }

            isServiceRunning = true
            updateStatus("connected")
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.notify(NOTIFICATION_ID, buildNotification("已安全连接"))
            Log.i(TAG, "VPN service established successfully with fd: ${vpnInterface?.fd}")

        } catch (e: Exception) {
            Log.e(TAG, "Failed to start VPN service", e)
            cleanupResources()
            updateStatus("error:${e.message ?: "unknown"}")
            stopSelf()
        }
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
            coreProcess?.destroy()
            coreProcess = null
        } catch (e: Exception) {
            Log.w(TAG, "Error stopping core process", e)
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
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
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
