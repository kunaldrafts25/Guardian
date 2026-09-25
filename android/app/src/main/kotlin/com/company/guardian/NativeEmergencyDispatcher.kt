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
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.Constraints
import androidx.work.NetworkType
import androidx.work.WorkManager
import androidx.work.ExistingWorkPolicy
import androidx.work.Data
import androidx.work.BackoffPolicy
import java.util.concurrent.TimeUnit

/** Executes the minimum emergency path without requiring an Activity or Dart VM. */
object NativeEmergencyDispatcher {
    private const val CHANNEL_ID = "guardian_native_emergency"
    private const val REFRACTORY_MS = 15_000L

    private fun getPriorityForSource(source: String): Int {
        return when (source) {
            "ANDROID_POWER_GESTURE", "MULTI_TAP", "hardware_power_panic" -> 100 // EXPLICIT_DISTRESS
            "ANDROID_FALL", "fall_detected", "ROUTE_DEVIATION", "CHECK_IN_EXPIRED" -> 50 // AUTO_HIGH
            "ANDROID_SHAKE", "shake_sos" -> 20 // AUTO_PROBABLE
            else -> 10
        }
    }

    @Synchronized
    fun trigger(context: Context, source: String, operationId: String? = null, sensorEvidence: JSONObject? = null): JSONObject? {
        val now = System.currentTimeMillis()
        val priority = getPriorityForSource(source)
        if (!NativeEmergencyStore.claimTrigger(context, now, REFRACTORY_MS, priority, operationId)) return null

        val eventId = UUID.randomUUID().toString()
        val snapshot = NativeEmergencyStore.snapshot(context)
        val cloudAuth = NativeEmergencyStore.cloudAuth(context)
        val ownerUserId = snapshot?.optString("user_id")?.takeIf { it.isNotBlank() }
            ?: cloudAuth?.optString("user_id")?.takeIf { it.isNotBlank() }
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
        val contactIdByPhone = mutableMapOf<String, String>()
        for (index in 0 until contacts.length()) {
            val contact = contacts.optJSONObject(index) ?: continue
            val phone = contact.optString("phone").takeIf { it.isNotBlank() } ?: continue
            phones.add(phone)
            contact.optString("id").takeIf { it.isNotBlank() }?.let { contactId ->
                contactIdByPhone[phone] = contactId
            }
        }
        val phoneHashByContact = JSONObject()
        contactIdByPhone.forEach { (phone, contactId) ->
            phoneHashByContact.put(contactId, phone.hashCode())
        }
        val event = JSONObject().apply {
            put("schema_version", 1)
            put("event_id", eventId)
            put("owner_user_id", ownerUserId ?: JSONObject.NULL)
            put("source", source)
            if (!operationId.isNullOrBlank()) put("operation_id", operationId)
            put("occurred_at_ms", now)
            put("snapshot_version", snapshot?.optInt("version", 0) ?: 0)
            put("accepted_phones", JSONArray())
            put("failed_phones", JSONArray())
            put("accepted_contact_ids", JSONArray())
            put("failed_contact_ids", JSONArray())
            put("phone_hash_by_contact", phoneHashByContact)
            put("latitude", location?.latitude ?: JSONObject.NULL)
            put("longitude", location?.longitude ?: JSONObject.NULL)
            put("accuracy", location?.accuracy ?: JSONObject.NULL)
            put("location_time_ms", location?.time ?: JSONObject.NULL)
            put("location_provider", location?.provider ?: JSONObject.NULL)
            put("sensor_evidence", sensorEvidence ?: JSONObject.NULL)
            put("consumed", false)
            put("cloud_synced", false)
        }

        // Persist before calling SmsManager so an immediate sent callback can
        // always attach evidence to the canonical event.
        NativeEmergencyStore.appendEvent(context, event)

        val dispatchResults = SmsHelper.sendEmergencySms(
            context = context,
            eventId = eventId,
            phoneNumbers = phones.distinct(),
            message = message,
        )
        val acceptedPhones = JSONArray()
        val failedPhones = JSONArray()
        val acceptedContactIds = JSONArray()
        val failedContactIds = JSONArray()
        dispatchResults.forEach { (phone, accepted) ->
            if (accepted) {
                acceptedPhones.put(phone)
                contactIdByPhone[phone]?.let(acceptedContactIds::put)
            } else {
                failedPhones.put(phone)
                contactIdByPhone[phone]?.let(failedContactIds::put)
            }
        }
        NativeEmergencyStore.updateSmsSubmissionResults(
            context,
            eventId,
            acceptedPhones,
            failedPhones,
            acceptedContactIds,
            failedContactIds,
        )
        event.put("accepted_phones", acceptedPhones)
        event.put("failed_phones", failedPhones)
        event.put("accepted_contact_ids", acceptedContactIds)
        event.put("failed_contact_ids", failedContactIds)
        acknowledgeOnDevice(context, dispatchResults.values.count { it }, phones.size)

        // P1-04: Queue resilient cloud upload using WorkManager
        val workData = Data.Builder().putString("event_id", eventId).build()
        val constraints = Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()
        val workRequest = OneTimeWorkRequestBuilder<CloudSyncWorker>()
            .setInputData(workData)
            .setConstraints(constraints)
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 10, TimeUnit.SECONDS)
            .build()
        WorkManager.getInstance(context).enqueueUniqueWork(
            "guardian-emergency-$eventId",
            ExistingWorkPolicy.KEEP,
            workRequest,
        )

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
