package com.lansway.client.common

import android.content.ComponentName

object Components {
    const val PACKAGE_NAME = "com.lansway.client"

    val mainActivity =
        ComponentName(GlobalState.packageName, "${GlobalState.packageName}.MainActivity")

    val quickActionActivity =
        ComponentName(GlobalState.packageName, "${GlobalState.packageName}.QuickActionActivity")

    val serviceBroadcastReceiver =
        ComponentName(GlobalState.packageName, "${GlobalState.packageName}.ServiceBroadcastReceiver")
}
