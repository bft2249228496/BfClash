package com.lansway.client

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val METHOD_CHANNEL = "com.lansway.client/vpn_control"
        const val EVENT_CHANNEL = "com.lansway.client/vpn_status"
        const val INSTALL_CHANNEL = "com.lansway.client/app_installer"
        const val REQUEST_CODE_VPN_PREPARE = 1002
    }

    private var pendingConfigContent: String? = null
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. 状态事件流：让 Flutter 实时监听真实 VPN 状态
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    LanswayVpnService.setStatusListener { status ->
                        runOnUiThread {
                            events?.success(status)
                        }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    LanswayVpnService.setStatusListener(null)
                }
            }
        )

        // 2. 控制方法通道：启动、断开、状态查询
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getFilesDir" -> {
                    result.success(filesDir.absolutePath)
                }
                "getStatus" -> {
                    result.success(LanswayVpnService.currentStatus)
                }
                "startVpn" -> {
                    val config = call.argument<String>("config") ?: ""
                    if (config.isBlank()) {
                        result.error("EMPTY_CONFIG", "启动 VPN 需要提供有效的配置文件，拒绝启动空 TUN", null)
                        return@setMethodCallHandler
                    }

                    if (LanswayVpnService.isServiceRunning) {
                        result.success(true)
                        return@setMethodCallHandler
                    }

                    val prepareIntent = VpnService.prepare(this)
                    if (prepareIntent != null) {
                        pendingConfigContent = config
                        pendingResult = result
                        startActivityForResult(prepareIntent, REQUEST_CODE_VPN_PREPARE)
                    } else {
                        startVpnServiceInternal(config)
                        result.success(true)
                    }
                }
                "stopVpn" -> {
                    val stopIntent = Intent(this, LanswayVpnService::class.java).apply {
                        action = LanswayVpnService.ACTION_STOP
                    }
                    startService(stopIntent)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // 3. 应用在线更新安装通道
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INSTALL_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "installApk") {
                val filePath = call.argument<String>("filePath")
                if (filePath.isNullOrBlank()) {
                    result.error("INVALID_PATH", "APK 路径为空", null)
                    return@setMethodCallHandler
                }
                try {
                    val srcFile = java.io.File(filePath)
                    if (!srcFile.exists()) {
                        result.error("FILE_NOT_FOUND", "APK 文件不存在: $filePath", null)
                        return@setMethodCallHandler
                    }

                    // 检查 Android 8.0+ 未知应用安装权限
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                        if (!packageManager.canRequestPackageInstalls()) {
                            val permissionIntent = Intent(android.provider.Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                                data = android.net.Uri.parse("package:$packageName")
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(permissionIntent)
                        }
                    }

                    // 规范化并拷贝到内部 cacheDir 确保 FileProvider 100% 匹配可用
                    val targetApk = java.io.File(cacheDir, "lansway_update.apk")
                    if (srcFile.canonicalPath != targetApk.canonicalPath) {
                        srcFile.copyTo(targetApk, overwrite = true)
                    }

                    val uri = androidx.core.content.FileProvider.getUriForFile(
                        this@MainActivity,
                        "${applicationContext.packageName}.fileprovider",
                        targetApk
                    )

                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
                        setDataAndType(uri, "application/vnd.android.package-archive")
                    }
                    startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("INSTALL_ERROR", e.message ?: "拉起安装器失败", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun startVpnServiceInternal(config: String) {
        val startIntent = Intent(this, LanswayVpnService::class.java).apply {
            action = LanswayVpnService.ACTION_START
            putExtra(LanswayVpnService.EXTRA_CONFIG_CONTENT, config)
        }
        startService(startIntent)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_VPN_PREPARE) {
            val result = pendingResult
            val config = pendingConfigContent
            pendingResult = null
            pendingConfigContent = null

            if (resultCode == Activity.RESULT_OK && config != null) {
                startVpnServiceInternal(config)
                result?.success(true)
            } else {
                result?.error("PERMISSION_DENIED", "用户未授予 VPN 权限", null)
            }
        }
    }
}
