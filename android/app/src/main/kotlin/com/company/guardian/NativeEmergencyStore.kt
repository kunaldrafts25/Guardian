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
    fun claimTrigger(context: Context, now: Long, refractoryMs: Long): Boolean {
        val prefs = preferences(context)
        val previous = prefs.getLong(LAST_TRIGGER_AT_KEY, 0L)
        if (previous > 0L && now - previous < refractoryMs) return false
        return prefs.edit().putLong(LAST_TRIGGER_AT_KEY, now).commit()
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

    private fun allEvents(context: Context): JSONArray {
        val raw = preferences(context).getString(EVENTS_KEY, null) ?: return JSONArray()
        return runCatching { JSONArray(raw) }.getOrDefault(JSONArray())
    }
}
