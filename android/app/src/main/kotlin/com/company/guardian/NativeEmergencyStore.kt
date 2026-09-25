package com.company.guardian

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKeys
import org.json.JSONArray
import org.json.JSONObject

/** Encrypted, process-independent state used by the no-open emergency path. */
object NativeEmergencyStore {
    private const val FILE_NAME = "guardian_native_emergency_v1"
    private const val SNAPSHOT_KEY = "snapshot"
    private const val CLOUD_AUTH_KEY = "cloud_auth"
    private const val EVENTS_KEY = "events"
    private const val LAST_TRIGGER_AT_KEY = "last_trigger_at"
    private const val LAST_TRIGGER_PRIORITY_KEY = "last_trigger_priority"
    private const val CHECK_IN_SCHEDULE_KEY = "check_in_schedule"
    private const val CHECK_IN_ACTIONS_KEY = "check_in_actions"
    private const val SMS_RESULTS_KEY = "sms_sent_results"
    private const val MAX_EVENTS = 64

    private fun preferences(context: Context): SharedPreferences {
        val masterKey = MasterKeys.getOrCreate(MasterKeys.AES256_GCM_SPEC)
        return EncryptedSharedPreferences.create(
            FILE_NAME,
            masterKey,
            context.applicationContext,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
    }

    @Synchronized
    fun saveSnapshot(context: Context, snapshot: JSONObject) {
        require(snapshot.optInt("version", 0) > 0) { "Snapshot version is required" }
        preferences(context).edit().putString(SNAPSHOT_KEY, snapshot.toString()).commit()
    }

    @Synchronized
    fun snapshot(context: Context): JSONObject? {
        val raw = preferences(context).getString(SNAPSHOT_KEY, null) ?: return null
        return runCatching { JSONObject(raw) }.getOrNull()
    }

    @Synchronized
    fun clearSnapshot(context: Context) {
        preferences(context).edit().remove(SNAPSHOT_KEY).commit()
    }

    @Synchronized
    fun saveCloudAuth(context: Context, auth: JSONObject) {
        require(auth.optString("user_id").isNotBlank()) { "User ID is required" }
        require(auth.optString("access_token").isNotBlank()) { "Access token is required" }
        require(auth.optString("session_id").isNotBlank()) { "Guardian session ID is required" }
        require(auth.optString("api_endpoint").isNotBlank()) { "API endpoint is required" }
        preferences(context).edit().putString(CLOUD_AUTH_KEY, auth.toString()).commit()
    }

    @Synchronized
    fun cloudAuth(context: Context): JSONObject? {
        val raw = preferences(context).getString(CLOUD_AUTH_KEY, null) ?: return null
        return runCatching { JSONObject(raw) }.getOrNull()
    }

    @Synchronized
    fun clearCloudAuth(context: Context) {
        preferences(context).edit().remove(CLOUD_AUTH_KEY).commit()
    }

    @Synchronized
    fun claimTrigger(context: Context, now: Long, refractoryMs: Long, priority: Int = 0, operationId: String? = null): Boolean {
        val prefs = preferences(context)
        
        // P1-05: Check-in/operation specific deduplication
        if (operationId != null) {
            val opKey = "claim_op_$operationId"
            if (prefs.contains(opKey)) return false
            prefs.edit().putLong(opKey, now).commit()
            return true
        }

        // P0-02: Priority-aware arbitration
        val previous = prefs.getLong(LAST_TRIGGER_AT_KEY, 0L)
        val prevPriority = prefs.getInt(LAST_TRIGGER_PRIORITY_KEY, 0)
        
        if (previous > 0L && (now - previous < refractoryMs) && priority <= prevPriority) return false
        
        return prefs.edit()
            .putLong(LAST_TRIGGER_AT_KEY, now)
            .putInt(LAST_TRIGGER_PRIORITY_KEY, priority)
            .commit()
    }

    @Synchronized
    fun appendEvent(context: Context, event: JSONObject) {
        val events = allEvents(context)
        events.put(event)

        // Never discard emergency evidence that still needs Flutter import or
        // native cloud synchronisation. Only fully-reconciled oldest records
        // are eligible for trimming. If more than MAX_EVENTS are unresolved,
        // retain them all rather than losing safety evidence.
        var removable = maxOf(0, events.length() - MAX_EVENTS)
        val retained = JSONArray()
        for (index in 0 until events.length()) {
            val item = events.getJSONObject(index)
            val fullyReconciled =
                item.optBoolean("consumed", false) && item.optBoolean("cloud_synced", false)
            if (removable > 0 && fullyReconciled) {
                removable--
                continue
            }
            retained.put(item)
        }
        preferences(context).edit().putString(EVENTS_KEY, retained.toString()).commit()
    }

    @Synchronized
    fun pendingEvents(context: Context): JSONArray {
        val all = allEvents(context)
        val pending = JSONArray()
        for (index in 0 until all.length()) {
            val event = all.getJSONObject(index)
            if (!event.optBoolean("consumed", false)) pending.put(event)
        }
        return pending
    }

    @Synchronized
    fun eventById(context: Context, eventId: String): JSONObject? {
        val all = allEvents(context)
        for (index in 0 until all.length()) {
            val event = all.getJSONObject(index)
            if (event.optString("event_id") == eventId) {
                return JSONObject(event.toString())
            }
        }
        return null
    }

    @Synchronized
    fun eventByOperationId(context: Context, operationId: String): JSONObject? {
        if (operationId.isBlank()) return null
        val all = allEvents(context)
        for (index in all.length() - 1 downTo 0) {
            val event = all.getJSONObject(index)
            if (event.optString("operation_id") == operationId) {
                return JSONObject(event.toString())
            }
        }
        return null
    }

    @Synchronized
    fun updateSmsSubmissionResults(
        context: Context,
        eventId: String,
        acceptedContactIds: JSONArray,
        failedContactIds: JSONArray,
    ): Boolean {
        val all = allEvents(context)
        var found = false
        for (index in 0 until all.length()) {
            val event = all.getJSONObject(index)
            if (event.optString("event_id") == eventId) {
                event.put("accepted_contact_ids", acceptedContactIds)
                event.put("failed_contact_ids", failedContactIds)
                found = true
                break
            }
        }
        if (found) preferences(context).edit().putString(EVENTS_KEY, all.toString()).commit()
        return found
    }

    @Synchronized
    fun recordSmsPartResult(
        context: Context,
        eventId: String,
        phoneHash: Int,
        partIndex: Int,
        totalParts: Int,
        success: Boolean,
        errorCode: Int?,
    ): Boolean {
        val prefs = preferences(context)
        val allResults = runCatching {
            JSONObject(prefs.getString(SMS_RESULTS_KEY, null) ?: "{}")
        }.getOrDefault(JSONObject())
        val eventResults = allResults.optJSONObject(eventId) ?: JSONObject()
        val key = phoneHash.toString()
        val aggregate = eventResults.optJSONObject(key) ?: JSONObject()
            .put("phone_hash", phoneHash)
            .put("status", "PENDING")
            .put("parts_total", totalParts)
            .put("parts_reported", 0)
            .put("parts_succeeded", 0)

        val partResults = aggregate.optJSONObject("part_results") ?: JSONObject()
        val partKey = partIndex.toString()
        if (!partResults.has(partKey)) {
            partResults.put(
                partKey,
                JSONObject()
                    .put("success", success)
                    .put("error_code", errorCode ?: JSONObject.NULL)
                    .put("reported_at_ms", System.currentTimeMillis()),
            )
            aggregate.put("parts_reported", aggregate.optInt("parts_reported", 0) + 1)
            if (success) {
                aggregate.put("parts_succeeded", aggregate.optInt("parts_succeeded", 0) + 1)
            }
        }

        aggregate.put("part_results", partResults)
        aggregate.put("parts_total", totalParts)
        aggregate.put("updated_at_ms", System.currentTimeMillis())
        val reported = aggregate.optInt("parts_reported", 0)
        val succeeded = aggregate.optInt("parts_succeeded", 0)
        aggregate.put(
            "status",
            when {
                reported < totalParts -> "PENDING"
                succeeded == totalParts -> "SENT"
                else -> "FAILED"
            },
        )
        eventResults.put(key, aggregate)
        allResults.put(eventId, eventResults)
        prefs.edit().putString(SMS_RESULTS_KEY, allResults.toString()).commit()

        // Mirror the result into a native emergency event when one exists so
        // the no-Flutter cloud worker can include stronger transport evidence.
        val events = allEvents(context)
        var eventFound = false
        for (index in 0 until events.length()) {
            val event = events.getJSONObject(index)
            if (event.optString("event_id") != eventId) continue
            val mirrored = event.optJSONObject("sms_sent_results") ?: JSONObject()
            mirrored.put(key, JSONObject(aggregate.toString()))
            event.put("sms_sent_results", mirrored)
            eventFound = true
            break
        }
        if (eventFound) {
            prefs.edit().putString(EVENTS_KEY, events.toString()).commit()
        }
        return true
    }

    @Synchronized
    fun smsSentResult(context: Context, eventId: String, phoneHash: Int): JSONObject? {
        val raw = preferences(context).getString(SMS_RESULTS_KEY, null) ?: return null
        val allResults = runCatching { JSONObject(raw) }.getOrNull() ?: return null
        val result = allResults.optJSONObject(eventId)
            ?.optJSONObject(phoneHash.toString())
            ?: return null
        return JSONObject(result.toString())
    }

    @Synchronized
    fun clearSmsResults(context: Context, eventId: String) {
        val prefs = preferences(context)
        val raw = prefs.getString(SMS_RESULTS_KEY, null) ?: return
        val allResults = runCatching { JSONObject(raw) }.getOrNull() ?: return
        allResults.remove(eventId)
        prefs.edit().putString(SMS_RESULTS_KEY, allResults.toString()).commit()
    }

    @Synchronized
    fun markCloudSynced(context: Context, eventId: String, incidentId: String?): Boolean {
        val all = allEvents(context)
        var found = false
        for (index in 0 until all.length()) {
            val event = all.getJSONObject(index)
            if (event.optString("event_id") == eventId) {
                event.put("cloud_synced", true)
                event.put("cloud_synced_at_ms", System.currentTimeMillis())
                if (!incidentId.isNullOrBlank()) event.put("cloud_incident_id", incidentId)
                found = true
            }
        }
        if (found) preferences(context).edit().putString(EVENTS_KEY, all.toString()).commit()
        return found
    }

    @Synchronized
    fun acknowledge(context: Context, eventId: String): Boolean {
        val all = allEvents(context)
        var found = false
        for (index in 0 until all.length()) {
            val event = all.getJSONObject(index)
            if (event.optString("event_id") == eventId) {
                event.put("consumed", true)
                found = true
            }
        }
        if (found) preferences(context).edit().putString(EVENTS_KEY, all.toString()).commit()
        return found
    }

    @Synchronized
    fun saveCheckInSchedule(context: Context, schedule: JSONObject) {
        preferences(context).edit()
            .putString(CHECK_IN_SCHEDULE_KEY, schedule.toString()).commit()
    }

    @Synchronized
    fun checkInSchedule(context: Context): JSONObject? {
        val raw = preferences(context).getString(CHECK_IN_SCHEDULE_KEY, null) ?: return null
        return runCatching { JSONObject(raw) }.getOrNull()
    }

    @Synchronized
    fun clearCheckInSchedule(context: Context) {
        preferences(context).edit().remove(CHECK_IN_SCHEDULE_KEY).commit()
    }

    @Synchronized
    fun appendCheckInAction(context: Context, action: JSONObject) {
        val actions = checkInActions(context)
        actions.put(action)
        preferences(context).edit().putString(CHECK_IN_ACTIONS_KEY, actions.toString()).commit()
    }

    @Synchronized
    fun checkInActions(context: Context): JSONArray {
        val raw = preferences(context).getString(CHECK_IN_ACTIONS_KEY, null) ?: return JSONArray()
        return runCatching { JSONArray(raw) }.getOrDefault(JSONArray())
    }

    @Synchronized
    fun acknowledgeCheckInAction(context: Context, actionId: String): Boolean {
        val actions = checkInActions(context)
        val remaining = JSONArray()
        var found = false
        for (index in 0 until actions.length()) {
            val action = actions.getJSONObject(index)
            if (action.optString("action_id") == actionId) found = true
            else remaining.put(action)
        }
        if (found) preferences(context).edit().putString(CHECK_IN_ACTIONS_KEY, remaining.toString()).commit()
        return found
    }

    private fun allEvents(context: Context): JSONArray {
        val raw = preferences(context).getString(EVENTS_KEY, null) ?: return JSONArray()
        return runCatching { JSONArray(raw) }.getOrDefault(JSONArray())
    }
}
