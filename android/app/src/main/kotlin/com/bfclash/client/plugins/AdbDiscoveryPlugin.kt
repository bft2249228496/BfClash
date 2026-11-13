package com.bfclash.client.plugins

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.net.wifi.WifiManager
import android.os.Handler
import android.os.Looper
import com.bfclash.client.common.Components
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.net.NetworkInterface
import java.util.Collections

/** Temporary discovery of this device's Android wireless ADB services. */
class AdbDiscoveryPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var context: Context
    private lateinit var channel: MethodChannel
    private lateinit var nsd: NsdManager
    private val handler = Handler(Looper.getMainLooper())
    private val listeners = mutableListOf<NsdManager.DiscoveryListener>()
    private val pending = ArrayDeque<NsdServiceInfo>()
    private val live = mutableSetOf<String>()
    private val resolved = mutableMapOf<String, Int>()
    private var resolving = false
    private var generation = 0
    private var lock: WifiManager.MulticastLock? = null
    private val supported = setOf("_adb-tls-pairing._tcp.", "_adb-tls-connect._tcp.")

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        nsd = context.getSystemService(Context.NSD_SERVICE) as NsdManager
        channel = MethodChannel(binding.binaryMessenger, "${Components.PACKAGE_NAME}/adb-discovery")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stop()
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> try { start(); result.success(true) } catch (_: Exception) { stop(); result.error("DISCOVERY_FAILED", "Unable to discover wireless debugging", null) }
            "stop" -> { stop(); result.success(true) }
            else -> result.notImplemented()
        }
    }

    private fun key(info: NsdServiceInfo): String = "${info.serviceType}|${info.serviceName}"

    private fun start() {
        stop()
        val current = ++generation
        val wifi = context.getSystemService(Context.WIFI_SERVICE) as WifiManager
        lock = wifi.createMulticastLock("bfclash-adb-discovery").apply { setReferenceCounted(false); acquire() }
        for (type in supported) {
            val listener = object : NsdManager.DiscoveryListener {
                override fun onDiscoveryStarted(serviceType: String) {}
                override fun onDiscoveryStopped(serviceType: String) {}
                override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) { handler.post { if (generation == current) channel.invokeMethod("error", null) } }
                override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {}
                override fun onServiceFound(service: NsdServiceInfo) { handler.post {
                    if (generation != current) return@post
                    val key = key(service)
                    if (live.add(key)) { pending.addLast(service); resolveNext(current) }
                } }
                override fun onServiceLost(service: NsdServiceInfo) { handler.post {
                    if (generation != current) return@post
                    val key = key(service)
                    live.remove(key)
                    val port = resolved.remove(key)
                    if (port != null && !resolved.containsValue(port)) channel.invokeMethod("lost", port)
                } }
            }
            listeners.add(listener)
            nsd.discoverServices(type, NsdManager.PROTOCOL_DNS_SD, listener)
        }
        handler.postDelayed({ if (generation == current) { stop(); channel.invokeMethod("expired", null) } }, 60 * 60 * 1000L)
    }

    @Suppress("DEPRECATION")
    private fun resolveNext(current: Int) {
        if (resolving || generation != current) return
        val service = pending.removeFirstOrNull() ?: return
        if (!live.contains(key(service))) { resolveNext(current); return }
        resolving = true
        try {
            nsd.resolveService(service, object : NsdManager.ResolveListener {
                override fun onResolveFailed(serviceInfo: NsdServiceInfo, errorCode: Int) { handler.post { if (generation == current) { resolving = false; resolveNext(current) } } }
                override fun onServiceResolved(serviceInfo: NsdServiceInfo) { handler.post {
                    if (generation != current) return@post
                    resolving = false
                    val key = key(service)
                    if (live.contains(key) && serviceInfo.port in 1..65535 && isLocalAddress(serviceInfo.host?.hostAddress)) {
                        val alreadyKnown = resolved.containsValue(serviceInfo.port)
                        resolved[key] = serviceInfo.port
                        if (!alreadyKnown) channel.invokeMethod(if (service.serviceType == "_adb-tls-connect._tcp.") "foundConnect" else "found", serviceInfo.port)
                    }
                    resolveNext(current)
                } }
            })
        } catch (_: Exception) { resolving = false; resolveNext(current) }
    }

    private fun isLocalAddress(address: String?): Boolean {
        if (address == null) return false
        return try {
            Collections.list(NetworkInterface.getNetworkInterfaces()).any { nic ->
                Collections.list(nic.inetAddresses).any { it.hostAddress?.substringBefore('%') == address.substringBefore('%') }
            }
        } catch (_: Exception) { false }
    }

    private fun stop() {
        generation++
        listeners.forEach { try { nsd.stopServiceDiscovery(it) } catch (_: Exception) {} }
        listeners.clear(); pending.clear(); live.clear(); resolved.clear(); resolving = false
        lock?.let { if (it.isHeld) it.release() }; lock = null
    }
}
