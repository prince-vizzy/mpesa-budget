package com.example.mpesa_tracker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Sweeps the SMS inbox after a reboot.
 *
 * A phone that restarts overnight comes back with the notification listener not
 * yet rebound and any M-Pesa SMS that landed during the boot already delivered.
 * Without this, those transactions are only picked up whenever the user next
 * happens to open the app.
 */
class MpesaBootReceiver : BroadcastReceiver() {

    private companion object {
        const val TAG = "MpesaBootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != "android.intent.action.QUICKBOOT_POWERON"
        ) {
            return
        }

        val appContext = context.applicationContext
        val pendingResult = goAsync()

        // The content provider query is disk I/O, so keep it off the main thread
        // and hold the broadcast open until it finishes.
        Thread {
            try {
                val queued = MpesaSms.backfillAndNotify(appContext)
                Log.d(TAG, "Boot sweep queued $queued message(s).")

                // Anything left unacknowledged from before the reboot still needs
                // a Dart isolate to come and take it.
                if (queued == 0 && MpesaStore.pendingCount(appContext) > 0) {
                    if (!MpesaChannels.pokeForeground()) {
                        MpesaBackgroundEngine.wake(appContext)
                    }
                }
            } catch (t: Throwable) {
                Log.w(TAG, "Boot sweep failed", t)
            } finally {
                pendingResult.finish()
            }
        }.start()
    }
}
