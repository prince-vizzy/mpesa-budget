package com.example.mpesa_tracker

import android.app.Notification
import android.content.ComponentName
import android.os.Build
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

/**
 * Secondary capture path, for what never arrives as an SMS: alerts posted by the
 * M-PESA app itself and by bank apps.
 *
 * [MpesaSmsReceiver] and [MpesaSms] cover SMS far more reliably; everything here
 * de-duplicates against them through [MpesaStore].
 */
class MpesaNotificationListenerService : NotificationListenerService() {

    private companion object {
        const val TAG = "MpesaListener"

        /** Keys whose values are a single candidate message body. */
        val SINGLE_TEXT_KEYS = arrayOf(
            Notification.EXTRA_TEXT,
            Notification.EXTRA_BIG_TEXT,
            Notification.EXTRA_SUB_TEXT,
            Notification.EXTRA_SUMMARY_TEXT
        )
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "Listener connected.")

        var queued = 0

        // onNotificationPosted only fires for *new* posts, so everything already
        // sitting in the shade is invisible to it. After a reboot, an OEM battery
        // kill, or the user granting this permission for the first time, that is
        // exactly where the missed transactions are.
        queued += harvestActiveNotifications()

        // Catches anything that was delivered while we had no process at all.
        queued += MpesaSms.backfill(applicationContext)

        // Anything captured while Dart was down is still queued — drain it now.
        if (queued > 0 || MpesaStore.pendingCount(applicationContext) > 0) {
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
        val queued = harvest(sbn)
        if (queued == 0) return

        Log.d(TAG, "Queued $queued M-Pesa payload(s) from ${sbn.packageName}")

        // Hand it to whichever Dart side is available.
        if (!MpesaChannels.pokeForeground()) {
            MpesaBackgroundEngine.wake(applicationContext)
        }
    }

    /** Re-reads everything currently showing in the shade. */
    private fun harvestActiveNotifications(): Int {
        val active = try {
            activeNotifications
        } catch (t: Throwable) {
            // Throws if the binding is not fully up yet; the SMS paths still cover us.
            Log.w(TAG, "Could not read active notifications", t)
            null
        } ?: return 0

        var queued = 0
        for (sbn in active) {
            queued += harvest(sbn ?: continue)
        }
        if (queued > 0) Log.d(TAG, "Recovered $queued M-Pesa payload(s) from the shade.")
        return queued
    }

    /**
     * Persists every M-Pesa-looking message this notification carries.
     *
     * Persisting is the step that makes the app work while it is closed: the
     * message is safe on disk before we care whether any Dart isolate exists.
     *
     * @return how many were newly queued.
     */
    private fun harvest(sbn: StatusBarNotification): Int {
        // Never react to our own "tap to categorize" alerts — their body contains
        // "Ksh", which would otherwise feed straight back into the parser.
        if (sbn.packageName == packageName) return 0

        val notification = sbn.notification ?: return 0
        val extras = notification.extras ?: return 0

        // A group summary just repeats what the child notifications already carry.
        if (notification.flags and Notification.FLAG_GROUP_SUMMARY != 0) return 0

        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim()

        // One entry per candidate message body, NOT one blob per notification.
        //
        // A messaging app collapses a conversation into a single notification: the
        // individual SMS bodies live in EXTRA_MESSAGES while EXTRA_TEXT degrades to
        // "3 new messages". Joining every extra together therefore both loses the
        // real bodies and, when several do survive, hands the parser a string with
        // several amounts in it — of which it can only ever read the first.
        val bodies = collectBodies(extras)
        if (bodies.isEmpty()) {
            Log.v(TAG, "No readable body on notification from ${sbn.packageName}")
            return 0
        }

        var queued = 0
        for (body in bodies) {
            // Keep the title (the SMS sender) attached: it is part of what the
            // parser and the de-duplication key see.
            val payload = if (title.isNullOrBlank()) body else "$title $body"
            if (!MpesaSms.looksLikeMpesa(payload)) continue
            if (MpesaStore.enqueue(applicationContext, payload)) queued++
        }
        return queued
    }

    /**
     * Every distinct message body this notification carries, newest last.
     *
     * Covers the plain single-text notification, InboxStyle (EXTRA_TEXT_LINES) and
     * MessagingStyle (EXTRA_MESSAGES / EXTRA_HISTORIC_MESSAGES), which is what
     * Google Messages and most OEM SMS apps actually post.
     */
    // getParcelableArray(key, Class) is API 33+; the untyped overload is the only
    // one that works across every level this app supports.
    @Suppress("DEPRECATION")
    private fun collectBodies(extras: Bundle): List<String> {
        val bodies = LinkedHashSet<String>()

        fun add(value: CharSequence?) {
            val text = value?.toString()?.trim()
            if (!text.isNullOrBlank()) bodies.add(text)
        }

        // MessagingStyle: the only place the real bodies survive once a conversation
        // has more than one unread message.
        for (key in arrayOf(Notification.EXTRA_MESSAGES, Notification.EXTRA_HISTORIC_MESSAGES)) {
            val parcelables = try {
                extras.getParcelableArray(key)
            } catch (t: Throwable) {
                Log.w(TAG, "Could not read $key", t)
                null
            } ?: continue

            for (parcelable in parcelables) {
                val message = parcelable as? Bundle ?: continue
                add(message.getCharSequence("text"))
            }
        }

        // InboxStyle: one line per message.
        try {
            extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)?.forEach(::add)
        } catch (t: Throwable) {
            Log.w(TAG, "Could not read EXTRA_TEXT_LINES", t)
        }

        // Plain notification bodies. Added last so that when a messaging app has
        // already given us the real messages, a degraded "3 new messages" summary
        // is just an extra candidate that fails the M-Pesa check.
        for (key in SINGLE_TEXT_KEYS) {
            add(extras.getCharSequence(key))
        }

        // A body that is fully contained in a longer one is the truncated collapsed
        // version of it (EXTRA_TEXT vs EXTRA_BIG_TEXT) — drop it so the same
        // transaction is not queued twice under two slightly different payloads.
        return bodies.filterNot { candidate ->
            bodies.any { other -> other != candidate && other.contains(candidate) }
        }
    }

    override fun onDestroy() {
        MpesaBackgroundEngine.shutdown()
        super.onDestroy()
    }
}
