package com.lansway.client.substore

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import ano.subcase.engine.BackendFiles
import ano.subcase.engine.CaseEngine
import com.lansway.client.MainActivity
import com.lansway.client.R

enum class SubStoreBackendPhase {
    STOPPED,
    STARTING,
    RUNNING,
    FAILED,
}

object SubStoreBackendController {
    const val BACKEND_PORT = 3001
    const val FRONTEND_PORT = 3002
    const val ENDPOINT = "http://127.0.0.1:$BACKEND_PORT"

    @Volatile
    var phase = SubStoreBackendPhase.STOPPED
        private set

    @Volatile
    var error: String? = null
        private set

    fun start(context: Context) {
        if (phase == SubStoreBackendPhase.STARTING || phase == SubStoreBackendPhase.RUNNING) return
        phase = SubStoreBackendPhase.STARTING
        error = null
        ContextCompat.startForegroundService(
            context.applicationContext,
            Intent(context, SubStoreBackendService::class.java),
        )
    }

    fun stop(context: Context) {
        context.applicationContext.stopService(Intent(context, SubStoreBackendService::class.java))
        phase = SubStoreBackendPhase.STOPPED
        error = null
    }

    internal fun running() {
        phase = SubStoreBackendPhase.RUNNING
        error = null
    }

    internal fun failed(cause: Throwable) {
        phase = SubStoreBackendPhase.FAILED
        error = cause.message ?: cause.javaClass.simpleName
    }

    internal fun stopped() {
        if (phase != SubStoreBackendPhase.FAILED) phase = SubStoreBackendPhase.STOPPED
    }

    fun status(): Map<String, Any?> = mapOf(
        "phase" to phase.name.lowercase(),
        "endpoint" to ENDPOINT,
        "backendVersion" to BackendFiles.BUNDLED_VERSION,
        "error" to error,
    )
}

class SubStoreBackendService : Service() {
    private var engine: CaseEngine? = null

    override fun onCreate() {
        super.onCreate()
        check(Looper.myLooper() == Looper.getMainLooper())
        startForeground(NOTIFICATION_ID, createNotification())
        try {
            BackendFiles.ensureInstalled(this)
            engine = CaseEngine(
                context = this,
                backendPort = SubStoreBackendController.BACKEND_PORT,
                frontendPort = SubStoreBackendController.FRONTEND_PORT,
                host = "127.0.0.1",
                onFailure = { _, error ->
                    SubStoreBackendController.failed(error)
                    stopSelf()
                },
            ).also(CaseEngine::startServer)
            SubStoreBackendController.running()
        } catch (error: Throwable) {
            SubStoreBackendController.failed(error)
            stopSelf()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_NOT_STICKY

    override fun onDestroy() {
        try {
            engine?.stopServer()
        } catch (error: Throwable) {
            SubStoreBackendController.failed(error)
        } finally {
            engine = null
            SubStoreBackendController.stopped()
            super.onDestroy()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotification(): Notification {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Sub-Store backend",
                    NotificationManager.IMPORTANCE_LOW,
                ),
            )
        }
        val launchIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("BfClash Sub-Store")
            .setContentText("Local backend is available at ${SubStoreBackendController.ENDPOINT}")
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setSilent(true)
            .build()
    }

    companion object {
        private const val CHANNEL_ID = "bfclash_substore_backend"
        private const val NOTIFICATION_ID = 0x5353
    }
}
