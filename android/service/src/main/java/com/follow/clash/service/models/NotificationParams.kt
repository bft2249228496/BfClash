package com.lansway.client.service.models

data class NotificationParams(
    val title: String = "澜序",
    val stopText: String = "STOP",
    val onlyStatisticsProxy: Boolean = false,
    val showStopAction: Boolean = true,
)
