package com.example.azaan_ramzan_timings

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Fires on device boot — restores ALL alarm layers.
 *
 * BOOT ACTIONS COVERED:
 *   Standard boot actions + Chinese ROM-specific variants (Xiaomi MIUI,
 *   Samsung, HTC QuickBoot, package replace after update).
 *
 * WHAT HAPPENS ON BOOT:
 *   Layer A — Starts AzanForegroundService (ticker, fires alarms every second)
 *   Layer B — Reschedules all AlarmManager alarms from saved SharedPrefs data
 *   Layer C — Starts JobScheduler watchdog (persisted, survives future reboots)
 *   Layer D — Starts AlarmManager watchdog (5-min ticks, self-perpetuating)
 *   Layer E — Starts WorkManager watchdog (Google-recommended reliable scheduler)
 *   Layer F — Firebase FCM (handled by Google Play Services automatically)
 *
 * NOTE: On Chinese phones with no Autostart granted, this receiver may be
 * blocked. Layers C and E (JobScheduler + WorkManager) are scheduled with
 * setPersisted(true) so they survive even WITHOUT BootReceiver firing.
 * That is why the watchdogs exist — they are the last line of defence.
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "BootReceiver"

        private val BOOT_ACTIONS = setOf(
            "android.intent.action.BOOT_COMPLETED",
            "android.intent.action.LOCKED_BOOT_COMPLETED",
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON",
            "com.samsung.intent.action.BOOT_COMPLETED",
            "com.miui.home.launcher.action.BOOT_COMPLETED",
            "android.intent.action.MY_PACKAGE_REPLACED",
        )
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action !in BOOT_ACTIONS) return

        Log.d(TAG, "════════════════════════════════════")
        Log.d(TAG, "🔄 Boot event received: $action")
        Log.d(TAG, "════════════════════════════════════")

        val prefs  = context.getSharedPreferences(AzanForegroundService.PREFS_NAME, Context.MODE_PRIVATE)
        val azanOn = prefs.getBoolean("azan_on", true)

        if (!azanOn) {
            Log.d(TAG, "   Azan is OFF — nothing to restore")
            return
        }

        // ── Layer A: Start foreground service ─────────────────────────────
        val serviceIntent = Intent(context, AzanForegroundService::class.java)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            Log.d(TAG, "   ✅ Layer A: AzanForegroundService started")
        } catch (e: Exception) {
            Log.e(TAG, "   ❌ Layer A failed: ${e.message}")
        }

        // ── Layer B: Reschedule AlarmManager alarms from storage ──────────
        try {
            AzanAlarmReceiver.rescheduleAllFromStorage(context)
            Log.d(TAG, "   ✅ Layer B: AlarmManager alarms rescheduled")
        } catch (e: Exception) {
            Log.e(TAG, "   ❌ Layer B failed: ${e.message}")
        }

        // ── Layer C: JobScheduler watchdog ────────────────────────────────
        // Runs every 15 min, setPersisted(true) — survives reboots independently.
        // Even if this BootReceiver is blocked, the OS keeps the JobScheduler job.
        try {
            AzanWatchdogJob.schedule(context)
            Log.d(TAG, "   ✅ Layer C: JobScheduler watchdog scheduled")
        } catch (e: Exception) {
            Log.e(TAG, "   ❌ Layer C failed: ${e.message}")
        }

        // ── Layer D: AlarmManager watchdog ────────────────────────────────
        // 5-min ticks, uses setExactAndAllowWhileIdle() — fires in Doze mode.
        try {
            AzanAlarmWatchdog.schedule(context)
            Log.d(TAG, "   ✅ Layer D: AlarmManager watchdog scheduled")
        } catch (e: Exception) {
            Log.e(TAG, "   ❌ Layer D failed: ${e.message}")
        }

        // ── Layer E: WorkManager ──────────────────────────────────────────
        try {
            AzanKeepAliveWorker.schedule(context)
            Log.d(TAG, "   ✅ Layer E: WorkManager watchdog scheduled")
        } catch (e: Exception) {
            Log.e(TAG, "   ❌ Layer E failed: ${e.message}")
        }

        Log.d(TAG, "✅ All alarm layers restored on boot")
    }
}