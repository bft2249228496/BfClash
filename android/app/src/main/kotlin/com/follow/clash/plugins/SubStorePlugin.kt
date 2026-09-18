package com.lansway.client.plugins

import android.content.Context
import com.lansway.client.common.Components
import com.lansway.client.substore.SubStoreBackendController
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class SubStorePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(
            binding.binaryMessenger,
            "${Components.PACKAGE_NAME}/sub-store",
        )
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> result.success(SubStoreBackendController.status())
            "start" -> runCatching {
                SubStoreBackendController.start(context)
                SubStoreBackendController.status()
            }.fold(
                onSuccess = result::success,
                onFailure = { error ->
                    result.error("SUB_STORE_START_FAILED", error.message, null)
                },
            )
            "stop" -> runCatching {
                SubStoreBackendController.stop(context)
                SubStoreBackendController.status()
            }.fold(
                onSuccess = result::success,
                onFailure = { error ->
                    result.error("SUB_STORE_STOP_FAILED", error.message, null)
                },
            )
            else -> result.notImplemented()
        }
    }
}
