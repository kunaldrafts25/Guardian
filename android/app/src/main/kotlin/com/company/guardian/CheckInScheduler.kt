package com.company.guardian

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import java.util.UUID

object CheckInScheduler {
    const val ACTION_REMINDER = "com.guardian.CHECK_IN_REMINDER"
    const val ACTION_ESCALATE = "com.guardian.CHECK_IN_ESCALATE"
    const val ACTION_SAFE = "com.guardian.CHECK_IN_SAFE"
    const val ACTION_HELP = "com.guardian.CHECK_IN_HELP"
    private const val CHANNEL_ID = "guardian_checkin_native"
    private const val NOTIFICATION_ID = 4201

    fun schedule(
        context: Context,
        operationId: String,
        deadlineMs: Long,
        graceDeadlineMs: Long,
    ): Boolean {
        require(operationId.isNotBlank()) { "operationId is required" }
        require(deadlineMs < graceDeadlineMs) { "Grace deadline must follow deadline" }
        cancel(context, clearStored = false)
        val schedule = JSONObject().apply {
            put("operation_id", operationId)
            put("deadline_ms", deadlineMs)
            put("grace_deadline_ms", graceDeadlineMs)
        }
        NativeEmergencyStore.saveCheckInSchedule(context, schedule)
        val manager = context.getSystemService(AlarmManager::class.java)
        val exact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || manager.canScheduleExactAlarms()
        setAlarm(context, manager, deadlineMs, ACTION_REMINDER, 4201, exact)
        setAlarm(context, manager, graceDeadlineMs, ACTION_ESCALATE, 4202, exact)
        return exact
    }

    fun restore(context: Context) {
        val schedule = NativeEmergencyStore.checkInSchedule(context) ?: return
        val now = System.currentTimeMillis()
        val deadline = schedule.optLong("deadline_ms")
        val grace = schedule.optLong("grace_deadline_ms")
        if (grace <= now) {
            NativeEmergencyDispatcher.trigger(context, "CHECK_IN_EXPIRED")
            NativeEmergencyStore.clearCheckInSchedule(context)
            return
        }
        val manager = context.getSystemService(AlarmManager::class.java)
        val exact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || manager.canScheduleExactAlarms()
        if (deadline <= now) showReminder(context)
        else setAlarm(context, manager, deadline, ACTION_REMINDER, 4201, exact)
        setAlarm(context, manager, grace, ACTION_ESCALATE, 4202, exact)
    }

    fun cancel(context: Context, clearStored: Boolean = true) {
        val manager = context.getSystemService(AlarmManager::class.java)
        manager.cancel(pending(context, ACTION_REMINDER, 4201))
        manager.cancel(pending(context, ACTION_ESCALATE, 4202))
        context.getSystemService(NotificationManager::class.java).cancel(NOTIFICATION_ID)
        if (clearStored) NativeEmergencyStore.clearCheckInSchedule(context)
    }

    private fun setAlarm(
        context: Context,
        manager: AlarmManager,
        atMs: Long,
        action: String,
        requestCode: Int,
        exact: Boolean,
    ) {
        val intent = pending(context, action, requestCode)
        if (exact) manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMs, intent)
        else manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMs, intent)
    }

    private fun pending(context: Context, action: String, requestCode: Int): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            requestCode,
            Intent(context, CheckInAlarmReceiver::class.java).setAction(action),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    fun showReminder(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Safety check-ins", NotificationManager.IMPORTANCE_HIGH)
            )
        }
        val safe = PendingIntent.getBroadcast(
            context, 4203,
            Intent(context, CheckInAlarmReceiver::class.java).setAction(ACTION_SAFE),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val help = PendingIntent.getBroadcast(
            context, 4204,
            Intent(context, CheckInAlarmReceiver::class.java).setAction(ACTION_HELP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        manager.notify(
            NOTIFICATION_ID,
            NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_notification_guardian)
                .setContentTitle("Safety check-in due")
                .setContentText("Confirm you are safe or request help now.")
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(false)
                .addAction(0, "I'm safe", safe)
                .addAction(0, "Need help", help)
                .build(),
        )
    }

    fun recordSafeAction(context: Context) {
        val operationId = NativeEmergencyStore.checkInSchedule(context)
            ?.optString("operation_id") ?: return
        NativeEmergencyStore.appendCheckInAction(
            context,
            JSONObject().apply {
                put("action_id", UUID.randomUUID().toString())
                put("operation_id", operationId)
                put("action", "safe")
                put("occurred_at_ms", System.currentTimeMillis())
            },
        )
        cancel(context)
    }
}

class CheckInAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            CheckInScheduler.ACTION_REMINDER -> CheckInScheduler.showReminder(context)
            CheckInScheduler.ACTION_ESCALATE -> {
                NativeEmergencyDispatcher.trigger(context, "CHECK_IN_EXPIRED")
                CheckInScheduler.cancel(context)
            }
            CheckInScheduler.ACTION_SAFE -> CheckInScheduler.recordSafeAction(context)
            CheckInScheduler.ACTION_HELP -> {
                NativeEmergencyDispatcher.trigger(context, "CHECK_IN_EXPIRED")
                CheckInScheduler.cancel(context)
            }
        }
    }
}
