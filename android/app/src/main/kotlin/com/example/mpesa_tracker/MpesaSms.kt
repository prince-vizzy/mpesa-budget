package com.example.mpesa_tracker

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Telephony
import android.util.Log

/**
 * SMS-side capture: the text filter shared by every source, plus a sweep of the
 * device SMS inbox.
 *
 * The notification listener can only ever see what the system actually posts. It
 * misses anything that arrived while our process was dead, anything in a muted or
 * currently-open conversation, and everything from before the user granted the
 * listener permission. Reading the SMS inbox closes all of those at once, because
 * the messages are still sitting there regardless.
 */
object MpesaSms {
    private const val TAG = "MpesaSms"

    /** How far back the very first sweep looks, so we do not import years of history. */
    private const val FIRST_SCAN_WINDOW_MS = 7L * 24 * 60 * 60 * 1000

    /** Safety valve so one sweep can never sit in a cursor loop forever. */
    private const val MAX_ROWS_PER_SCAN = 500

    /** Deliberately broad, so STK/SMS/banking app variations all get through. */
    fun looksLikeMpesa(payload: String): Boolean {
        val normalized = payload.lowercase()
        return normalized.contains("m-pesa") ||
            normalized.contains("mpesa") ||
            normalized.contains("ksh") ||
            normalized.contains("kes")
    }

    fun canReadInbox(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        return context.applicationContext.checkSelfPermission(Manifest.permission.READ_SMS) ==
            PackageManager.PERMISSION_GRANTED
    }

    /**
     * Queues every M-Pesa message in the SMS inbox that this app has not already
     * seen, and moves the bookmark forward.
     *
     * @param since overrides the stored bookmark, for an explicit deeper import.
     * @return how many new messages were queued.
     */
    fun backfill(context: Context, since: Long? = null): Int {
        val appContext = context.applicationContext
        if (!canReadInbox(appContext)) {
            Log.d(TAG, "READ_SMS not granted — skipping inbox sweep.")
            return 0
        }

        val bookmark = MpesaStore.lastSmsScan(appContext)
        val from = since
            ?: if (bookmark > 0L) bookmark
            else System.currentTimeMillis() - FIRST_SCAN_WINDOW_MS

        var queued = 0
        var newest = bookmark

        try {
            appContext.contentResolver.query(
                Telephony.Sms.Inbox.CONTENT_URI,
                arrayOf(Telephony.Sms.ADDRESS, Telephony.Sms.BODY, Telephony.Sms.DATE),
                "${Telephony.Sms.DATE} > ?",
                arrayOf(from.toString()),
                "${Telephony.Sms.DATE} ASC"
            )?.use { cursor ->
                val addressColumn = cursor.getColumnIndex(Telephony.Sms.ADDRESS)
                val bodyColumn = cursor.getColumnIndex(Telephony.Sms.BODY)
                val dateColumn = cursor.getColumnIndex(Telephony.Sms.DATE)
                if (bodyColumn < 0) return@use

                var rows = 0
                while (cursor.moveToNext() && rows < MAX_ROWS_PER_SCAN) {
                    rows++

                    val body = cursor.getString(bodyColumn)?.trim().orEmpty()
                    val date = if (dateColumn >= 0) cursor.getLong(dateColumn) else 0L
                    if (date > newest) newest = date
                    if (body.isBlank() || !looksLikeMpesa(body)) continue

                    val sender = if (addressColumn >= 0) {
                        cursor.getString(addressColumn)?.trim().orEmpty()
                    } else {
                        ""
                    }

                    // Same shape the listener produces, so the two sources agree.
                    val payload = if (sender.isBlank()) body else "$sender $body"
                    if (MpesaStore.enqueue(appContext, payload)) queued++
                }
            }
        } catch (t: Throwable) {
            // A missing permission, an OEM-locked provider or a revoked grant must
            // never take the app down — the listener is still capturing.
            Log.w(TAG, "Inbox sweep failed", t)
            return queued
        }

        // Only move the bookmark on a sweep that actually completed.
        MpesaStore.setLastSmsScan(appContext, newest)

        if (queued > 0) Log.d(TAG, "Inbox sweep queued $queued new message(s).")
        return queued
    }

    /** Queues anything new from the inbox and nudges whichever Dart side is alive. */
    fun backfillAndNotify(context: Context, since: Long? = null): Int {
        val queued = backfill(context, since)
        if (queued > 0 && !MpesaChannels.pokeForeground()) {
            MpesaBackgroundEngine.wake(context.applicationContext)
        }
        return queued
    }
}
