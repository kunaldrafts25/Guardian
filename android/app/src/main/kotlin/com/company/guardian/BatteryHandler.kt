package com.company.guardian

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall

/**
 * Handler for battery-related functionality
 */
class BatteryHandler(private val context: Context) {

    /**
     * Get the current battery level
     * @return Battery level as an integer percentage (0-100)
     */
    fun getBatteryLevel(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
            batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        } else {
            val intent = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            val level = intent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
            val scale = intent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
            if (level == -1 || scale == -1) {
                50 // Default value if we can't get the battery level
            } else {
                (level * 100 / scale.toFloat()).toInt()
            }
        }
    }

    /**
     * Handle method channel calls
     */
    fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getBatteryLevel" -> {
                val batteryLevel = getBatteryLevel()
                result.success(batteryLevel)
            }
            else -> {
                result.notImplemented()
            }
        }
    }
}
