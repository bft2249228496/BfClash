package com.lansway.client

import android.app.Activity
import android.os.Bundle
import androidx.core.content.pm.ShortcutManagerCompat
import com.lansway.client.common.GlobalState
import com.lansway.client.common.QuickAction
import com.lansway.client.common.action
import kotlinx.coroutines.launch

class QuickActionActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        when (intent.action) {
            QuickAction.START.action -> GlobalState.launch { ServiceState.handleStartAction() }
            QuickAction.STOP.action -> GlobalState.launch { ServiceState.handleStopAction() }
            QuickAction.TOGGLE.action -> {
                ShortcutManagerCompat.reportShortcutUsed(this, SHORTCUT_ID)
                GlobalState.launch { ServiceState.handleToggleAction() }
            }
        }
        finish()
    }

    private companion object {
        const val SHORTCUT_ID = "toggle"
    }
}
