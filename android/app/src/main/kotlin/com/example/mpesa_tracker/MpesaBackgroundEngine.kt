package com.example.mpesa_tracker

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
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
    private var wakeLock: PowerManager.WakeLock? = null

    @Volatile
    private var dartReady = false

    // onNotificationPosted only gets an implicit system wake lock for the duration
    // of that call. wake() posts to the main thread and returns immediately, so
    // everything after that — booting a FlutterEngine, the ready handshake, opening
    // the DB, inserting — runs with no guarantee the CPU stays on. Without this the
    // device can doze mid-chain and the process gets killed before Dart ever
    // finishes, which drops the message instead of just delaying it.
    private fun acquireWakeLock(context: Context) {
        val lock = wakeLock ?: run {
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "MpesaTracker:BackgroundProcessing")
                .apply { setReferenceCounted(false) }
                .also { wakeLock = it }
        }
        // Timeout is a safety net in case Dart never reports back (crash, ANR) —
        // guarantees this can't leak and drain the battery.
        lock.acquire(30_000L)
    }

    private fun releaseWakeLock() {
        wakeLock?.let { if (it.isHeld) it.release() }
    }

    /** Starts the engine if needed, then tells Dart to drain the queue. */
    fun wake(context: Context) {
        val appContext = context.applicationContext
        acquireWakeLock(appContext)
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
            releaseWakeLock()
            return
        }

        try {
            // Initialize the loader *before* looking the handle up. lookupCallbackInformation
            // is a native call, so it needs libflutter loaded. When Android has killed us and
            // re-bound the listener into a brand new process nothing has loaded it yet, and
            // looking up first fails for a perfectly valid handle.
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(context)
            loader.ensureInitializationComplete(context, null)

            val callback = FlutterCallbackInformation.lookupCallbackInformation(handle)
            if (callback == null) {
                // Genuinely stale (the APK was rebuilt) — forget it so the next app launch
                // re-registers. Only safe to conclude now that the loader is up.
                Log.w(TAG, "Stale Dart callback handle $handle, clearing.")
                MpesaStore.setCallbackHandle(context, 0L)
                releaseWakeLock()
                return
            }

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
                        "processingComplete" -> {
                            // Dart finished this pass (queue drained and acknowledged, or
                            // nothing was pending) — safe to let the CPU sleep again.
                            releaseWakeLock()
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
            releaseWakeLock()
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
            releaseWakeLock()
        }
    }
}
