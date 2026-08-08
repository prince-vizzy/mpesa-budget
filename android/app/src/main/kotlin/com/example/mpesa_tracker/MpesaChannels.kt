package com.example.mpesa_tracker

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Registers the `mpesa_listener` control channel. Both the UI engine and the
 * headless background engine get the same API, so the Dart side does not need to
 * know which isolate it is running in.
 */
object MpesaChannels {
    private const val TAG = "MpesaChannels"
    private const val METHOD_CHANNEL = "mpesa_listener"
    private const val EVENT_CHANNEL = "mpesa_events"

    /** Live "wake up and drain" signal for a foreground UI engine. */
    @Volatile
    private var eventSink: EventChannel.EventSink? = null

    /**
     * Whether a MainActivity is actually on screen. The event sink alone is not
     * trustworthy: when the activity is destroyed Flutter never calls onCancel,
     * so a stale sink survives and silently swallows every message
     * ("FlutterJNI was detached from native C++").
     */
    @Volatile
    private var uiResumed = false

    fun setUiResumed(resumed: Boolean) {
        uiResumed = resumed
    }

    /** Called when the activity's engine goes away, so we stop trusting the sink. */
    fun detachForeground() {
        uiResumed = false
        eventSink = null
    }

    /** Nudges the UI to drain the queue. Returns false if no live UI is listening. */
    fun pokeForeground(): Boolean {
        if (!uiResumed) return false
        val sink = eventSink ?: return false
        return try {
            sink.success("pending")
            true
        } catch (t: Throwable) {
            Log.w(TAG, "Foreground sink is dead, falling back to background engine", t)
            detachForeground()
            false
        }
    }

    fun register(context: Context, messenger: BinaryMessenger, background: Boolean) {
        val appContext = context.applicationContext

        if (!background) {
            EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                        eventSink = events
                    }

                    override fun onCancel(arguments: Any?) {
                        eventSink = null
                    }
                }
            )
        }

        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isListenerEnabled" -> result.success(isNotificationListenerEnabled(appContext))

                "openListenerSettings" -> {
                    val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    appContext.startActivity(intent)
                    result.success(true)
                }

                "drainPending" -> result.success(MpesaStore.drain(appContext))

                "pendingCount" -> result.success(MpesaStore.pendingCount(appContext))

                "registerBackgroundHandler" -> {
                    val handle = call.argument<Any>("handle")
                    val raw = when (handle) {
                        is Long -> handle
                        is Int -> handle.toLong()
                        is Number -> handle.toLong()
                        else -> 0L
                    }
                    MpesaStore.setCallbackHandle(appContext, raw)
                    result.success(true)
                }

                "simulateMpesaNotification" -> {
                    val message = call.argument<String>("message")
                        ?: "QTEST123 Confirmed. Ksh650.00 paid to Demo Shop on 31/3/26 at 10:05 AM. " +
                        "New M-PESA balance is Ksh2,100.00"
                    MpesaStore.enqueue(appContext, message)
                    if (!pokeForeground()) MpesaBackgroundEngine.wake(appContext)
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    fun isNotificationListenerEnabled(context: Context): Boolean {
        val enabled = Settings.Secure.getString(
            context.contentResolver,
            "enabled_notification_listeners"
        ) ?: return false
        val component = ComponentName(context, MpesaNotificationListenerService::class.java)
        return enabled.split(":").any {
            ComponentName.unflattenFromString(it) == component
        }
    }
}
