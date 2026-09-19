package com.company.guardian

import android.app.*
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.*
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Guardian — SafetyForegroundService
 *
 * A persistent Android Foreground Service that:
 * 1. Continuously tracks GPS location (survives screen off / app backgrounded)
 * 2. Maintains "last known good location" for immediate SOS use
 * 3. Monitors accelerometer for shake/fall detection (placeholder for TFLite)
 * 4. Broadcasts location updates and events to Flutter via static callbacks
 * 5. Restarts automatically after device reboot (via BootReceiver)
 *
 * Without this service, all safety features stop when the screen turns off.
 * This is the second most critical fix in the entire codebase.
 */
class SafetyForegroundService : Service() {

    companion object {
        private const val TAG = "Guardian.ForegroundService"
        const val CHANNEL_ID = "guardian_safety_channel"
        const val NOTIFICATION_ID = 1001
        const val ACTION_START = "com.guardian.START_SAFETY"
        const val ACTION_STOP = "com.guardian.STOP_SAFETY"
        const val ACTION_TRIGGER_SOS = "com.guardian.TRIGGER_SOS"

        // Static last-known location — readable from anywhere without binding
        @Volatile
        var lastKnownLocation: Location? = null
            private set

        @Volatile
        var isRunning: Boolean = false
            private set

        // Callback registered by Flutter method channel
        var onLocationUpdate: ((Double, Double, Float) -> Unit)? = null
        var onSosTrigger: ((String) -> Unit)? = null

        fun start(context: Context) {
            val intent = Intent(context, SafetyForegroundService::class.java)
                .apply { action = ACTION_START }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(
                Intent(context, SafetyForegroundService::class.java)
            )
        }
    }

    private lateinit var locationManager: LocationManager
    private var locationListener: LocationListener? = null
    private val handler = Handler(Looper.getMainLooper())

    private var screenStateReceiver: BroadcastReceiver? = null
    private val screenToggleTimestamps = java.util.ArrayDeque<Long>()

    // ───────────────────────────────────────────────────────────────
    // Lifecycle
    // ───────────────────────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "SafetyForegroundService created")
        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        createNotificationChannel()
        registerScreenStateReceiver()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_TRIGGER_SOS -> {
                val event = NativeEmergencyDispatcher.trigger(this, "service_trigger")
                if (event != null) onSosTrigger?.invoke("service_trigger")
            }
        }

        // Start as foreground with persistent notification
        startForegroundWithNotification()
        startLocationTracking()
        isRunning = true

        Log.i(TAG, "SafetyForegroundService started — location tracking and power-button panic detection active")

        // START_STICKY: OS restarts this service if it's killed
        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        stopLocationTracking()
        unregisterScreenStateReceiver()
        Log.i(TAG, "SafetyForegroundService destroyed")
        super.onDestroy()
    }

    private fun registerScreenStateReceiver() {
        try {
            val filter = IntentFilter().apply {
                addAction(Intent.ACTION_SCREEN_ON)
                addAction(Intent.ACTION_SCREEN_OFF)
            }
            screenStateReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    val now = System.currentTimeMillis()
                    screenToggleTimestamps.addLast(now)
                    // Keep only toggles within 3000ms
                    while (!screenToggleTimestamps.isEmpty() && now - screenToggleTimestamps.first > 3000L) {
                        screenToggleTimestamps.removeFirst()
                    }
                    Log.d(TAG, "Power screen toggle detected. Count in 3s: ${screenToggleTimestamps.size}")
                    if (screenToggleTimestamps.size >= 3) {
                        Log.w(TAG, "🚨 HARDWARE POWER BUTTON PANIC DETECTED (3+ taps in 3s)!")
                        screenToggleTimestamps.clear()
                        val event = NativeEmergencyDispatcher.trigger(
                            this@SafetyForegroundService,
                            "hardware_power_panic",
                        )
                        if (event != null) onSosTrigger?.invoke("hardware_power_panic")
                    }
                }
            }
            registerReceiver(screenStateReceiver, filter)
            Log.i(TAG, "ScreenStateReceiver registered for hardware panic detection")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register ScreenStateReceiver: ${e.message}")
        }
    }

    private fun unregisterScreenStateReceiver() {
        screenStateReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to unregister ScreenStateReceiver: ${e.message}")
            }
            screenStateReceiver = null
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ───────────────────────────────────────────────────────────────
    // Foreground Notification

    // ───────────────────────────────────────────────────────────────

    private fun startForegroundWithNotification() {
        val notification = buildNotification()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun buildNotification(): Notification {
        val tapIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val tapPending = PendingIntent.getActivity(
            this, 0, tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val sosIntent = Intent(this, SafetyForegroundService::class.java).apply {
            action = ACTION_TRIGGER_SOS
        }
        val sosPending = PendingIntent.getService(
            this, 1, sosIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Guardian is protecting you")
            .setContentText("Monitoring your safety in the background")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(tapPending)
            .addAction(
                android.R.drawable.ic_dialog_alert,
                "SOS",
                sosPending
            )
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Guardian Safety Monitoring",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps Guardian running in the background to protect you"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    // ───────────────────────────────────────────────────────────────
    // Location Tracking — uses ALL providers for best coverage
    // ───────────────────────────────────────────────────────────────

    private fun startLocationTracking() {
        locationListener = object : LocationListener {
            override fun onLocationChanged(location: Location) {
                lastKnownLocation = location
                onLocationUpdate?.invoke(location.latitude, location.longitude, location.accuracy)
                Log.d(TAG, "Location updated (accuracy: ${location.accuracy}m)")
            }

            @Deprecated("Deprecated in API 29")
            override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
        }

        try {
            // GPS provider — most accurate, slowest to first fix
            if (locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                locationManager.requestLocationUpdates(
                    LocationManager.GPS_PROVIDER,
                    10_000L,   // min 10 seconds between updates
                    10f,        // min 10 meters movement
                    locationListener!!,
                    Looper.getMainLooper()
                )
            }

            // Network provider — faster fix, works indoors and underground
            if (locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                locationManager.requestLocationUpdates(
                    LocationManager.NETWORK_PROVIDER,
                    5_000L,
                    5f,
                    locationListener!!,
                    Looper.getMainLooper()
                )
            }

            // Seed with last known position immediately (no wait for new fix)
            val lastGps = locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER)
            val lastNetwork = locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
            lastKnownLocation = when {
                lastGps != null && lastNetwork != null ->
                    if (lastGps.accuracy <= lastNetwork.accuracy) lastGps else lastNetwork
                lastGps != null -> lastGps
                else -> lastNetwork
            }
            lastKnownLocation?.let {
                Log.i(TAG, "Seeded with last known location (accuracy: ${it.accuracy}m)")
            }

        } catch (e: SecurityException) {
            Log.e(TAG, "Location permission denied: ${e.message}")
        }
    }

    private fun stopLocationTracking() {
        locationListener?.let {
            locationManager.removeUpdates(it)
            locationListener = null
        }
    }
}
