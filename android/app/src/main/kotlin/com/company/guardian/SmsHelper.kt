package com.company.guardian

import android.Manifest
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.telephony.SmsManager
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat

/**
 * Guardian — SmsHelper
 *
 * Sends emergency SMS automatically via Android SmsManager.
 * NO user interaction required — SMS is sent directly without opening
 * the SMS app. This is the critical fix for the core safety defect
 * where url_launcher required the user to manually tap "Send".
 *
 * Method channel: "com.guardian/sms"
 */
object SmsHelper {

    private const val TAG = "Guardian.SmsHelper"

    /**
     * Send emergency SMS to a list of phone numbers.
     * Returns a map of phone -> success boolean.
     */
    fun sendEmergencySms(
        context: Context,
        phoneNumbers: List<String>,
        message: String
    ): Map<String, Boolean> {
        if (!hasSmsPermission(context)) {
            Log.e(TAG, "SEND_SMS permission not granted — cannot send emergency SMS")
            return phoneNumbers.associateWith { false }
        }

        val results = mutableMapOf<String, Boolean>()

        val smsManager: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(SmsManager::class.java)
        } else {
            @Suppress("DEPRECATION")
            SmsManager.getDefault()
        }

        for (rawPhone in phoneNumbers) {
            val phone = sanitizePhone(rawPhone)
            if (phone.isEmpty()) {
                Log.w(TAG, "Skipping invalid phone number")
                results[rawPhone] = false
                continue
            }

            try {
                // Split long messages into multiple SMS parts (160 char limit)
                val parts = smsManager.divideMessage(message)

                if (parts.size == 1) {
                    // Short message — single SMS
                    val sentIntent = buildSentIntent(context, phone)
                    smsManager.sendTextMessage(phone, null, message, sentIntent, null)
                } else {
                    // Long message — multipart SMS
                    val sentIntents = ArrayList(parts.map { buildSentIntent(context, phone) })
                    smsManager.sendMultipartTextMessage(
                        phone, null, ArrayList(parts), sentIntents, null
                    )
                }

                Log.i(TAG, "Emergency SMS dispatched to [REDACTED]")
                results[phone] = true

            } catch (e: Exception) {
                Log.e(TAG, "Failed to send SMS: ${e.javaClass.simpleName}")
                results[phone] = false
            }
        }

        return results
    }

    /**
     * Build a PendingIntent for SMS delivery confirmation.
     * Used to track whether SMS was actually sent by the carrier.
     */
    private fun buildSentIntent(context: Context, phone: String): PendingIntent {
        val intent = Intent("GUARDIAN_SMS_SENT").apply {
            putExtra("phone_hash", phone.hashCode())
        }
        return PendingIntent.getBroadcast(
            context,
            phone.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    /**
     * Clean a phone number — keep only digits and leading +
     */
    private fun sanitizePhone(phone: String): String {
        val clean = phone.trim()
        return if (clean.startsWith("+")) {
            "+" + clean.substring(1).replace(Regex("[^\\d]"), "")
        } else {
            clean.replace(Regex("[^\\d]"), "")
        }
    }

    fun hasSmsPermission(context: Context): Boolean {
        return ContextCompat.checkSelfPermission(
            context, Manifest.permission.SEND_SMS
        ) == PackageManager.PERMISSION_GRANTED
    }
}
