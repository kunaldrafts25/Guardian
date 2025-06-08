package com.company.guardian

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.content.BroadcastReceiver
import android.util.Log
import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

class MainActivity: FlutterActivity() {
    private val EMERGENCY_CHANNEL = "com.guardian/emergency"
    private val VOICE_CHANNEL = "com.guardian/voice_recognition"
    private val BATTERY_CHANNEL = "com.guardian/battery"
    private val RECORD_AUDIO_REQUEST_CODE = 101

    private var powerButtonReceiver: PowerButtonReceiver? = null
    private var isTripleTapListening = false
    private var voiceRecognitionHandler: VoiceRecognitionHandler? = null
    private var batteryHandler: BatteryHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Set up emergency channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, EMERGENCY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startTripleTapDetection" -> {
                    val success = startTripleTapDetection()
                    result.success(success)
                }
                "stopTripleTapDetection" -> {
                    val success = stopTripleTapDetection()
                    result.success(success)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Set up voice recognition channel
        val voiceChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VOICE_CHANNEL)
        voiceChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startVoiceRecognition" -> {
                    if (checkAudioPermission()) {
                        if (voiceRecognitionHandler == null) {
                            voiceRecognitionHandler = VoiceRecognitionHandler(this)
                            voiceRecognitionHandler?.initialize(voiceChannel)
                        }
                        val success = voiceRecognitionHandler?.startListening() ?: false
                        result.success(success)
                    } else {
                        requestAudioPermission()
                        result.success(false)
                    }
                }
                "stopVoiceRecognition" -> {
                    val success = voiceRecognitionHandler?.stopListening() ?: true
                    result.success(success)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Set up battery channel
        batteryHandler = BatteryHandler(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_CHANNEL).setMethodCallHandler { call, result ->
            batteryHandler?.handleMethodCall(call, result)
        }
    }

    private fun startTripleTapDetection(): Boolean {
        if (isTripleTapListening) {
            return true
        }

        try {
            powerButtonReceiver = PowerButtonReceiver()
            val filter = IntentFilter(Intent.ACTION_SCREEN_OFF)
            filter.addAction(Intent.ACTION_SCREEN_ON)
            registerReceiver(powerButtonReceiver, filter)
            isTripleTapListening = true
            Log.d("Guardian", "Triple tap detection started")
            return true
        } catch (e: Exception) {
            Log.e("Guardian", "Error starting triple tap detection: ${e.message}")
            return false
        }
    }

    private fun stopTripleTapDetection(): Boolean {
        if (!isTripleTapListening) {
            return true
        }

        try {
            powerButtonReceiver?.let {
                unregisterReceiver(it)
                powerButtonReceiver = null
            }
            isTripleTapListening = false
            Log.d("Guardian", "Triple tap detection stopped")
            return true
        } catch (e: Exception) {
            Log.e("Guardian", "Error stopping triple tap detection: ${e.message}")
            return false
        }
    }

    private fun checkAudioPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestAudioPermission() {
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.RECORD_AUDIO),
            RECORD_AUDIO_REQUEST_CODE
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == RECORD_AUDIO_REQUEST_CODE && grantResults.isNotEmpty()) {
            if (grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                Log.d("Guardian", "Audio permission granted")
                // Notify Flutter that permission is granted
                MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, VOICE_CHANNEL)
                    .invokeMethod("onPermissionGranted", null)
            } else {
                Log.d("Guardian", "Audio permission denied")
                // Notify Flutter that permission is denied
                MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, VOICE_CHANNEL)
                    .invokeMethod("onPermissionDenied", null)
            }
        }
    }

    override fun onDestroy() {
        stopTripleTapDetection()
        voiceRecognitionHandler?.destroy()
        voiceRecognitionHandler = null
        batteryHandler = null
        super.onDestroy()
    }

    inner class PowerButtonReceiver : BroadcastReceiver() {
        private val MAX_CLICK_DURATION = 1000L // 1 second
        private val clicks = mutableListOf<Long>()
        private val handler = Handler(Looper.getMainLooper())
        private val resetRunnable = Runnable {
            clicks.clear()
        }

        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                Intent.ACTION_SCREEN_OFF, Intent.ACTION_SCREEN_ON -> {
                    val now = System.currentTimeMillis()
                    clicks.add(now)

                    // Reset after MAX_CLICK_DURATION
                    handler.removeCallbacks(resetRunnable)
                    handler.postDelayed(resetRunnable, MAX_CLICK_DURATION)

                    // Check for triple tap
                    if (clicks.size >= 6) { // 3 screen off + 3 screen on events
                        val duration = clicks.last() - clicks[clicks.size - 6]
                        if (duration <= MAX_CLICK_DURATION * 3) {
                            Log.d("Guardian", "Triple tap detected!")
                            triggerEmergencyAlert()
                            clicks.clear()
                        }
                    }
                }
            }
        }

        private fun triggerEmergencyAlert() {
            // Send message to Flutter side
            Handler(Looper.getMainLooper()).post {
                MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, EMERGENCY_CHANNEL).invokeMethod("onTripleTap", null)
            }
        }
    }
}
