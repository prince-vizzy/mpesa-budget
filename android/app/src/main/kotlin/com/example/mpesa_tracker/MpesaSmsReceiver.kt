package com.example.mpesa_tracker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log

/**
 * Primary capture path: every incoming SMS, straight from the system broadcast.
 *
 * Unlike the notification listener this does not depend on a notification being
 * posted at all, so it still fires when the M-Pesa conversation is muted, when the
 * messaging app is open on that thread, or when the user has cleared the shade.
 */
class MpesaSmsReceiver : BroadcastReceiver() {

    private companion object {
        const val TAG = "MpesaSmsReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val appContext = context.applicationContext

        // onReceive must return quickly, but enqueueing is a single committed
        // SharedPreferences write — cheap enough to finish inline, and doing it
        // here means the message is durable before this process can be killed.
        val messages = try {
            Telephony.Sms.Intents.getMessagesFromIntent(intent)
        } catch (t: Throwable) {
            Log.w(TAG, "Could not read SMS from broadcast", t)
            return
        } ?: return

        // M-Pesa messages run past 160 characters, so they arrive split across
        // several PDUs that have to be stitched back together before parsing —
        // each part on its own has half a transaction in it.
        val bodies = LinkedHashMap<String, StringBuilder>()
        for (message in messages) {
            val sender = message?.originatingAddress?.trim().orEmpty()
            val part = message?.messageBody ?: continue
            bodies.getOrPut(sender) { StringBuilder() }.append(part)
        }

        var queued = 0
        for ((sender, builder) in bodies) {
            val body = builder.toString().trim()
            if (body.isBlank() || !MpesaSms.looksLikeMpesa(body)) continue

            // Same shape the listener and the inbox sweep produce, so all three
            // sources de-duplicate against each other.
            val payload = if (sender.isBlank()) body else "$sender $body"
            if (MpesaStore.enqueue(appContext, payload)) queued++
        }

        if (queued == 0) return
        Log.d(TAG, "Queued $queued M-Pesa SMS.")

        if (!MpesaChannels.pokeForeground()) {
            MpesaBackgroundEngine.wake(appContext)
        }
    }
}
