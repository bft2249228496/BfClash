package com.bfclash.client.service.modules

import android.app.Service
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkCapabilities.TRANSPORT_SATELLITE
import android.net.NetworkCapabilities.TRANSPORT_USB
import android.net.NetworkRequest
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.content.getSystemService
import com.bfclash.client.core.Core
import java.net.Inet4Address
import java.net.Inet6Address
import java.net.InetAddress
import java.util.concurrent.ConcurrentHashMap

private data class NetworkInfo(
    @Volatile var losingUntilMillis: Long = 0,
    @Volatile var dnsList: List<InetAddress> = emptyList(),
    @Volatile var linkIdentity: String? = null,
) {
    val priorityPenalty: Int
        get() = if (losingUntilMillis > System.currentTimeMillis()) 10 else 0
}

internal class NetworkObserveModule(
    private val service: Service,
    private val recoverTunnel: (() -> Unit)? = null,
) : ServiceModule {

    private val networkInfos = ConcurrentHashMap<Network, NetworkInfo>()
    private val connectivity by lazy {
        service.getSystemService<ConnectivityManager>()
    }
    private val mainHandler = Handler(Looper.getMainLooper())
    private var currentDnsList = listOf<String>()
    private var upstreamIdentity: String? = null
    private var upstreamChanges = UpstreamChangePolicy()
    @Volatile
    private var started = false
    private val recover = Runnable {
        if (started) recoverTunnel?.invoke()
    }

    private val request = NetworkRequest.Builder().apply {
        addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
        addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            addCapability(NetworkCapabilities.NET_CAPABILITY_FOREGROUND)
        }
        addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_RESTRICTED)
    }.build()

    private val callback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            networkInfos[network] = NetworkInfo()
            updateDns()
        }

        override fun onLosing(network: Network, maxMsToLive: Int) {
            val info = networkInfos[network] ?: return
            info.losingUntilMillis = System.currentTimeMillis() + maxMsToLive
            updateDns()
            if (maxMsToLive > 0) {
                mainHandler.postDelayed({
                    if (networkInfos.containsKey(network)) {
                        updateDns()
                    }
                }, maxMsToLive.toLong() + 50)
            }
        }

        override fun onLost(network: Network) {
            networkInfos.remove(network)
            updateDns()
        }

        override fun onLinkPropertiesChanged(network: Network, linkProperties: LinkProperties) {
            networkInfos[network]?.apply {
                dnsList = linkProperties.dnsServers
                linkIdentity = listOf(
                    network.toString(),
                    linkProperties.interfaceName.orEmpty(),
                    linkProperties.linkAddresses.map { it.toString() }.sorted().joinToString(),
                    linkProperties.routes.map { it.toString() }.sorted().joinToString(),
                    linkProperties.mtu.toString(),
                ).joinToString("|")
            }
            updateDns()
        }

        override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) {
            updateDns()
        }
    }

    override fun start() {
        started = true
        updateDns()
        connectivity?.registerNetworkCallback(request, callback)
    }

    private fun networkPriority(entry: Map.Entry<Network, NetworkInfo>): Int {
        val capabilities = connectivity?.getNetworkCapabilities(entry.key)
        return when {
            capabilities == null -> 100
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN) -> 90
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> 0
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> 1
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                capabilities.hasTransport(TRANSPORT_USB) -> 2

            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_BLUETOOTH) -> 3
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> 4
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM &&
                capabilities.hasTransport(TRANSPORT_SATELLITE) -> 5

            else -> 20
        } + entry.value.priorityPenalty + if (
            capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) == true
        ) 0 else 30
    }

    @Synchronized
    private fun updateDns() {
        val selected = networkInfos.asSequence()
            .filter { it.value.linkIdentity != null }
            .minByOrNull(::networkPriority)
        val identity = selected?.value?.linkIdentity
        if (identity != upstreamIdentity) {
            upstreamIdentity = identity
            mainHandler.removeCallbacks(recover)
            if (upstreamChanges.update(identity)) {
                mainHandler.postDelayed(recover, 1_500)
            }
        }
        val dnsList = selected?.value
            ?.dnsList
            .orEmpty()
            .map { address -> address.asSocketAddressText(DNS_PORT) }
            .distinct()
        if (dnsList == currentDnsList) {
            return
        }
        currentDnsList = dnsList
        Core.updateDNS(dnsList.joinToString(","))
    }

    override fun stop() {
        started = false
        mainHandler.removeCallbacksAndMessages(null)
        try {
            connectivity?.unregisterNetworkCallback(callback)
        } finally {
            networkInfos.clear()
            upstreamIdentity = null
            upstreamChanges = UpstreamChangePolicy()
            updateDns()
        }
    }
}

private const val DNS_PORT = 53

private fun InetAddress.asSocketAddressText(port: Int): String = when (this) {
    is Inet6Address -> "[$hostAddress]:$port"
    is Inet4Address -> "$hostAddress:$port"
    else -> error("Unsupported address type: ${javaClass.name}")
}
