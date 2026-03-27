package com.example.azaan_ramzan_timings

import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

/**
 * WorkManager watchdog — runs every 15 minutes.
 *
 * WHY THIS EXISTS IN ADDITION TO AzanWatchdogJob:
 *   WorkManager and JobScheduler use different scheduling paths internally.
 *   On some devices (particularly Samsung with DeX and certain Xiaomi builds),
 *   one may survive where the other doesn't. Having both maximises coverage.
 *
 *   WorkManager is Google's recommended approach for guaranteed background work.
 *   It handles Doze mode, battery optimisation, and app restarts automatically.
 *
 * BUG FIXES FROM CODE REVIEW:
 *   - Bug #10: Changed KEEP → UPDATE policy so updates take effect after app updates
 *   - Bug #8:  Replaced deprecated getRunningServices() with static isRunning flag
 */
class AzanKeepAliveWorker(
    private val context: Context,
    params: WorkerParameters,
) : CoroutineWorker(context, params) {

    companion object {
        private const val TAG       = "KeepAliveWorker"
        const val WORK_NAME         = "azan_keep_alive"
        private const val PERIOD_MIN = 15L

        fun schedule(context: Context) {
            val request = PeriodicWorkRequestBuilder<AzanKeepAliveWorker>(
                PERIOD_MIN, TimeUnit.MINUTES
            ).build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                // FIX Bug #10: Use UPDATE instead of KEEP.
                // KEEP would silently run old code after an app update.
                // UPDATE replaces the scheduled work with the new version.
                ExistingPeriodicWorkPolicy.UPDATE,
                request
            )
            Log.d(TAG, "✅ WorkManager watchdog scheduled (every ${PERIOD_MIN}min)")
        }

        fun cancel(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
            Log.d(TAG, "WorkManager watchdog cancelled")
        }
    }

    override suspend fun doWork(): Result {
        Log.d(TAG, "⏰ KeepAliveWorker fired — checking system state")

        val prefs  = context.getSharedPreferences(
            AzanForegroundService.PREFS_NAME, Context.MODE_PRIVATE
        )
        val azanOn = prefs.getBoolean("azan_on", true)

        if (!azanOn) {
            Log.d(TAG, "   Azan is OFF — worker skipping")
            return Result.success()
        }

        // Reschedule all AlarmManager alarms from saved data
        // (keeps Layer B alive after long sleep or reboot without autostart)
        Log.d(TAG, "   Rescheduling all AlarmManager alarms from storage")
        AzanAlarmReceiver.rescheduleAllFromStorage(context)

        // FIX Bug #8: Use static isRunning flag instead of deprecated getRunningServices()
        if (!AzanForegroundService.isRunning) {
            Log.d(TAG, "   AzanForegroundService is DEAD — restarting")
            val intent = Intent(context, AzanForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        } else {
            Log.d(TAG, "   AzanForegroundService is alive ✓")
        }

        return Result.success()
    }
}