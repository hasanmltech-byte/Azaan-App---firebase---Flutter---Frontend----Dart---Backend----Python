package com.example.azaan_ramzan_timings

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Handles dismiss button tap on azan notification.
 *
 * Stops BOTH possible audio services and clears ALL azan notifications.
 *
 * BUG FIXES FROM CODE REVIEW:
 *   Bug #11: Was only cancelling IDs 0–11 — missed the actual alarm notification IDs
 *            which are 200–211 (NOTIF_ALARM_BASE + alarmId).
 *            Now cancels the full correct range: 200–211.
 */
class AzanDismissReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val notifId = intent.getIntExtra("notif_id", 0)
        Log.d("AzanDismiss", "Dismiss tapped for notification $notifId")

        // Stop audio in AzanForegroundService (Layer A)
        val stopFg = Intent(context, AzanForegroundService::class.java).apply {
            action = AzanForegroundService.ACTION_STOP_ALARM
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(stopFg)
        } else {
            context.startService(stopFg)
        }

        // Stop audio in AzanPlaybackService (Layer B backup)
        val stopPb = Intent(context, AzanPlaybackService::class.java).apply {
            action = AzanPlaybackService.ACTION_STOP
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(stopPb)
            } else {
                context.startService(stopPb)
            }
        } catch (e: Exception) {
            Log.w("AzanDismiss", "AzanPlaybackService stop failed (may not be running): ${e.message}")
        }

        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Cancel the specific notification that was tapped
        nm.cancel(notifId)

        // FIX Bug #11: Cancel the CORRECT alarm notification range.
        // AzanForegroundService uses NOTIF_ALARM_BASE (200) + alarmId (0–11)
        // so the actual IDs are 200–211. The old code cancelled 0–11 which
        // missed all of these, leaving stale alarm notifications on screen.
        for (id in 200..211) {
            nm.cancel(id)
        }

        // Also cancel any legacy IDs just in case
        for (id in 0..11) {
            nm.cancel(id)
        }

        // Do NOT cancel ID 99 (NOTIF_COUNTDOWN — the persistent countdown)
        // That should stay visible so the user knows the service is running.

        Log.d("AzanDismiss", "All azan notifications cleared")
    }
}