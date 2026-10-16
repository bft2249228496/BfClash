package com.bfclash.client.service.modules

internal class TunnelProbeSchedule(private var lastProbeMillis: Long) {
    fun shouldProbe(nowMillis: Long, interactive: Boolean, idle: Boolean, suspicious: Boolean): Boolean {
        if (idle) return false
        val interval = if (interactive || suspicious) 60_000L else 300_000L
        if (nowMillis - lastProbeMillis < interval) return false
        lastProbeMillis = nowMillis
        return true
    }
}
