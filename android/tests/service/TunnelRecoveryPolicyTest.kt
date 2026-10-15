package com.bfclash.client.service.modules

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TunnelRecoveryPolicyTest {
    @Test
    fun requiresConsecutiveFailuresWithWorkingProxy() {
        val policy = TunnelRecoveryPolicy()
        assertFalse(policy.record(false, true, 0))
        assertTrue(policy.record(false, true, 60_000))
    }

    @Test
    fun doesNotRestartForEndpointOrNodeOutage() {
        val policy = TunnelRecoveryPolicy()
        repeat(10) { assertFalse(policy.record(false, false, it * 60_000L)) }
    }

    @Test
    fun healthyTunnelClearsFailureStreak() {
        val policy = TunnelRecoveryPolicy()
        assertFalse(policy.record(false, true, 0))
        assertFalse(policy.record(true, false, 60_000))
        assertFalse(policy.record(false, true, 120_000))
        assertTrue(policy.record(false, true, 180_000))
    }

    @Test
    fun proxyFailureClearsFailureStreak() {
        val policy = TunnelRecoveryPolicy()
        assertFalse(policy.record(false, true, 0))
        assertFalse(policy.record(false, false, 60_000))
        assertFalse(policy.record(false, true, 120_000))
    }

    @Test
    fun repeatedFailuresCannotCauseRestartLoop() {
        val policy = TunnelRecoveryPolicy()
        assertFalse(policy.record(false, true, 0))
        assertTrue(policy.record(false, true, 60_000))
        for (time in listOf(120_000L, 180_000L, 240_000L, 300_000L)) {
            assertFalse(policy.record(false, true, time))
        }
        assertTrue(policy.record(false, true, 360_000))
    }

    @Test
    fun initialNetworkAndDnsOnlyUpdatesDoNotRestart() {
        val policy = UpstreamChangePolicy()
        assertFalse(policy.update(null))
        assertFalse(policy.update("wifi|address|route"))
        assertFalse(policy.update("wifi|address|route"))
        assertTrue(policy.update("cellular|address|route"))
    }

    @Test
    fun networkReturnRestartsEvenWithSameAddressAndDns() {
        val policy = UpstreamChangePolicy()
        assertFalse(policy.update("wifi"))
        assertFalse(policy.update(null))
        assertTrue(policy.update("wifi"))
    }

    @Test
    fun linkAddressChangeOnSameNetworkRestarts() {
        val policy = UpstreamChangePolicy()
        assertFalse(policy.update("wifi|address1"))
        assertTrue(policy.update("wifi|address2"))
    }
}
