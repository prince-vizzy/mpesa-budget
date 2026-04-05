package com.example.mpesa_finance_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            for (message in messages) {
                val messageBody = message.messageBody
                if (isMpesaMessage(messageBody)) {
                    savePendingSms(context, messageBody)
                }
            }
        }
    }

    private fun isMpesaMessage(message: String): Boolean {
        val lower = message.lowercase()
        return lower.contains("mpesa") || 
               lower.contains("m-pesa") || 
               lower.contains("confirmation") ||
               lower.contains("sent to") ||
               lower.contains("received from") ||
               lower.contains("withdraw") ||
               lower.contains("airtime")
    }

    private fun savePendingSms(context: Context, message: String) {
        val prefs = context.getSharedPreferences("mpesa_prefs", Context.MODE_PRIVATE)
        val currentSms = prefs.getString("pending_sms", "") ?: ""
        val newSmsList = if (currentSms.isEmpty()) message else "$currentSms|||new|||$message"
        prefs.edit().putString("pending_sms", newSmsList).apply()
    }
}