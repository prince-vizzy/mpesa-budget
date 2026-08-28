package com.example.mpesa_tracker

import android.content.Context
import org.json.JSONArray

/**
 * Durable, process-independent inbox for captured M-Pesa messages.
 *
 * Every capture source — the notification listener, the SMS broadcast receiver and
 * the SMS inbox backfill — writes here the instant a message arrives, whether or
 * not any Flutter engine is alive. Dart drains the queue when it comes up, so a
 * message can never be lost just because the UI was closed.
 */
object MpesaStore {
    private const val PREFS = "mpesa_tracker_native"
    private const val KEY_QUEUE = "pending_messages"
    private const val KEY_SEEN = "seen_keys"
    private const val KEY_CALLBACK = "background_callback_handle"
    private const val KEY_LAST_SMS_SCAN = "last_sms_scan"
    private const val MAX_QUEUE = 200
    private const val MAX_SEEN = 500

    /**
     * The transaction code every Safaricom M-Pesa message opens with, e.g.
     * "TIJ4E5RXYZ Confirmed. …". Ten uppercase alphanumerics starting with a
     * letter, and always within the first few words.
     */
    private val TRANSACTION_CODE = Regex("""\b([A-Z][A-Z0-9]{9})\b""")

    private val lock = Any()

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /**
     * Stable identity for a message, so the same transaction is stored once no
     * matter how many sources report it.
     *
     * The same M-Pesa SMS reaches us as a raw SMS body *and* as a notification with
     * the sender name glued to the front, so the texts never match exactly. The
     * transaction code does, and it is unique per transaction. Messages without one
     * (in-app M-PESA and bank alerts) fall back to their normalised text.
     */
    private fun dedupeKey(payload: String): String {
        val head = payload.take(60)
        val code = TRANSACTION_CODE.find(head)?.groupValues?.get(1)
        if (code != null) return "code:$code"
        return "text:" + payload.replace(Regex("""\s+"""), " ").trim().lowercase()
    }

    /**
     * Queues a message unless it has already been seen.
     *
     * @return true if this was new and is now waiting for Dart.
     */
    fun enqueue(context: Context, payload: String): Boolean {
        synchronized(lock) {
            val store = prefs(context)
            val key = dedupeKey(payload)

            val seen = JSONArray(store.getString(KEY_SEEN, "[]"))
            for (i in 0 until seen.length()) {
                if (seen.optString(i) == key) return false
            }

            val queue = JSONArray(store.getString(KEY_QUEUE, "[]"))
            queue.put(payload)
            while (queue.length() > MAX_QUEUE) queue.remove(0)

            seen.put(key)
            while (seen.length() > MAX_SEEN) seen.remove(0)

            // commit(), not apply() — the process may be killed moments from now.
            store.edit()
                .putString(KEY_QUEUE, queue.toString())
                .putString(KEY_SEEN, seen.toString())
                .commit()
            return true
        }
    }

    /**
     * Returns everything queued, without clearing it. Entries only leave the queue
     * via [acknowledge], once Dart has actually finished with them — otherwise a
     * process death between fetching and finishing (parsing, DB insert) would drop
     * the message on the floor instead of just delaying it.
     *
     * Note that the seen-key list is deliberately *not* consulted here: a message
     * stays queued until it is acknowledged, so a crash mid-processing still gets
     * a retry even though its key is already marked seen.
     */
    fun peekAll(context: Context): List<String> = synchronized(lock) {
        val queue = JSONArray(prefs(context).getString(KEY_QUEUE, "[]"))
        (0 until queue.length())
            .map { queue.optString(it) }
            .filter { it.isNotBlank() }
    }

    /** Removes one successfully-processed entry (first exact match) from the queue. */
    fun acknowledge(context: Context, payload: String) {
        synchronized(lock) {
            val store = prefs(context)
            val queue = JSONArray(store.getString(KEY_QUEUE, "[]"))

            val remaining = JSONArray()
            var removedOne = false
            for (i in 0 until queue.length()) {
                val item = queue.optString(i)
                if (!removedOne && item == payload) {
                    removedOne = true
                    continue
                }
                remaining.put(item)
            }

            if (removedOne) {
                store.edit().putString(KEY_QUEUE, remaining.toString()).commit()
            }
        }
    }

    fun pendingCount(context: Context): Int = synchronized(lock) {
        JSONArray(prefs(context).getString(KEY_QUEUE, "[]")).length()
    }

    /**
     * Timestamp of the newest SMS the inbox sweep has already looked at, so a
     * later sweep only has to consider what arrived since.
     */
    fun lastSmsScan(context: Context): Long =
        prefs(context).getLong(KEY_LAST_SMS_SCAN, 0L)

    fun setLastSmsScan(context: Context, timestamp: Long) {
        synchronized(lock) {
            val store = prefs(context)
            if (timestamp > store.getLong(KEY_LAST_SMS_SCAN, 0L)) {
                store.edit().putLong(KEY_LAST_SMS_SCAN, timestamp).commit()
            }
        }
    }

    /** Raw handle of the Dart entrypoint used to spin up the headless engine. */
    fun setCallbackHandle(context: Context, handle: Long) {
        prefs(context).edit().putLong(KEY_CALLBACK, handle).commit()
    }

    fun callbackHandle(context: Context): Long =
        prefs(context).getLong(KEY_CALLBACK, 0L)
}
