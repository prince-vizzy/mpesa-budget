package com.example.mpesa_tracker

import android.content.Context
import org.json.JSONArray

/**
 * Durable, process-independent inbox for captured M-Pesa notifications.
 *
 * The notification listener writes here the instant a message arrives, whether or
 * not any Flutter engine is alive. Dart drains the queue when it comes up, so a
 * message can never be lost just because the UI was closed.
 */
object MpesaStore {
    private const val PREFS = "mpesa_tracker_native"
    private const val KEY_QUEUE = "pending_messages"
    private const val KEY_CALLBACK = "background_callback_handle"
    private const val MAX_QUEUE = 200

    private val lock = Any()

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun enqueue(context: Context, payload: String) {
        synchronized(lock) {
            val store = prefs(context)
            val queue = JSONArray(store.getString(KEY_QUEUE, "[]"))

            // Android re-posts the same notification on every update; skip anything
            // already waiting to be drained.
            for (i in 0 until queue.length()) {
                if (queue.optString(i) == payload) return
            }

            queue.put(payload)
            while (queue.length() > MAX_QUEUE) queue.remove(0)

            // commit(), not apply() — the process may be killed moments from now.
            store.edit().putString(KEY_QUEUE, queue.toString()).commit()
        }
    }

    /** Atomically returns everything queued and empties the queue. */
    fun drain(context: Context): List<String> {
        synchronized(lock) {
            val store = prefs(context)
            val raw = store.getString(KEY_QUEUE, "[]") ?: "[]"
            store.edit().putString(KEY_QUEUE, "[]").commit()

            val queue = JSONArray(raw)
            return (0 until queue.length())
                .map { queue.optString(it) }
                .filter { it.isNotBlank() }
        }
    }

    fun pendingCount(context: Context): Int = synchronized(lock) {
        JSONArray(prefs(context).getString(KEY_QUEUE, "[]")).length()
    }

    /** Raw handle of the Dart entrypoint used to spin up the headless engine. */
    fun setCallbackHandle(context: Context, handle: Long) {
        prefs(context).edit().putLong(KEY_CALLBACK, handle).commit()
    }

    fun callbackHandle(context: Context): Long =
        prefs(context).getLong(KEY_CALLBACK, 0L)
}
