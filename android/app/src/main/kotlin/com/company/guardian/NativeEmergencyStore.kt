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
    private const val EVENTS_KEY = "events"
    private const val LAST_TRIGGER_AT_KEY = "last_trigger_at"
    private const val LAST_TRIGGER_PRIORITY_KEY = "last_trigger_priority"
    private const val CHECK_IN_SCHEDULE_KEY = "check_in_schedule"
    private const val CHECK_IN_ACTIONS_KEY = "check_in_actions"
    private const val MAX_EVENTS = 32

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
        val trimmed = JSONArray()
        val start = maxOf(0, events.length() - MAX_EVENTS)
        for (index in start until events.length()) trimmed.put(events.getJSONObject(index))
        preferences(context).edit().putString(EVENTS_KEY, trimmed.toString()).commit()
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
