package com.example.mpesa_tracker

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.FlutterCallbackInformation

/**
 * Runs a headless FlutterEngine so Dart can parse, store and notify while the app
 * UI is closed. The engine is started lazily by the notification listener and kept
 * alive for as long as the listener process lives.
 */
object MpesaBackgroundEngine {
    private const val TAG = "MpesaBgEngine"
    private const val CHANNEL = "mpesa_background"

    private val mainHandler = Handler(Looper.getMainLooper())

    private var engine: FlutterEngine? = null
    private var channel: MethodChannel? = null

    @Volatile
    private var dartReady = false

    /** Starts the engine if needed, then tells Dart to drain the queue. */
    fun wake(context: Context) {
        val appContext = context.applicationContext
        mainHandler.post { wakeOnMainThread(appContext) }
    }

    private fun wakeOnMainThread(context: Context) {
        if (dartReady) {
            channel?.invokeMethod("process", null)
            return
        }

        // Engine is booting; Dart drains the queue itself as soon as it is ready,
        // so anything enqueued in the meantime is still picked up.
        if (engine != null) return

        val handle = MpesaStore.callbackHandle(context)
        if (handle == 0L) {
            Log.w(TAG, "No background entrypoint registered yet — message stays queued.")
            return
        }

        val callback = FlutterCallbackInformation.lookupCallbackInformation(handle)
        if (callback == null) {
            // Handles do not survive a rebuild; forget it so the next app launch re-registers.
            Log.w(TAG, "Stale Dart callback handle $handle, clearing.")
            MpesaStore.setCallbackHandle(context, 0L)
            return
        }

        try {
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(context)
            loader.ensureInitializationComplete(context, null)

            val newEngine = FlutterEngine(context)
            engine = newEngine

            // Register channels *before* running Dart so the first calls are handled.
            MpesaChannels.register(context, newEngine.dartExecutor.binaryMessenger, background = true)
            channel = MethodChannel(newEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
                setMethodCallHandler { call, result ->
                    when (call.method) {
                        "ready" -> {
                            dartReady = true
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                }
            }

            try {
                io.flutter.plugins.GeneratedPluginRegistrant.registerWith(newEngine)
            } catch (t: Throwable) {
                Log.w(TAG, "Plugin registration failed in background engine", t)
            }

            newEngine.dartExecutor.executeDartCallback(
                DartExecutor.DartCallback(context.assets, loader.findAppBundlePath(), callback)
            )
            Log.d(TAG, "Headless engine started.")
        } catch (t: Throwable) {
            Log.e(TAG, "Could not start headless engine", t)
            engine = null
            channel = null
            dartReady = false
        }
    }

    /** Called when the listener service is torn down. */
    fun shutdown() {
        mainHandler.post {
            try {
                engine?.destroy()
            } catch (t: Throwable) {
                Log.w(TAG, "Error destroying headless engine", t)
            }
            engine = null
            channel = null
            dartReady = false
        }
    }
}
