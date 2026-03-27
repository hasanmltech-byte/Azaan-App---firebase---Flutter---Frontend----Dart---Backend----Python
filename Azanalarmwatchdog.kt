package com.example.azaan_ramzan_timings

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * AlarmManager watchdog — fires every 5 minutes as a tertiary backup.
 *
 * WHY THIS EXISTS:
 *   On some extreme cases (particularly Tecno HiOS and Infinix XOS), even
 *   JobScheduler jobs can be killed during deep power-saving modes.
 *   AlarmManager with setExactAndAllowWhileIdle() bypasses most restrictions
 *   and will fire even during Doze mode.
 *
 *   It reschedules itself on every tick — so it's self-perpetuating.
 *   Each tick also calls rescheduleAllFromStorage() to keep prayer alarms live.
 *
 * BUG FIX FROM CODE REVIEW:
 *   - Bug #6: Changed setAlarmClock() → setExactAndAllowWhileIdle()
 *     setAlarmClock() was wrong here because:
 *       (a) It shows a clock icon in the status bar for every 5-min tick ❌
 *       (b) On Android 12+, requires SCHEDULE_EXACT_ALARM which users can revoke ❌
 *       (c) It is reserved for user-visible prayer alarms only ✓
 *     setExactAndAllowWhileIdle() fires during Doze without status bar icon.
 */
class AzanAlarmWatchdog : BroadcastReceiver() {

    companion object {
        private const val TAG         = "AlarmWatchdog"
        const val ACTION_WATCHDOG     = "com.example.azaan_ramzan_timings.WATCHDOG_TICK"
        private const val REQUEST_CODE = 9001
        private const val INTERVAL_MS  = 5 * 60 * 1000L  // 5 minutes

        fun schedule(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val triggerAt    = System.currentTimeMillis() + INTERVAL_MS

            val intent = Intent(context, AzanAlarmWatchdog::class.java).apply {
                action = ACTION_WATCHDOG
            }
            val pending = PendingIntent.getBroadcast(
                context,
                REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // FIX Bug #6: Use setExactAndAllowWhileIdle() NOT setAlarmClock()
            // This fires during Doze mode without showing a clock icon in status bar.
            // Reserve setAlarmClock() only for actual user-facing prayer alarms.
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        triggerAt,
                        pending
                    )
                } else {
                    alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pending)
                }
                Log.d(TAG, "✅ AlarmManager watchdog scheduled in 5min")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Watchdog schedule failed: ${e.message}")
            }
        }

        fun cancel(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, AzanAlarmWatchdog::class.java).apply {
                action = ACTION_WATCHDOG
            }
            val pending = PendingIntent.getBroadcast(
                context,
                REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pending)
            Log.d(TAG, "AlarmManager watchdog cancelled")
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_WATCHDOG) return

        Log.d(TAG, "⏰ AlarmWatchdog tick")

        val prefs  = context.getSharedPreferences(AzanForegroundService.PREFS_NAME, Context.MODE_PRIVATE)
        val azanOn = prefs.getBoolean("azan_on", true)

        if (!azanOn) {
            Log.d(TAG, "   Azan is OFF — watchdog skipping (not rescheduling)")
            return
        }

        // Reschedule all prayer AlarmManager alarms from saved storage
        AzanAlarmReceiver.rescheduleAllFromStorage(context)

        // FIX Bug #8: Use static isRunning flag
        if (!AzanForegroundService.isRunning) {
            Log.d(TAG, "   Service DEAD — restarting")
            val serviceIntent = Intent(context, AzanForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        }

        // Reschedule self for next tick (self-perpetuating)
        schedule(context)
    }
}