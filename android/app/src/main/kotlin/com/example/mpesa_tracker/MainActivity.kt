package com.example.mpesa_tracker

import android.content.ComponentName
import android.content.Context
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private var eventSink: EventChannel.EventSink? = null

        fun emitMpesaEvent(message: String) {
            eventSink?.success(message)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "mpesa_events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mpesa_listener")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isListenerEnabled" -> {
                        result.success(isNotificationListenerEnabled())
                    }

                    "openListenerSettings" -> {
                        startActivity(
                            android.content.Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS")
                        )
                        result.success(true)
                    }

                    "simulateMpesaNotification" -> {
                        val message = call.argument<String>("message")
                            ?: "QTEST123 Confirmed. Ksh650.00 paid to Demo Shop on 31/3/26 at 10:05 AM. New M-PESA balance is Ksh2,100.00"
                        emitMpesaEvent(message)
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun isNotificationListenerEnabled(): Boolean {
        val enabledListeners = Settings.Secure.getString(
            contentResolver,
            "enabled_notification_listeners"
        ) ?: return false
        val component = ComponentName(this, MpesaNotificationListenerService::class.java)
        return enabledListeners.contains(component.flattenToString())
    }
}
