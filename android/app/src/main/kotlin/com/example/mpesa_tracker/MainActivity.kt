package com.example.mpesa_tracker

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "mpesa_channel"
    private var flutterEngineRef: FlutterEngine? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        flutterEngineRef = flutterEngine
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        val message = intent?.getStringExtra("mpesa_message") ?: return

        flutterEngineRef?.let { engine ->
            MethodChannel(
                engine.dartExecutor.binaryMessenger,
                CHANNEL
            ).invokeMethod("mpesa_received", message)
        }
    }
}
