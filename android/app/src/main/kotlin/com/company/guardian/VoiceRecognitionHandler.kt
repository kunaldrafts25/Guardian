package com.company.guardian

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import java.util.*

/**
 * Handler for voice recognition functionality
 */
class VoiceRecognitionHandler(private val activity: Activity) {
    private val TAG = "VoiceRecognitionHandler"
    private var speechRecognizer: SpeechRecognizer? = null
    private var isListening = false
    private var methodChannel: MethodChannel? = null

    /**
     * Initialize the voice recognition handler
     */
    fun initialize(channel: MethodChannel) {
        methodChannel = channel

        // Check if speech recognition is available
        if (!SpeechRecognizer.isRecognitionAvailable(activity)) {
            Log.e(TAG, "Speech recognition is not available on this device")
            return
        }

        // Create speech recognizer
        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(activity)
        speechRecognizer?.setRecognitionListener(createRecognitionListener())
    }

    /**
     * Start voice recognition
     */
    fun startListening(): Boolean {
        if (isListening) return true
        if (speechRecognizer == null) {
            Log.e(TAG, "Speech recognizer is not initialized")
            return false
        }

        try {
            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault())
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, activity.packageName)
            }

            speechRecognizer?.startListening(intent)
            isListening = true
            Log.d(TAG, "Voice recognition started")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error starting voice recognition: ${e.message}")
            return false
        }
    }

    /**
     * Stop voice recognition
     */
    fun stopListening(): Boolean {
        if (!isListening) return true

        try {
            speechRecognizer?.stopListening()
            isListening = false
            Log.d(TAG, "Voice recognition stopped")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping voice recognition: ${e.message}")
            return false
        }
    }

    /**
     * Create recognition listener
     */
    private fun createRecognitionListener(): RecognitionListener {
        return object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                Log.d(TAG, "Ready for speech")
            }

            override fun onBeginningOfSpeech() {
                Log.d(TAG, "Beginning of speech")
            }

            override fun onRmsChanged(rmsdB: Float) {
                // Not used
            }

            override fun onBufferReceived(buffer: ByteArray?) {
                // Not used
            }

            override fun onEndOfSpeech() {
                Log.d(TAG, "End of speech")
                // Restart listening after a short delay
                activity.runOnUiThread {
                    if (isListening) {
                        speechRecognizer?.stopListening()
                        android.os.Handler().postDelayed({
                            if (isListening) {
                                startListening()
                            }
                        }, 300)
                    }
                }
            }

            override fun onError(error: Int) {
                val errorMessage = getErrorMessage(error)
                Log.e(TAG, "Error in speech recognition: $errorMessage")

                // Restart listening after error (except for some specific errors)
                if (error != SpeechRecognizer.ERROR_NO_MATCH &&
                    error != SpeechRecognizer.ERROR_SPEECH_TIMEOUT &&
                    isListening) {
                    activity.runOnUiThread {
                        android.os.Handler().postDelayed({
                            if (isListening) {
                                startListening()
                            }
                        }, 1000)
                    }
                }
            }

            override fun onResults(results: Bundle?) {
                val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                if (matches != null && matches.isNotEmpty()) {
                    val text = matches[0]
                    Log.d(TAG, "Speech recognized: $text")

                    // Send result to Flutter
                    val resultMap = HashMap<String, Any>()
                    resultMap["text"] = text
                    methodChannel?.invokeMethod("onSpeechRecognized", resultMap)
                }
            }

            override fun onPartialResults(partialResults: Bundle?) {
                // Not used for now
            }

            override fun onEvent(eventType: Int, params: Bundle?) {
                // Not used
            }
        }
    }

    /**
     * Get error message from error code
     */
    private fun getErrorMessage(error: Int): String {
        return when (error) {
            SpeechRecognizer.ERROR_AUDIO -> "Audio recording error"
            SpeechRecognizer.ERROR_CLIENT -> "Client side error"
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Insufficient permissions"
            SpeechRecognizer.ERROR_NETWORK -> "Network error"
            SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Network timeout"
            SpeechRecognizer.ERROR_NO_MATCH -> "No match found"
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "RecognitionService busy"
            SpeechRecognizer.ERROR_SERVER -> "Server error"
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "No speech input"
            else -> "Unknown error"
        }
    }

    /**
     * Clean up resources
     */
    fun destroy() {
        stopListening()
        speechRecognizer?.destroy()
        speechRecognizer = null
    }
}
