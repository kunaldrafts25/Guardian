package com.company.guardian

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.content.BroadcastReceiver
import android.util.Log
import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "Guardian.MainActivity"
        private const val EMERGENCY_CHANNEL   = "com.guardian/emergency"
        private const val VOICE_CHANNEL       = "com.guardian/voice_recognition"
        private const val BATTERY_CHANNEL     = "com.guardian/battery"
        private const val SMS_CHANNEL         = "com.guardian/sms"
        private const val SERVICE_CHANNEL     = "com.guardian/service"
        private const val RECORD_AUDIO_REQUEST = 101
        private const val SEND_SMS_REQUEST    = 102
    }

    private var powerButtonReceiver: PowerButtonReceiver? = null
    private var isTripleTapListening = false
    private var voiceRecognitionHandler: VoiceRecognitionHandler? = null
    private var batteryHandler: BatteryHandler? = null

    // ─────────────────────────────────────────────────────
    // FlutterEngine setup — register all method channels
    // ─────────────────────────────────────────────────────

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        setupEmergencyChannel(flutterEngine)
        setupVoiceChannel(flutterEngine)
        setupBatteryChannel(flutterEngine)
        setupSmsChannel(flutterEngine)
        setupServiceChannel(flutterEngine)

        // Register location callback from foreground service → Flutter
        SafetyForegroundService.onLocationUpdate = { lat, lng, accuracy ->
            Handler(Looper.getMainLooper()).post {
                MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SERVICE_CHANNEL)
                    .invokeMethod("onLocationUpdate", mapOf(
                        "latitude" to lat,
                        "longitude" to lng,
                        "accuracy" to accuracy
                    ))
            }
        }

        // Register SOS trigger from foreground service → Flutter
        // 'hardware_power_panic' → onHardwarePanic (zero-delay critical escalation)
        // 'service_trigger'     → onServiceSosTrigger (standard notification SOS)
        SafetyForegroundService.onSosTrigger = { source ->
            Handler(Looper.getMainLooper()).post {
                val methodName = if (source == "hardware_power_panic") "onHardwarePanic" else "onServiceSosTrigger"
                MethodChannel(flutterEngine.dartExecutor.binaryMessenger, EMERGENCY_CHANNEL)
                    .invokeMethod(methodName, mapOf("source" to source))
            }
        }

    }

    // ─────────────────────────────────────────────────────
    // Emergency Channel — triple-tap power button
    // ─────────────────────────────────────────────────────

    private fun setupEmergencyChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, EMERGENCY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startTripleTapDetection" -> result.success(startTripleTapDetection())
                    "stopTripleTapDetection"  -> result.success(stopTripleTapDetection())
                    else -> result.notImplemented()
                }
            }
    }

    // ─────────────────────────────────────────────────────
    // Voice Channel — native SpeechRecognizer
    // ─────────────────────────────────────────────────────

    private fun setupVoiceChannel(flutterEngine: FlutterEngine) {
        val voiceChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VOICE_CHANNEL)
        voiceChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startVoiceRecognition" -> {
                    if (checkPermission(Manifest.permission.RECORD_AUDIO)) {
                        if (voiceRecognitionHandler == null) {
                            voiceRecognitionHandler = VoiceRecognitionHandler(this)
                            voiceRecognitionHandler?.initialize(voiceChannel)
                        }
                        result.success(voiceRecognitionHandler?.startListening() ?: false)
                    } else {
                        requestPermission(Manifest.permission.RECORD_AUDIO, RECORD_AUDIO_REQUEST)
                        result.success(false)
                    }
                }
                "stopVoiceRecognition" -> result.success(voiceRecognitionHandler?.stopListening() ?: true)
                else -> result.notImplemented()
            }
        }
    }

    // ─────────────────────────────────────────────────────
    // Battery Channel
    // ─────────────────────────────────────────────────────

    private fun setupBatteryChannel(flutterEngine: FlutterEngine) {
        batteryHandler = BatteryHandler(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_CHANNEL)
            .setMethodCallHandler { call, result ->
                batteryHandler?.handleMethodCall(call, result)
            }
    }

    // ─────────────────────────────────────────────────────
    // SMS Channel — automatic SmsManager (no user tap)
    // ─────────────────────────────────────────────────────

    private fun setupSmsChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sendEmergencySms" -> {
                        val phones  = call.argument<List<String>>("phones") ?: emptyList()
                        val message = call.argument<String>("message") ?: ""

                        if (!SmsHelper.hasSmsPermission(this)) {
                            requestPermission(Manifest.permission.SEND_SMS, SEND_SMS_REQUEST)
                            result.error("NO_PERMISSION", "SEND_SMS permission required", null)
                            return@setMethodCallHandler
                        }

                        // Run on background thread — SMS sending can block briefly
                        Thread {
                            val results = SmsHelper.sendEmergencySms(this, phones, message)
                            val successCount = results.values.count { it }
                            Handler(Looper.getMainLooper()).post {
                                result.success(mapOf(
                                    "sent" to successCount,
                                    "total" to phones.size,
                                    "allSuccess" to (successCount == phones.size)
                                ))
                            }
                        }.start()
                    }
                    "hasSmsPermission" -> result.success(SmsHelper.hasSmsPermission(this))
                    else -> result.notImplemented()
                }
            }
    }

    // ─────────────────────────────────────────────────────
    // Service Channel — control SafetyForegroundService
    // ─────────────────────────────────────────────────────

    private fun setupServiceChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SERVICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startSafetyService" -> {
                        SafetyForegroundService.start(this)
                        result.success(true)
                    }
                    "stopSafetyService" -> {
                        SafetyForegroundService.stop(this)
                        result.success(true)
                    }
                    "isServiceRunning" -> result.success(SafetyForegroundService.isRunning)
                    "getLastLocation" -> {
                        val loc = SafetyForegroundService.lastKnownLocation
                        result.success(loc?.let {
                            mapOf("latitude" to it.latitude, "longitude" to it.longitude, "accuracy" to it.accuracy)
                        })
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ─────────────────────────────────────────────────────
    // Triple-tap detection
    // ─────────────────────────────────────────────────────

    private fun startTripleTapDetection(): Boolean {
        if (isTripleTapListening) return true
        return try {
            powerButtonReceiver = PowerButtonReceiver()
            val filter = IntentFilter(Intent.ACTION_SCREEN_OFF)
            filter.addAction(Intent.ACTION_SCREEN_ON)
            registerReceiver(powerButtonReceiver, filter)
            isTripleTapListening = true
            Log.d(TAG, "Triple tap detection started")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error starting triple tap: ${e.message}")
            false
        }
    }

    private fun stopTripleTapDetection(): Boolean {
        if (!isTripleTapListening) return true
        return try {
            powerButtonReceiver?.let { unregisterReceiver(it) }
            powerButtonReceiver = null
            isTripleTapListening = false
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping triple tap: ${e.message}")
            false
        }
    }

    // ─────────────────────────────────────────────────────
    // Permission helpers
    // ─────────────────────────────────────────────────────

    private fun checkPermission(permission: String) =
        ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED

    private fun requestPermission(permission: String, requestCode: Int) {
        ActivityCompat.requestPermissions(this, arrayOf(permission), requestCode)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        when (requestCode) {
            RECORD_AUDIO_REQUEST -> {
                val method = if (granted) "onPermissionGranted" else "onPermissionDenied"
                MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, VOICE_CHANNEL)
                    .invokeMethod(method, null)
            }
        }
    }

    // ─────────────────────────────────────────────────────
    // Lifecycle
    // ─────────────────────────────────────────────────────

    override fun onDestroy() {
        stopTripleTapDetection()
        voiceRecognitionHandler?.destroy()
        voiceRecognitionHandler = null
        batteryHandler = null
        super.onDestroy()
    }

    // ─────────────────────────────────────────────────────
    // Inner: Power Button Triple-Tap Receiver
    // ─────────────────────────────────────────────────────

    inner class PowerButtonReceiver : BroadcastReceiver() {
        private val MAX_DURATION = 1500L
        private val clicks = mutableListOf<Long>()
        private val handler = Handler(Looper.getMainLooper())
        private val resetRunnable = Runnable { clicks.clear() }

        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action in listOf(Intent.ACTION_SCREEN_OFF, Intent.ACTION_SCREEN_ON)) {
                val now = System.currentTimeMillis()
                clicks.add(now)
                handler.removeCallbacks(resetRunnable)
                handler.postDelayed(resetRunnable, MAX_DURATION)

                // 6 events = 3×(screen_off + screen_on) = triple press
                if (clicks.size >= 6) {
                    val duration = clicks.last() - clicks[clicks.size - 6]
                    if (duration <= MAX_DURATION * 3) {
                        Log.d(TAG, "Triple tap SOS detected")
                        clicks.clear()
                        MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, EMERGENCY_CHANNEL)
                            .invokeMethod("onTripleTap", null)
                    }
                }
            }
        }
    }
}
