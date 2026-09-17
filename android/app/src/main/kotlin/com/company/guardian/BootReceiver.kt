package com.company.guardian

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Guardian — BootReceiver
 *
 * Restarts SafetyForegroundService when the device reboots.
 * Without this, Guardian stops protecting the user after every reboot
 * until they manually open the app again.
 *
 * Registered in AndroidManifest with RECEIVE_BOOT_COMPLETED permission.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                Log.i("Guardian.BootReceiver", "Device booted — restarting SafetyForegroundService")
                SafetyForegroundService.start(context)
            }
        }
    }
}
