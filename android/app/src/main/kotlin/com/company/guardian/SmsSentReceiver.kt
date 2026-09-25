package com.company.guardian

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.SmsManager
import android.util.Log

class SmsSentReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_SMS_SENT) return

        val eventId = intent.getStringExtra(EXTRA_EVENT_ID) ?: return
        val recipientToken = intent.getStringExtra(EXTRA_RECIPIENT_TOKEN)
            ?: intent.getIntExtra(EXTRA_PHONE_HASH, 0)
                .takeIf { it != 0 }
                ?.toString()
            ?: return
        val partIndex = intent.getIntExtra(EXTRA_PART_INDEX, 0)
        val totalParts = intent.getIntExtra(EXTRA_TOTAL_PARTS, 1).coerceAtLeast(1)
        val success = resultCode == Activity.RESULT_OK
        val errorCode = if (success) null else resultCode

        NativeEmergencyStore.recordSmsPartResult(
            context = context.applicationContext,
            eventId = eventId,
            recipientToken = recipientToken,
            partIndex = partIndex,
            totalParts = totalParts,
            success = success,
            errorCode = errorCode,
        )

        if (!success) {
            val category = when (resultCode) {
                SmsManager.RESULT_ERROR_GENERIC_FAILURE -> "generic_failure"
                SmsManager.RESULT_ERROR_NO_SERVICE -> "no_service"
                SmsManager.RESULT_ERROR_NULL_PDU -> "null_pdu"
                SmsManager.RESULT_ERROR_RADIO_OFF -> "radio_off"
                else -> "sms_error"
            }
            Log.w(TAG, "Emergency SMS part send failed: $category")
        }
    }

    companion object {
        const val ACTION_SMS_SENT = "com.company.guardian.GUARDIAN_SMS_SENT"
        const val EXTRA_EVENT_ID = "event_id"
        const val EXTRA_RECIPIENT_TOKEN = "recipient_token"
        // Backward compatibility for PendingIntents created by the previous build.
        const val EXTRA_PHONE_HASH = "phone_hash"
        const val EXTRA_PART_INDEX = "part_index"
        const val EXTRA_TOTAL_PARTS = "total_parts"
        private const val TAG = "Guardian.SmsSent"
    }
}
