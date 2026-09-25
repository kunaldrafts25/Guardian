package com.company.guardian

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * Native emergency cloud outbox.
 *
 * Uses the same stable event_id, protected /incidents contract, Cognito access
 * token, and Guardian session header as Flutter. If the access token has
 * expired, the worker refreshes through Guardian's existing /auth/refresh
 * endpoint using the encrypted refresh token and server-bound session.
 */
class CloudSyncWorker(
    appContext: Context,
    params: WorkerParameters,
) : CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result {
        val eventId = inputData.getString("event_id") ?: return Result.failure()
        val event = NativeEmergencyStore.eventById(applicationContext, eventId)
            ?: return Result.success()

        if (event.optBoolean("cloud_synced", false)) {
            return Result.success()
        }

        val auth = NativeEmergencyStore.cloudAuth(applicationContext)
        if (!hasUsableAccessContext(auth)) {
            Log.w(TAG, "Cloud credentials unavailable for $eventId; retrying after backoff.")
            return Result.retry()
        }

        val eventOwner = event.optString("owner_user_id").takeIf { it.isNotBlank() }
        val authOwner = auth!!.optString("user_id").takeIf { it.isNotBlank() }
        if (eventOwner == null || authOwner == null || eventOwner != authOwner) {
            Log.e(TAG, "Refusing cross-account native emergency upload for $eventId.")
            return Result.failure()
        }

        return uploadEvent(event, auth, allowRefresh = true)
    }

    private fun uploadEvent(
        event: JSONObject,
        auth: JSONObject,
        allowRefresh: Boolean,
    ): Result {
        val eventId = event.optString("event_id")
        val accessToken = auth.optString("access_token").takeIf { it.isNotBlank() }
            ?: return Result.retry()
        val sessionId = auth.optString("session_id").takeIf { it.isNotBlank() }
            ?: return Result.retry()
        val apiEndpoint = auth.optString("api_endpoint").takeIf { it.isNotBlank() }
            ?: return Result.retry()

        var connection: HttpURLConnection? = null
        return try {
            val base = apiEndpoint.trimEnd('/')
            connection = URL("$base/incidents").openConnection() as HttpURLConnection
            connection.requestMethod = "POST"
            connection.connectTimeout = 10_000
            connection.readTimeout = 15_000
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Accept", "application/json")
            connection.setRequestProperty("Authorization", "Bearer $accessToken")
            connection.setRequestProperty("X-Guardian-Session-ID", sessionId)
            connection.doOutput = true

            OutputStreamWriter(connection.outputStream).use { writer ->
                writer.write(buildIncidentPayload(event).toString())
            }

            val code = connection.responseCode
            when {
                code in 200..299 -> {
                    val responseText = readResponse(connection)
                    val incidentId = runCatching {
                        if (responseText.isBlank()) null
                        else JSONObject(responseText)
                            .optString("incident_id")
                            .takeIf { it.isNotBlank() }
                    }.getOrNull()
                    NativeEmergencyStore.markCloudSynced(
                        applicationContext,
                        eventId,
                        incidentId,
                    )
                    Log.i(TAG, "Cloud sync succeeded for $eventId incident=$incidentId")
                    Result.success()
                }
                (code == 401 || code == 403) && allowRefresh -> {
                    val refreshed = refreshCloudAuth(auth)
                    if (refreshed != null) {
                        uploadEvent(event, refreshed, allowRefresh = false)
                    } else {
                        Log.w(TAG, "Cloud auth refresh failed for $eventId; retrying later.")
                        Result.retry()
                    }
                }
                code == 401 || code == 403 -> {
                    Log.w(TAG, "Cloud auth rejected after refresh for $eventId; retrying later.")
                    Result.retry()
                }
                code == 408 || code == 425 || code == 429 || code >= 500 -> {
                    Log.w(TAG, "Transient cloud failure for $eventId (HTTP $code); retrying.")
                    Result.retry()
                }
                else -> {
                    val body = readResponse(connection)
                    Log.e(TAG, "Permanent cloud request failure for $eventId: HTTP $code $body")
                    Result.failure()
                }
            }
        } catch (error: Exception) {
            Log.e(TAG, "Cloud sync exception for $eventId: ${error.javaClass.simpleName}")
            Result.retry()
        } finally {
            connection?.disconnect()
        }
    }

    private fun refreshCloudAuth(currentAuth: JSONObject): JSONObject? {
        val refreshToken = currentAuth.optString("refresh_token").takeIf { it.isNotBlank() }
            ?: return null
        val sessionId = currentAuth.optString("session_id").takeIf { it.isNotBlank() }
            ?: return null
        val apiEndpoint = currentAuth.optString("api_endpoint").takeIf { it.isNotBlank() }
            ?: return null

        var connection: HttpURLConnection? = null
        return try {
            val base = apiEndpoint.trimEnd('/')
            connection = URL("$base/auth/refresh").openConnection() as HttpURLConnection
            connection.requestMethod = "POST"
            connection.connectTimeout = 10_000
            connection.readTimeout = 15_000
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Accept", "application/json")
            connection.doOutput = true

            val requestBody = JSONObject()
                .put("refresh_token", refreshToken)
                .put("session_id", sessionId)
            OutputStreamWriter(connection.outputStream).use { writer ->
                writer.write(requestBody.toString())
            }

            if (connection.responseCode !in 200..299) {
                Log.w(TAG, "Native token refresh rejected (HTTP ${connection.responseCode}).")
                return null
            }

            val response = JSONObject(readResponse(connection))
            val accessToken = response.optString("access_token").takeIf { it.isNotBlank() }
                ?: return null
            val returnedSessionId = response.optString("session_id")
                .takeIf { it.isNotBlank() }
                ?: sessionId

            val refreshed = JSONObject()
                .put("user_id", currentAuth.optString("user_id"))
                .put("access_token", accessToken)
                .put("refresh_token", refreshToken)
                .put("session_id", returnedSessionId)
                .put("api_endpoint", apiEndpoint)
                .put("updated_at_ms", System.currentTimeMillis())
            NativeEmergencyStore.saveCloudAuth(applicationContext, refreshed)
            refreshed
        } catch (error: Exception) {
            Log.w(TAG, "Native token refresh failed: ${error.javaClass.simpleName}")
            null
        } finally {
            connection?.disconnect()
        }
    }

    private fun hasUsableAccessContext(auth: JSONObject?): Boolean {
        if (auth == null) return false
        return auth.optString("user_id").isNotBlank() &&
            auth.optString("access_token").isNotBlank() &&
            auth.optString("session_id").isNotBlank() &&
            auth.optString("api_endpoint").isNotBlank()
    }

    private fun buildIncidentPayload(event: JSONObject): JSONObject {
        val motion = JSONObject()
        val evidence = event.optJSONObject("sensor_evidence")
        if (evidence != null) {
            val keys = evidence.keys()
            while (keys.hasNext()) {
                val key = keys.next()
                motion.put(key, evidence.opt(key))
            }
        }

        val occurredAtMs = event.optLong("occurred_at_ms", 0L)
        if (occurredAtMs > 0L) {
            motion.put("event_occurred_at", isoUtc(occurredAtMs))
        }
        motion.put("trigger_source", event.optString("source", "native_trigger"))
        motion.put("native_dispatch", true)
        motion.put("snapshot_version", event.optInt("snapshot_version", 0))
        motion.put(
            "local_sms_accepted_count",
            event.optJSONArray("accepted_phones")?.length() ?: 0,
        )

        val localDelivery = org.json.JSONArray()
        val acceptedContactIds = event.optJSONArray("accepted_contact_ids")
        if (acceptedContactIds != null) {
            for (index in 0 until acceptedContactIds.length()) {
                localDelivery.put(
                    JSONObject()
                        .put("contact_id", acceptedContactIds.optString(index))
                        .put("state", "OS_ACCEPTED"),
                )
            }
        }
        val failedContactIds = event.optJSONArray("failed_contact_ids")
        if (failedContactIds != null) {
            for (index in 0 until failedContactIds.length()) {
                localDelivery.put(
                    JSONObject()
                        .put("contact_id", failedContactIds.optString(index))
                        .put("state", "FAILED"),
                )
            }
        }
        motion.put("local_sms_delivery", localDelivery)

        val payload = JSONObject()
            .put("event_id", event.optString("event_id"))
            .put("event_type", event.optString("source", "native_trigger"))
            .put("motion_data", motion)

        val latitude = event.optDouble("latitude", Double.NaN)
        val longitude = event.optDouble("longitude", Double.NaN)
        if (!latitude.isNaN() && !longitude.isNaN()) {
            val nowMs = System.currentTimeMillis()
            val location = JSONObject()
                .put("latitude", latitude)
                .put("longitude", longitude)
                .put("accuracy", event.optDouble("accuracy", 0.0))
                .put("source", event.optString("location_provider", "native_cached"))
                .put("received_at", isoUtc(nowMs))
                .put("timezone_offset", TimeZone.getDefault().getOffset(nowMs) / 1000)

            val capturedAtMs = event.optLong("location_time_ms", 0L)
            if (capturedAtMs > 0L) {
                location.put("captured_at", isoUtc(capturedAtMs))
            }
            payload.put("location", location)
        }

        return payload
    }

    private fun readResponse(connection: HttpURLConnection): String {
        val stream = if (connection.responseCode in 200..299) {
            connection.inputStream
        } else {
            connection.errorStream
        } ?: return ""
        return BufferedReader(InputStreamReader(stream)).use { it.readText() }
    }

    private fun isoUtc(epochMs: Long): String {
        val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        formatter.timeZone = TimeZone.getTimeZone("UTC")
        return formatter.format(Date(epochMs))
    }

    companion object {
        private const val TAG = "CloudSyncWorker"
    }
}
