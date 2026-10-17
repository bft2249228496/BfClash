package com.bfclash.client.service.modules

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class ScreenOnUpdatesTest {
    @Test
    fun screenOffCancelsRefreshTicksAndParameterSampling() = runTest {
        val screen = MutableStateFlow(true)
        val values = MutableStateFlow("first")
        val seen = mutableListOf<String>()
        backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) {
            screenOnUpdates(screen, values).collect { seen += it }
        }
        runCurrent()
        assertEquals(listOf("first"), seen)
        advanceTimeBy(1_000)
        runCurrent()
        assertEquals(2, seen.size)
        screen.value = false
        runCurrent()
        values.value = "changed while locked"
        advanceTimeBy(60_000)
        runCurrent()
        assertEquals(2, seen.size)
        screen.value = true
        runCurrent()
        assertEquals("changed while locked", seen.last())
        assertEquals(3, seen.size)
    }

    @Test
    fun initiallyLockedDeviceDoesNotStartARefreshLoop() = runTest {
        val screen = MutableStateFlow(false)
        val values = MutableStateFlow("current")
        val seen = mutableListOf<String>()
        backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) {
            screenOnUpdates(screen, values).collect { seen += it }
        }
        advanceTimeBy(60_000)
        runCurrent()
        assertEquals(0, seen.size)
        screen.value = true
        runCurrent()
        assertEquals(listOf("current"), seen)
    }

    @Test
    fun repeatedScreenEventsDoNotCreateDuplicateTimers() = runTest {
        val screen = MutableStateFlow(true)
        val seen = mutableListOf<String>()
        backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) {
            screenOnUpdates(screen, MutableStateFlow("current")).collect { seen += it }
        }
        runCurrent()
        repeat(3) { screen.value = true }
        advanceTimeBy(1_000)
        runCurrent()
        assertEquals(2, seen.size)
    }
}
