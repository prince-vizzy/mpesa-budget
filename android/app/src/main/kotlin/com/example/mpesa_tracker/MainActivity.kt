package com.example.mpesa_tracker

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

// FlutterFragmentActivity, not FlutterActivity: local_auth hosts the system
// biometric prompt in a fragment, and fails without one.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Re-register every time so a new FlutterEngine gets a live event sink.
        MpesaChannels.register(this, flutterEngine.dartExecutor.binaryMessenger, background = false)
    }

    // Flutter does not call the EventChannel's onCancel when the engine is torn
    // down, so we have to tell MpesaChannels ourselves. Without this the stale
    // sink keeps "accepting" messages that never reach Dart, and the background
    // engine is never started.
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        MpesaChannels.detachForeground()
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onResume() {
        super.onResume()
        MpesaChannels.setUiResumed(true)
    }

    override fun onPause() {
        MpesaChannels.setUiResumed(false)
        super.onPause()
    }

    override fun onDestroy() {
        MpesaChannels.detachForeground()
        super.onDestroy()
    }
}
