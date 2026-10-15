package com.bfclash.client.service.modules

internal class TunnelRecoveryPolicy(
    private val threshold: Int = 2,
    private val cooldownMillis: Long = 300_000,
) {
    private var failures = 0
    private var lastRecovery: Long? = null

    fun record(tunnelWorks: Boolean, proxyWorks: Boolean, nowMillis: Long): Boolean {
        if (tunnelWorks || !proxyWorks) {
            failures = 0
            return false
        }
        failures++
        if (failures < threshold) return false
        val previous = lastRecovery
        if (previous != null && nowMillis - previous < cooldownMillis) return false
        failures = 0
        lastRecovery = nowMillis
        return true
    }
}
