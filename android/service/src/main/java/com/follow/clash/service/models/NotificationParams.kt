package com.lansway.client.service.models

data class NotificationParams(
    val title: String = "BfClash",
    val stopText: String = "STOP",
    val onlyStatisticsProxy: Boolean = false,
    val showStopAction: Boolean = true,
)
