package com.company.guardian

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

/** Executes the minimum emergency path without requiring an Activity or Dart VM. */
object NativeEmergencyDispatcher {
    private const val CHANNEL_ID = "guardian_native_emergency"
    private const val REFRACTORY_MS = 15_000L

    @Synchronized
    fun trigger(context: Context, source: String): JSONObject? {
        val now = System.currentTimeMillis()
        if (!NativeEmergencyStore.claimTrigger(context, now, REFRACTORY_MS)) return null

        val eventId = UUID.randomUUID().toString()
        val snapshot = NativeEmergencyStore.snapshot(context)
        val contacts = snapshot?.optJSONArray("contacts") ?: JSONArray()
        val location = SafetyForegroundService.lastKnownLocation
        val userName = snapshot?.optString("user_name")?.takeIf { it.isNotBlank() }
            ?: "Guardian user"
        val mapsLink = location?.let { "https://maps.google.com/?q=${it.latitude},${it.longitude}" }
        val configuredMessage = snapshot?.optString("message")?.takeIf { it.isNotBlank() }
        val message = buildString {
            append(configuredMessage ?: "$userName needs urgent help.")
            append(" Event ID: $eventId.")
            if (mapsLink != null) append(" Location: $mapsLink")
            else append(" Current location was unavailable; please call them and emergency services.")
        }

        val phones = mutableListOf<String>()
        for (index in 0 until contacts.length()) {
            contacts.optJSONObject(index)?.optString("phone")
                ?.takeIf { it.isNotBlank() }
                ?.let(phones::add)
        }
        val dispatchResults = SmsHelper.sendEmergencySms(context, phones.distinct(), message)
        val acceptedPhones = JSONArray()
        val failedPhones = JSONArray()
        dispatchResults.forEach { (phone, accepted) ->
            if (accepted) acceptedPhones.put(phone) else failedPhones.put(phone)
        }

        val event = JSONObject().apply {
            put("schema_version", 1)
            put("event_id", eventId)
            put("source", source)
            put("occurred_at_ms", now)
            put("snapshot_version", snapshot?.optInt("version", 0) ?: 0)
            put("accepted_phones", acceptedPhones)
            put("failed_phones", failedPhones)
            put("latitude", location?.latitude ?: JSONObject.NULL)
            put("longitude", location?.longitude ?: JSONObject.NULL)
            put("accuracy", location?.accuracy ?: JSONObject.NULL)
            put("consumed", false)
        }
        NativeEmergencyStore.appendEvent(context, event)
        acknowledgeOnDevice(context, dispatchResults.values.count { it }, phones.size)
        return event
    }

    private fun acknowledgeOnDevice(context: Context, accepted: Int, total: Int) {
        val vibrator = context.getSystemService(Vibrator::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator?.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 90, 70, 180), -1))
        } else {
            @Suppress("DEPRECATION")
            vibrator?.vibrate(longArrayOf(0, 90, 70, 180), -1)
        }
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Emergency dispatch", NotificationManager.IMPORTANCE_HIGH)
            )
        }
        val body = if (total == 0) {
            "Emergency recorded. No emergency contacts are configured."
        } else {
            "$accepted of $total SMS dispatches were accepted by this device. Delivery is not confirmed."
        }
        manager.notify(
            4101,
            NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_notification_guardian)
                .setContentTitle("Emergency activated")
                .setContentText(body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .build(),
        )
    }
}
