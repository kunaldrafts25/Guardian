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
 * This worker intentionally uses the same stable event_id, API contract,
 * Cognito access token, and Guardian session header as the Flutter client.
 * Flutter import/acknowledgement and cloud synchronisation are independent:
 * an event may be consumed by Flutter while still requiring native cloud sync.
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
        val accessToken = auth?.optString("access_token")?.takeIf { it.isNotBlank() }
        val sessionId = auth?.optString("session_id")?.takeIf { it.isNotBlank() }
        val apiEndpoint = auth?.optString("api_endpoint")?.takeIf { it.isNotBlank() }

        if (accessToken == null || sessionId == null || apiEndpoint == null) {
            Log.w(TAG, "Cloud credentials unavailable for $eventId; retrying after backoff.")
            return Result.retry()
        }

        var connection: HttpURLConnection? = null
        return try {
            val base = apiEndpoint.trimEnd('/')
            val url = URL("$base/incidents")
            connection = url.openConnection() as HttpURLConnection
            connection.requestMethod = "POST"
            connection.connectTimeout = 10_000
            connection.readTimeout = 15_000
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Accept", "application/json")
            connection.setRequestProperty("Authorization", "Bearer $accessToken")
            connection.setRequestProperty("X-Guardian-Session-ID", sessionId)
            connection.doOutput = true

            val payload = buildIncidentPayload(event)
            OutputStreamWriter(connection.outputStream).use { writer ->
                writer.write(payload.toString())
            }

            val code = connection.responseCode
            when {
                code in 200..299 -> {
                    val responseText = readResponse(connection)
                    val incidentId = runCatching {
                        if (responseText.isBlank()) null
                        else JSONObject(responseText).optString("incident_id").takeIf { it.isNotBlank() }
                    }.getOrNull()
                    NativeEmergencyStore.markCloudSynced(
                        applicationContext,
                        eventId,
                        incidentId,
                    )
                    Log.i(TAG, "Cloud sync succeeded for $eventId incident=$incidentId")
                    Result.success()
                }
                code == 401 || code == 403 -> {
                    // Flutter refresh/login will update native cloud auth; WorkManager
                    // keeps the durable event and retries without manufacturing a
                    // second incident because event_id is stable.
                    Log.w(TAG, "Cloud auth rejected for $eventId (HTTP $code); retrying.")
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

        val payload = JSONObject()
            .put("event_id", event.optString("event_id"))
            .put("event_type", event.optString("source", "native_trigger"))
            .put("motion_data", motion)

        val latitude = event.optDouble("latitude", Double.NaN)
        val longitude = event.optDouble("longitude", Double.NaN)
        if (!latitude.isNaN() && !longitude.isNaN()) {
            val location = JSONObject()
                .put("latitude", latitude)
                .put("longitude", longitude)
                .put("accuracy", event.optDouble("accuracy", 0.0))
                .put("source", event.optString("location_provider", "native_cached"))
                .put("received_at", isoUtc(System.currentTimeMillis()))
                .put("timezone_offset", TimeZone.getDefault().rawOffset / 1000)

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
