package com.follow.clash.core

import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.URI

object Core {
    private external fun startTun(
        fd: Int,
        cb: TunInterface,
        stack: String,
        address: String,
        dns: String,
    ): Boolean

    external fun stopTun()
    external fun forceGC()
    external fun updateDNS(dns: String)
    external fun suspended(suspended: Boolean)

    private fun parseInetSocketAddress(address: String): InetSocketAddress {
        return try {
            val uri = URI("tcp://$address")
            val host = uri.host ?: "127.0.0.1"
            val port = if (uri.port >= 0) uri.port else 0
            InetSocketAddress(InetAddress.getByName(host), port)
        } catch (_: Exception) {
            InetSocketAddress(InetAddress.getLoopbackAddress(), 0)
        }
    }

    fun startTun(
        fd: Int,
        protect: (Int) -> Boolean,
        resolveUid: (protocol: Int, source: InetSocketAddress, target: InetSocketAddress) -> Int,
        resolvePackage: (uid: Int) -> String,
        stack: String,
        address: String,
        dns: String,
    ): Boolean {
        return startTun(
            fd,
            object : TunInterface {
                override fun protect(fd: Int): Boolean = protect(fd)

                override fun resolveUid(
                    protocol: Int,
                    source: String,
                    target: String,
                ): Int {
                    return resolveUid(
                        protocol,
                        parseInetSocketAddress(source),
                        parseInetSocketAddress(target),
                    )
                }

                override fun resolvePackage(uid: Int): String = resolvePackage(uid)
            },
            stack,
            address,
            dns,
        )
    }

    private external fun invokeMethod(
        data: String,
        cb: InvokeInterface,
    )

    fun invokeMethod(
        data: String,
        cb: (result: String?) -> Unit,
    ) {
        invokeMethod(
            data,
            object : InvokeInterface {
                override fun onResult(result: String?) {
                    cb(result)
                }
            },
        )
    }

    private external fun quickSetup(
        initParamsString: String,
        setupParamsString: String,
        cb: InvokeInterface,
    )

    fun quickSetup(
        initParamsString: String,
        setupParamsString: String,
        callback: (result: String?) -> Unit,
    ) {
        quickSetup(
            initParamsString,
            setupParamsString,
            object : InvokeInterface {
                override fun onResult(result: String?) {
                    callback(result)
                }
            },
        )
    }

    external fun getTraffic(onlyStatisticsProxy: Boolean): String
    external fun getTotalTraffic(onlyStatisticsProxy: Boolean): String

    init {
        try {
            System.loadLibrary("core")
        } catch (e: Throwable) {
            android.util.Log.e("Core", "Failed to load libcore: ${e.message}")
        }
    }
}
