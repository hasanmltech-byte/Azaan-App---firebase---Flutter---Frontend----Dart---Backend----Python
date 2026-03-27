package com.example.azaan_ramzan_timings

import android.util.Log
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

/**
 * Receives Firebase push notifications and immediately triggers the alarm.
 *
 * Expected FCM data payload:
 * {
 *   "prayer_name": "Fajr",          // required
 *   "alarm_id":    "0",             // required — int as string
 *   "sound_file":  "azan.mp3",      // optional, default azan.mp3
 *   "loop_sound":  "false",         // optional, default false
 *   "notif_title": "🕌 Fajr Azan",  // optional
 *   "notif_body":  "Prayer time!"   // optional
 * }
 *
 * The service schedules the alarm for NOW (current time + 2 seconds buffer)
 * so AzanAlarmReceiver fires immediately and plays the azan.
 *
 * This is the FIREBASE LAYER — backup/trigger from server side.
 * Primary layer is still AzanForegroundService ticking every second.
 */
class MyFirebaseMessagingService : FirebaseMessagingService() {

    companion object {
        private const val TAG = "FCMService"
    }

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)

        Log.d(TAG, "═══════════════════════════════════════")
        Log.d(TAG, "🔔 FCM MESSAGE RECEIVED")
        Log.d(TAG, "   From: ${message.from}")
        Log.d(TAG, "   Data: ${message.data}")
        Log.d(TAG, "═══════════════════════════════════════")

        val data = message.data
        if (data.isEmpty()) {
            Log.w(TAG, "⚠️ Empty data payload — ignoring")
            return
        }

        val prayerName = data["prayer_name"] ?: run {
            Log.w(TAG, "⚠️ No prayer_name in payload — ignoring")
            return
        }

        val alarmId = data["alarm_id"]?.toIntOrNull() ?: run {
            Log.w(TAG, "⚠️ No valid alarm_id in payload — ignoring")
            return
        }

        val soundFile  = data["sound_file"]  ?: "azan.mp3"
        val loopSound  = data["loop_sound"]  == "true"
        val notifTitle = data["notif_title"] ?: "🕌 $prayerName Azan Time"
        val notifBody  = data["notif_body"]  ?: "$prayerName prayer time is now!"

        // Check if azan is enabled by user
        val prefs = getSharedPreferences(AzanForegroundService.PREFS_NAME, MODE_PRIVATE)
        if (!prefs.getBoolean("azan_on", true)) {
            Log.d(TAG, "   Azan is OFF — skipping FCM alarm trigger")
            return
        }

        // Check individual prayer toggle
        val toggleOn = prefs.getBoolean("prayer_toggle_$prayerName", true)
        if (!toggleOn) {
            Log.d(TAG, "   $prayerName toggle is OFF — skipping")
            return
        }

        // Schedule alarm for NOW + 2s buffer so AlarmManager fires immediately
        val triggerMs = System.currentTimeMillis() + 2_000L

        Log.d(TAG, "   Scheduling IMMEDIATE alarm for $prayerName (ID:$alarmId)")
        Log.d(TAG, "   Sound: $soundFile, Loop: $loopSound")

        AzanAlarmReceiver.scheduleAzan(
            context     = this,
            prayerName  = prayerName,
            alarmId     = alarmId,
            triggerAtMs = triggerMs,
            soundFile   = soundFile,
            loopSound   = loopSound,
            notifTitle  = notifTitle,
            notifBody   = notifBody,
        )

        Log.d(TAG, "✅ FCM alarm scheduled — will fire in ~2 seconds")
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        Log.d(TAG, "🔑 New FCM Token: $token")
        // Token is read by Flutter via FirebaseMessaging.instance.getToken()
        // Store locally so Flutter can send it to your server on next open
        val prefs = getSharedPreferences("fcm_prefs", MODE_PRIVATE)
        prefs.edit().putString("fcm_token", token).apply()
    }
}