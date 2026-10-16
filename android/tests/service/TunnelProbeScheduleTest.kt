package com.bfclash.client.service.modules

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TunnelProbeScheduleTest {
    @Test
    fun interactiveDeviceRetainsMinuteChecks() {
        val schedule = TunnelProbeSchedule(0)
        assertFalse(schedule.shouldProbe(59_999, true, false, false))
        assertTrue(schedule.shouldProbe(60_000, true, false, false))
        assertFalse(schedule.shouldProbe(60_001, true, false, false))
        assertTrue(schedule.shouldProbe(120_000, true, false, false))
    }

    @Test
    fun healthyScreenOffDeviceUsesFiveMinuteChecks() {
        val schedule = TunnelProbeSchedule(0)
        for (time in listOf(60_000L, 120_000L, 180_000L, 240_000L)) {
            assertFalse(schedule.shouldProbe(time, false, false, false))
        }
        assertTrue(schedule.shouldProbe(300_000, false, false, false))
    }

    @Test
    fun deepIdleDoesNotSendProbesAndUnlockDoesNotWaitFiveMinutes() {
        val schedule = TunnelProbeSchedule(0)
        assertFalse(schedule.shouldProbe(600_000, false, true, false))
        assertFalse(schedule.shouldProbe(660_000, false, true, true))
        assertTrue(schedule.shouldProbe(660_001, true, false, false))
    }

    @Test
    fun suspectedTunnelFailureStillRetriesAtOneMinuteWhileScreenOff() {
        val schedule = TunnelProbeSchedule(0)
        assertTrue(schedule.shouldProbe(300_000, false, false, false))
        assertFalse(schedule.shouldProbe(359_999, false, false, true))
        assertTrue(schedule.shouldProbe(360_000, false, false, true))
    }
}
