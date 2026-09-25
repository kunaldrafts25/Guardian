package com.company.guardian

import android.Manifest
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.telephony.SmsManager
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat
import java.security.MessageDigest

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
        eventId: String,
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
                    val sentIntent = buildSentIntent(
                        context = context,
                        eventId = eventId,
                        phone = phone,
                        partIndex = 0,
                        totalParts = 1,
                    )
                    smsManager.sendTextMessage(phone, null, message, sentIntent, null)
                } else {
                    // Long message — multipart SMS
                    val sentIntents = ArrayList(
                        parts.indices.map { partIndex ->
                            buildSentIntent(
                                context = context,
                                eventId = eventId,
                                phone = phone,
                                partIndex = partIndex,
                                totalParts = parts.size,
                            )
                        },
                    )
                    smsManager.sendMultipartTextMessage(
                        phone, null, ArrayList(parts), sentIntents, null
                    )
                }

                Log.i(TAG, "Emergency SMS dispatched to [REDACTED]")
                results[rawPhone] = true

            } catch (e: Exception) {
                Log.e(TAG, "Failed to send SMS: ${e.javaClass.simpleName}")
                results[rawPhone] = false
            }
        }

        return results
    }

    /**
     * Build a PendingIntent for asynchronous device/radio send-result evidence.
     * This is not handset/carrier delivery confirmation.
     */
    private fun buildSentIntent(
        context: Context,
        eventId: String,
        phone: String,
        partIndex: Int,
        totalParts: Int,
    ): PendingIntent {
        val recipientToken = recipientToken(eventId, phone)
        val intent = Intent(context, SmsSentReceiver::class.java).apply {
            action = SmsSentReceiver.ACTION_SMS_SENT
            // PendingIntent identity ignores extras. Give every event/recipient/
            // part callback a unique data URI so requestCode hash collisions
            // cannot cause one recipient's evidence to overwrite another's.
            data = Uri.Builder()
                .scheme("guardian-internal")
                .authority("sms-sent")
                .appendPath(eventId)
                .appendPath(recipientToken)
                .appendPath(partIndex.toString())
                .build()
            putExtra(SmsSentReceiver.EXTRA_EVENT_ID, eventId)
            putExtra(SmsSentReceiver.EXTRA_RECIPIENT_TOKEN, recipientToken)
            putExtra(SmsSentReceiver.EXTRA_PART_INDEX, partIndex)
            putExtra(SmsSentReceiver.EXTRA_TOTAL_PARTS, totalParts)
        }
        val requestCode = partIndex
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /**
     * Event-scoped recipient correlation token. SHA-256 avoids the collision
     * risk of Kotlin's 32-bit String.hashCode without persisting phone numbers.
     */
    fun recipientToken(eventId: String, phone: String): String {
        val normalized = sanitizePhone(phone)
        val digest = MessageDigest.getInstance("SHA-256")
            .digest("$eventId|$normalized".toByteArray(Charsets.UTF_8))
        return digest.joinToString(separator = "") { byte -> "%02x".format(byte) }
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
