package com.example.mpesa_tracker

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class MpesaNotificationListenerService : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val notification = sbn.notification ?: return
        val extras = notification.extras ?: return

        val title = extras.getCharSequence("android.title")?.toString().orEmpty()
        val text = extras.getCharSequence("android.text")?.toString().orEmpty()
        val bigText = extras.getCharSequence("android.bigText")?.toString().orEmpty()
        val payload = listOf(title, text, bigText)
            .filter { it.isNotBlank() }
            .joinToString(" ")
            .trim()

        if (payload.isBlank()) return

        // Keep this broad so we catch STK/SMS app variations.
        val normalized = payload.lowercase()
        val isMpesa = normalized.contains("m-pesa") ||
            normalized.contains("mpesa") ||
            normalized.contains("ksh")

        if (isMpesa) {
            MainActivity.emitMpesaEvent(payload)
        }
    }
}
