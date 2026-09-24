package com.company.guardian

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

/**
 * P1-04: Native Emergency Cloud-Outbox.
 * Synchronizes native-triggered incidents to AWS ApiGateway when the device has network connectivity.
 * 
 * CHALLENGES & LIMITATIONS (Auth Token Lifecycle):
 * Native uploads require a valid AWS Cognito ID token to hit the API Gateway.
 * However, Cognito ID tokens expire after 1 hour. If the app has been killed in the background
 * for >1 hour, the cached `id_token` in NativeEmergencyStore will be expired, and this WorkManager
 * request will receive HTTP 401 Unauthorized. 
 * 
 * Ideally, the native layer would use the `refresh_token` to mint a new `id_token` directly with Cognito.
 * However, implementing the SRP authentication flow or refresh flow in native Kotlin, while 
 * duplicating the Amplify Flutter logic, is out of scope. 
 * For now, this uploads *if* the token is fresh, otherwise relies on Flutter's next startup to reconcile.
 */
class CloudSyncWorker(
    appContext: Context, 
    params: WorkerParameters
) : CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result {
        val eventId = inputData.getString("event_id") ?: return Result.failure()
        
        Log.i("CloudSyncWorker", "Attempting cloud sync for native emergency: $eventId")
        
        val allEvents = NativeEmergencyStore.pendingEvents(applicationContext)
        var targetEvent: JSONObject? = null
        for (i in 0 until allEvents.length()) {
            val ev = allEvents.getJSONObject(i)
            if (ev.optString("event_id") == eventId) {
                targetEvent = ev
                break
            }
        }
        
        if (targetEvent == null || targetEvent.optBoolean("consumed", false)) {
            Log.i("CloudSyncWorker", "Event $eventId already consumed or missing.")
            return Result.success()
        }

        val snapshot = NativeEmergencyStore.snapshot(applicationContext)
        val idToken = snapshot?.optString("id_token")
        val apiEndpoint = snapshot?.optString("api_endpoint")
        
        if (idToken.isNullOrBlank() || apiEndpoint.isNullOrBlank()) {
            Log.w("CloudSyncWorker", "Missing auth token or API endpoint. Cannot sync natively.")
            return Result.failure()
        }
        
        return try {
            val url = URL("$apiEndpoint/incident")
            val conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.setRequestProperty("Content-Type", "application/json")
            conn.setRequestProperty("Authorization", "Bearer $idToken")
            conn.doOutput = true

            // Construct cloud payload mimicking Flutter's ingestNativeEmergencyEvent
            val payload = JSONObject().apply {
                put("event_id", eventId)
                put("event_type", targetEvent.optString("source", "native_trigger"))
                put("timestamp", targetEvent.optLong("occurred_at_ms"))
                
                val location = JSONObject()
                if (!targetEvent.isNull("latitude")) {
                    location.put("latitude", targetEvent.optDouble("latitude"))
                    location.put("longitude", targetEvent.optDouble("longitude"))
                    location.put("accuracy", targetEvent.optDouble("accuracy"))
                }
                put("location", location)
                
                val motion = targetEvent.optJSONObject("sensor_evidence") ?: JSONObject()
                motion.put("local_sms_accepted_count", targetEvent.optJSONArray("accepted_phones")?.length() ?: 0)
                put("motion_data", motion)
            }

            OutputStreamWriter(conn.outputStream).use { it.write(payload.toString()) }
            
            val code = conn.responseCode
            if (code in 200..299) {
                Log.i("CloudSyncWorker", "Cloud sync successful for $eventId")
                NativeEmergencyStore.acknowledge(applicationContext, eventId)
                Result.success()
            } else if (code == 401 || code == 403) {
                Log.e("CloudSyncWorker", "Cloud sync auth failed (token likely expired): $code. Retrying later.")
                Result.retry() // We retry so that if Flutter updates the token, this eventually succeeds
            } else {
                Log.e("CloudSyncWorker", "Cloud sync failed with HTTP $code")
                Result.retry()
            }
        } catch (e: Exception) {
            Log.e("CloudSyncWorker", "Cloud sync exception: ${e.message}")
            Result.retry()
        }
    }
}
