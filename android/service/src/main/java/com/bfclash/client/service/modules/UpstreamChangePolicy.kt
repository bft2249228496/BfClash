package com.bfclash.client.service.modules

internal class UpstreamChangePolicy {
    private var initialized = false
    private var current: String? = null

    fun update(identity: String?): Boolean {
        if (identity == current) return false
        current = identity
        if (identity == null) return false
        val changed = initialized
        initialized = true
        return changed
    }
}
