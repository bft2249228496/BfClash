package com.bfclash.client.service.modules

import android.os.SystemClock
import com.bfclash.client.common.GlobalState
import com.bfclash.client.service.ServiceConfig
import java.net.HttpURLConnection
import java.net.InetSocketAddress
import java.net.Proxy
import java.net.URL
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

internal class TunnelHealthModule(
    private val scope: CoroutineScope,
    private val recover: () -> Unit,
) : ServiceModule {
    private var job: Job? = null

    override fun start() {
        job = scope.launch {
            val policy = TunnelRecoveryPolicy()
            while (isActive) {
                delay(60_000)
                val port = ServiceConfig.vpnOptions?.port ?: continue
                val result = withContext(Dispatchers.IO) {
                    probePaths(port)
                }
                if (isActive && policy.record(result.first, result.second, SystemClock.elapsedRealtime())) {
                    GlobalState.log("VPN health: tunnel failed twice while local proxy works")
                    recover()
                }
            }
        }
    }

    private fun probePaths(port: Int): Pair<Boolean, Boolean> {
        val proxy = Proxy(Proxy.Type.HTTP, InetSocketAddress("127.0.0.1", port))
        var proxyWorks = false
        for (endpoint in ENDPOINTS) {
            if (probe(endpoint, Proxy.NO_PROXY)) return true to false
            proxyWorks = probe(endpoint, proxy) || proxyWorks
        }
        return false to proxyWorks
    }

    private fun probe(endpoint: String, proxy: Proxy): Boolean {
        var connection: HttpURLConnection? = null
        return try {
            connection = URL(endpoint).openConnection(proxy) as HttpURLConnection
            connection.connectTimeout = 4_000
            connection.readTimeout = 4_000
            connection.instanceFollowRedirects = false
            connection.useCaches = false
            connection.setRequestProperty("Connection", "close")
            connection.responseCode == 204
        } catch (_: Exception) {
            false
        } finally {
            connection?.disconnect()
        }
    }

    override fun stop() {
        job?.cancel()
        job = null
    }

    companion object {
        private val ENDPOINTS = listOf(
            "https://www.gstatic.com/generate_204",
            "https://cp.cloudflare.com/generate_204",
        )
    }
}
