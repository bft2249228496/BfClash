package com.bfclash.client.plugins

import org.junit.Assert.assertEquals
import org.junit.Assert.fail
import org.junit.Test

class ApkUpdatePolicyTest {
    private fun rejected(code: String, operation: () -> Unit) {
        try {
            operation()
            fail("Expected incompatible APK rejection")
        } catch (error: ApkUpdateRejected) {
            assertEquals(code, error.code)
        }
    }

    @Test
    fun `higher RC code cannot replace installed beta identity`() {
        rejected("APK_UPDATE_PACKAGE_MISMATCH") {
            ApkUpdatePolicy.validate("com.lansway.client.beta", 2057, "com.bfclash.client", 2061)
        }
    }

    @Test
    fun `same or lower build cannot repeat installation`() {
        for (candidate in listOf(2056L, 2057L)) {
            rejected("APK_UPDATE_NOT_NEWER") {
                ApkUpdatePolicy.validate("com.lansway.client.beta", 2057, "com.lansway.client.beta", candidate)
            }
        }
    }

    @Test
    fun `newer beta can replace old beta`() {
        ApkUpdatePolicy.validate("com.lansway.client.beta", 2057, "com.lansway.client.beta", 2062)
    }
}
