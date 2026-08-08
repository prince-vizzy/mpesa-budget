package com.example.mpesa_tracker

import android.app.Notification
import android.content.ComponentName
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

class MpesaNotificationListenerService : NotificationListenerService() {

    private companion object {
        const val TAG = "MpesaListener"
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "Listener connected.")
        // Anything captured while Dart was down is still queued — drain it now.
        if (MpesaStore.pendingCount(applicationContext) > 0) {
            if (!MpesaChannels.pokeForeground()) {
                MpesaBackgroundEngine.wake(applicationContext)
            }
        }
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.w(TAG, "Listener disconnected — asking the system to rebind.")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            requestRebind(ComponentName(this, MpesaNotificationListenerService::class.java))
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        // Never react to our own "tap to categorize" alerts — their body contains
        // "Ksh", which would otherwise feed straight back into the parser.
        if (sbn.packageName == packageName) return

        val extras = sbn.notification?.extras ?: return

        val payload = listOf(
            extras.getCharSequence(Notification.EXTRA_TITLE),
            extras.getCharSequence(Notification.EXTRA_TEXT),
            extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
        ).mapNotNull { it?.toString() }
            .filter { it.isNotBlank() }
            .joinToString(" ")
            .trim()

        if (payload.isBlank()) return

        // Keep this broad so we catch STK/SMS app variations.
        val normalized = payload.lowercase()
        val isMpesa = normalized.contains("m-pesa") ||
            normalized.contains("mpesa") ||
            normalized.contains("ksh")

        if (!isMpesa) return

        // Persist first. This is the step that makes the app work while it is closed:
        // the message is safe on disk before we care whether any Dart isolate exists.
        MpesaStore.enqueue(applicationContext, payload)
        Log.d(TAG, "Queued M-Pesa payload from ${sbn.packageName}")

        // Then hand it to whichever Dart side is available.
        if (!MpesaChannels.pokeForeground()) {
            MpesaBackgroundEngine.wake(applicationContext)
        }
    }

    override fun onDestroy() {
        MpesaBackgroundEngine.shutdown()
        super.onDestroy()
    }
}
