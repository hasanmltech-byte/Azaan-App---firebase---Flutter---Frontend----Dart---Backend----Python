package com.example.azaan_ramzan_timings

import android.app.AlarmManager
import android.app.PendingIntent
import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * JobScheduler watchdog — runs every 15 minutes.
 *
 * WHY THIS EXISTS (the "Chinese phone + no autostart + long off" problem):
 *   On aggressive Chinese ROMs (Tecno, Infinix, Xiaomi), when the phone is
 *   off for several hours and the user hasn't granted Autostart:
 *     - BootReceiver is BLOCKED by the ROM
 *     - AzanForegroundService is DEAD (never restarted)
 *     - AlarmManager alarms have EXPIRED (they were set 24h ahead)
 *   Result: no alarm fires. This watchdog is the only fix.
 *
 * WHY JOBSCHEDULER SURVIVES:
 *   Unlike plain services or BroadcastReceivers, JobScheduler jobs with
 *   setPersisted(true) are managed by the Android OS itself (not the app).
 *   Chinese ROMs cannot block them without breaking core system behavior.
 *   Even after reboot with no autostart, the OS reschedules persisted jobs.
 *
 * WHAT IT DOES EVERY 15 MINUTES:
 *   1. Checks if azan is enabled by user
 *   2. Reschedules all AlarmManager alarms from saved SharedPrefs data
 *      (this is the key — it keeps Layer B alive even after long sleep)
 *   3. Restarts AzanForegroundService if it has been killed (Layer A)
 *   4. Reschedules the AlarmManager watchdog backup
 *
 * BUG FIXES FROM CODE REVIEW:
 *   - Bug #9: Removed early-return if job exists — always re-schedule (idempotent)
 *   - Bug #8: Replaced deprecated getRunningServices() with static isRunning flag
 *   - Bug #6: Watchdog uses setExactAndAllowWhileIdle() NOT setAlarmClock()
 */
class AzanWatchdogJob : JobService() {

    companion object {
        private const val TAG    = "AzanWatchdog"
        const val JOB_ID         = 1001
        private const val PERIOD = 15 * 60 * 1000L  // 15 minutes

        fun schedule(context: Context) {
            val scheduler = context.getSystemService(Context.JOB_SCHEDULER_SERVICE)
                as JobScheduler

            // FIX Bug #9: Do NOT return early if job exists.
            // Always re-schedule — idempotent with same JOB_ID.
            // On Tecno/Huawei, allPendingJobs returns stale results anyway.
            val job = JobInfo.Builder(
                JOB_ID,
                ComponentName(context, AzanWatchdogJob::class.java)
            )
                .setPeriodic(PERIOD)
                .setPersisted(true)                          // ← survives reboot, no autostart needed
                .setRequiredNetworkType(JobInfo.NETWORK_TYPE_NONE)
                .build()

            val result = scheduler.schedule(job)
            if (result == JobScheduler.RESULT_SUCCESS) {
                Log.d(TAG, "✅ JobScheduler watchdog scheduled (every 15min, persisted)")
            } else {
                Log.e(TAG, "❌ JobScheduler scheduling failed — result=$result")
            }
        }

        fun cancel(context: Context) {
            val scheduler = context.getSystemService(Context.JOB_SCHEDULER_SERVICE)
                as JobScheduler
            scheduler.cancel(JOB_ID)
            Log.d(TAG, "JobScheduler watchdog cancelled")
        }
    }

    override fun onStartJob(params: JobParameters?): Boolean {
        Log.d(TAG, "⏰ WatchdogJob fired — checking system state")

        val prefs  = getSharedPreferences(AzanForegroundService.PREFS_NAME, MODE_PRIVATE)
        val azanOn = prefs.getBoolean("azan_on", true)

        if (!azanOn) {
            Log.d(TAG, "   Azan is OFF — watchdog skipping")
            jobFinished(params, false)
            return false
        }

        // ── Key action: Reschedule all AlarmManager alarms from storage ──────
        // This is what saves the "Chinese + no autostart + long off" scenario.
        // When the phone wakes up, alarms may have expired. We rebuild them
        // from the saved prayer times in SharedPrefs.
        Log.d(TAG, "   Rescheduling all AlarmManager alarms from storage")
        AzanAlarmReceiver.rescheduleAllFromStorage(this)

        // ── Restart foreground service if dead (Layer A) ──────────────────────
        // FIX Bug #8: Use static isRunning flag instead of deprecated getRunningServices()
        if (!AzanForegroundService.isRunning) {
            Log.d(TAG, "   AzanForegroundService is DEAD — restarting")
            val intent = Intent(this, AzanForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } else {
            Log.d(TAG, "   AzanForegroundService is alive ✓")
        }

        // ── Reschedule AlarmManager watchdog backup too ───────────────────────
        AzanAlarmWatchdog.schedule(this)

        jobFinished(params, false)
        return false
    }

    override fun onStopJob(params: JobParameters?): Boolean {
        // Return true = reschedule if the system stopped us early
        return true
    }
}