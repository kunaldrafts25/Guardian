package com.company.guardian

import android.app.*
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.*
import android.util.Log
import androidx.core.app.NotificationCompat
import android.Manifest
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import kotlin.math.*

/**
 * Guardian — SafetyForegroundService
 *
 * A persistent Android Foreground Service that:
 * 1. Continuously tracks GPS location (survives screen off / app backgrounded)
 * 2. Acquires PARTIAL_WAKE_LOCK to prevent CPU sleep during Android Doze mode
 * 3. Monitors native hardware accelerometer for Fall / Collapse impact detection
 * 4. Detects native Shake-to-SOS gestures even when screen is locked in pocket
 * 5. Monitors GPS Route Deviation from active navigation polylines
 * 6. Detects the supported screen-toggle panic gesture while running
 * 7. Broadcasts location updates and events to Flutter via static callbacks
 * 8. Restarts automatically after device reboot (via BootReceiver)
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

        // Active route waypoints for background deviation monitoring
        @Volatile
        var activeRoutePoints: List<Pair<Double, Double>> = emptyList()

        // Callbacks registered by Flutter method channel
        var onLocationUpdate: ((Double, Double, Float) -> Unit)? = null
        var onSosTrigger: ((String) -> Unit)? = null
        var onRouteDeviation: ((Double) -> Unit)? = null
        var onAnomalyDetected: ((String, Map<String, Any>) -> Unit)? = null

        fun setActiveRoute(points: List<Pair<Double, Double>>) {
            activeRoutePoints = points
            Log.i(TAG, "Active route updated: ${points.size} waypoints")
        }

        fun clearActiveRoute() {
            activeRoutePoints = emptyList()
            Log.i(TAG, "Active route cleared")
        }

        fun start(context: Context) {
            val hasLocation = ContextCompat.checkSelfPermission(
                context, Manifest.permission.ACCESS_FINE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED || ContextCompat.checkSelfPermission(
                context, Manifest.permission.ACCESS_COARSE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED

            if (!hasLocation) {
                Log.w(TAG, "Cannot start SafetyForegroundService: location permission not granted yet")
                return
            }

            try {
                val intent = Intent(context, SafetyForegroundService::class.java)
                    .apply { action = ACTION_START }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start SafetyForegroundService: ${e.message}")
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
    private var wakeLock: PowerManager.WakeLock? = null

    // Native Sensor Management
    private var sensorManager: SensorManager? = null
    private var accelerometer: Sensor? = null
    private var sensorListener: SensorEventListener? = null

    // Fall & Impact Detection State Machine
    private var lastFreeFallTimestamp: Long = 0L
    private var lastImpactTimestamp: Long = 0L
    private var stillStartTime: Long = 0L
    private var isMonitoringStillness: Boolean = false

    // Shake Detection State Machine
    private val shakeTimestamps = java.util.ArrayDeque<Long>()
    private var lastShakeTriggerTimestamp: Long = 0L

    // Route deviation tracking
    private var consecutiveDeviations = 0

    private var screenStateReceiver: BroadcastReceiver? = null
    private val screenToggleTimestamps = java.util.ArrayDeque<Long>()

    // ───────────────────────────────────────────────────────────────
    // Lifecycle
    // ───────────────────────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "SafetyForegroundService created")

        // Acquire WakeLock to survive Doze mode
        acquireWakeLock()

        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        createNotificationChannel()
        registerScreenStateReceiver()
        startSensorMonitoring()
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

        Log.i(TAG, "SafetyForegroundService started — location tracking, sensor anomaly engine, and panic detection active")

        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        stopLocationTracking()
        stopSensorMonitoring()
        unregisterScreenStateReceiver()
        releaseWakeLock()
        Log.i(TAG, "SafetyForegroundService destroyed")
        super.onDestroy()
    }

    // ───────────────────────────────────────────────────────────────
    // WakeLock Management
    // ───────────────────────────────────────────────────────────────

    private fun acquireWakeLock() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "Guardian:SafetyForegroundServiceWakeLock"
            ).apply {
                setReferenceCounted(false)
                acquire(24 * 60 * 60 * 1000L) // 24 hour safety cap
            }
            Log.i(TAG, "PartialWakeLock acquired — CPU will remain active in Doze mode")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to acquire PartialWakeLock: ${e.message}")
        }
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
                Log.i(TAG, "PartialWakeLock released")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing PartialWakeLock: ${e.message}")
        }
    }

    // ───────────────────────────────────────────────────────────────
    // Native Sensor Monitoring (Fall & Shake)
    // ───────────────────────────────────────────────────────────────

    private fun startSensorMonitoring() {
        try {
            sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
            accelerometer = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
            if (accelerometer == null) {
                Log.w(TAG, "Accelerometer not available on device")
                return
            }

            sensorListener = object : SensorEventListener {
                override fun onSensorChanged(event: SensorEvent?) {
                    if (event == null) return
                    val x = event.values[0]
                    val y = event.values[1]
                    val z = event.values[2]
                    val magnitude = sqrt((x * x + y * y + z * z).toDouble())
                    val now = System.currentTimeMillis()

                    processShake(magnitude, now)
                    processFall(magnitude, now)
                }

                override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
            }

            sensorManager?.registerListener(
                sensorListener,
                accelerometer,
                SensorManager.SENSOR_DELAY_GAME
            )
            Log.i(TAG, "Native accelerometer listener registered for Fall & Shake detection")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register accelerometer listener: ${e.message}")
        }
    }

    private fun stopSensorMonitoring() {
        sensorListener?.let {
            sensorManager?.unregisterListener(it)
            sensorListener = null
        }
    }

    private fun processShake(magnitude: Double, now: Long) {
        if (now - lastShakeTriggerTimestamp < 5000L) return

        if (magnitude > 14.0) {
            shakeTimestamps.addLast(now)
            while (!shakeTimestamps.isEmpty() && now - shakeTimestamps.first > 2000L) {
                shakeTimestamps.removeFirst()
            }
            if (shakeTimestamps.size >= 3) {
                Log.w(TAG, "🚨 NATIVE SHAKE SOS DETECTED in background!")
                shakeTimestamps.clear()
                lastShakeTriggerTimestamp = now
                val event = NativeEmergencyDispatcher.trigger(this@SafetyForegroundService, "shake_sos")
                if (event != null) {
                    onSosTrigger?.invoke("shake_sos")
                    onAnomalyDetected?.invoke("shake_sos", mapOf("magnitude" to magnitude))
                }
            }
        }
    }

    private fun processFall(magnitude: Double, now: Long) {
        // Freefall detection: near weightlessness (< 3.0 m/s^2)
        if (magnitude < 3.0) {
            lastFreeFallTimestamp = now
        }

        // High-G impact detection: spike > 28.0 m/s^2 within 1.5s of freefall
        if (magnitude > 28.0 && (now - lastFreeFallTimestamp) in 50..1500) {
            lastImpactTimestamp = now
            isMonitoringStillness = true
            stillStartTime = now
            Log.w(TAG, "⚠️ Potential Fall/Impact detected ($magnitude m/s²). Monitoring post-impact stillness...")
        }

        // Post-impact stillness verification: lying still for > 2.5 seconds
        if (isMonitoringStillness) {
            if (now - lastImpactTimestamp > 6000L) {
                isMonitoringStillness = false
            } else {
                val deviation = abs(magnitude - 9.8)
                if (deviation > 2.2) {
                    // Movement detected, reset stillness timer
                    stillStartTime = now
                } else if (now - stillStartTime >= 2500L) {
                    isMonitoringStillness = false
                    Log.w(TAG, "🚨 CONFIRMED FALL / COLLAPSE DETECTED BY NATIVE ACCELEROMETER!")
                    val event = NativeEmergencyDispatcher.trigger(this@SafetyForegroundService, "fall_detected")
                    if (event != null) {
                        onSosTrigger?.invoke("fall_detected")
                        onAnomalyDetected?.invoke(
                            "fall_detected",
                            mapOf("impact_magnitude" to magnitude, "stillness_ms" to (now - stillStartTime))
                        )
                    }
                }
            }
        }
    }

    // ───────────────────────────────────────────────────────────────
    // Screen Toggle Panic Receiver
    // ───────────────────────────────────────────────────────────────

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
        try {
            val notification = buildNotification()

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val hasLocation = ContextCompat.checkSelfPermission(
                    this, Manifest.permission.ACCESS_FINE_LOCATION
                ) == PackageManager.PERMISSION_GRANTED || ContextCompat.checkSelfPermission(
                    this, Manifest.permission.ACCESS_COARSE_LOCATION
                ) == PackageManager.PERMISSION_GRANTED

                if (hasLocation) {
                    startForeground(
                        NOTIFICATION_ID,
                        notification,
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
                    )
                } else {
                    Log.w(TAG, "Location permission not granted; stopping foreground service gracefully")
                    stopSelf()
                }
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception during startForeground: ${e.message}")
            stopSelf()
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
            .setContentText("Monitoring location & sensor anomalies in background")
            .setSmallIcon(R.drawable.ic_notification_guardian)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(tapPending)
            .addAction(
                R.drawable.ic_notification_guardian,
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
    // Location Tracking & Route Deviation
    // ───────────────────────────────────────────────────────────────

    private fun startLocationTracking() {
        locationListener = object : LocationListener {
            override fun onLocationChanged(location: Location) {
                lastKnownLocation = location
                onLocationUpdate?.invoke(location.latitude, location.longitude, location.accuracy)
                Log.d(TAG, "Location updated (accuracy: ${location.accuracy}m)")

                // Monitor route deviation
                checkRouteDeviation(location)
            }

            @Deprecated("Deprecated in API 29")
            override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
        }

        try {
            if (locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                locationManager.requestLocationUpdates(
                    LocationManager.GPS_PROVIDER,
                    10_000L,
                    10f,
                    locationListener!!,
                    Looper.getMainLooper()
                )
            }

            if (locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                locationManager.requestLocationUpdates(
                    LocationManager.NETWORK_PROVIDER,
                    5_000L,
                    5f,
                    locationListener!!,
                    Looper.getMainLooper()
                )
            }

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

    private fun checkRouteDeviation(location: Location) {
        val route = activeRoutePoints
        if (route.size < 2) return

        var minDistanceMeters = Double.MAX_VALUE
        val pLat = location.latitude
        val pLng = location.longitude

        for (i in 0 until route.size - 1) {
            val dist = distanceToSegmentMeters(
                pLat, pLng,
                route[i].first, route[i].second,
                route[i + 1].first, route[i + 1].second
            )
            if (dist < minDistanceMeters) {
                minDistanceMeters = dist
            }
        }

        if (minDistanceMeters > 150.0) {
            consecutiveDeviations++
            Log.w(TAG, "Route deviation: ${minDistanceMeters.roundToInt()}m away ($consecutiveDeviations/3)")
            if (consecutiveDeviations >= 3) {
                consecutiveDeviations = 0
                Log.w(TAG, "🚨 CRITICAL ROUTE DEVIATION CONFIRMED (>150m for 3 consecutive fixes)!")
                onRouteDeviation?.invoke(minDistanceMeters)
                onAnomalyDetected?.invoke("route_deviation", mapOf("deviation_meters" to minDistanceMeters))
            }
        } else {
            consecutiveDeviations = 0
        }
    }

    private fun distanceToSegmentMeters(
        latP: Double, lngP: Double,
        latA: Double, lngA: Double,
        latB: Double, lngB: Double
    ): Double {
        val midLat = Math.toRadians((latA + latB) / 2.0)
        val mPerLat = 111132.954 - 559.822 * cos(2 * midLat) + 1.175 * cos(4 * midLat)
        val mPerLng = 111412.84 * cos(midLat) - 93.5 * cos(3 * midLat)

        val px = (lngP - lngA) * mPerLng
        val py = (latP - latA) * mPerLat
        val bx = (lngB - lngA) * mPerLng
        val by = (latB - latA) * mPerLat

        val segLenSq = bx * bx + by * by
        if (segLenSq == 0.0) return sqrt(px * px + py * py)

        val t = max(0.0, min(1.0, (px * bx + py * by) / segLenSq))
        val projX = t * bx
        val projY = t * by
        val dx = px - projX
        val dy = py - projY
        return sqrt(dx * dx + dy * dy)
    }
}
