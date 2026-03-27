package com.example.azaan_ramzan_timings

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import java.io.IOException

/**
 * Primary alarm layer — runs 24/7 as a foreground service.
 *
 * WHAT IT DOES:
 *   • Shows a persistent countdown notification (foreground service)
 *   • Ticks every second via Handler
 *   • At prayer time: fires AlarmActivity, plays azan, shows alarm notification
 *   • Responds to ACTION_TRIGGER_ALARM (from AlarmManager / FCM layer)
 *   • Responds to ACTION_STOP_ALARM (from Dismiss button)
 *
 * BUG FIXES FROM CODE REVIEW:
 *   Bug #2:  Wake lock now has 24h timeout → no battery drain if process killed
 *   Bug #4:  setSmallIcon → R.drawable.ic_notification (not R.mipmap.ic_launcher)
 *   Bug #7:  playAzan() guards with mediaPlayer != null to prevent double-trigger
 *   Bug #8:  Static isRunning flag replaces deprecated getRunningServices()
 */
class AzanForegroundService : Service() {

    companion object {
        private const val TAG           = "AzanFgService"
        const val PREFS_NAME            = "azan_prefs"
        const val ACTION_TRIGGER_ALARM  = "com.example.azaan_ramzan_timings.TRIGGER_ALARM"
        const val ACTION_STOP_ALARM     = "com.example.azaan_ramzan_timings.STOP_ALARM"

        private const val CHANNEL_COUNTDOWN = "azan_countdown"
        private const val CHANNEL_ALARM     = "azan_alarm"
        private const val NOTIF_COUNTDOWN   = 99
        private const val NOTIF_ALARM_BASE  = 200   // alarm notifs: 200..211

        // FIX Bug #8: Static isRunning flag replaces deprecated getRunningServices().
        // All watchdogs now check AzanForegroundService.isRunning instead.
        @Volatile
        var isRunning = false
            private set
    }

    private val handler    = Handler(Looper.getMainLooper())
    private var wakeLock: PowerManager.WakeLock? = null
    private var mediaPlayer: MediaPlayer? = null

    // Tracks which prayers have already rung today (cleared at midnight)
    private val rangToday  = mutableSetOf<String>()
    private var lastDay    = -1

    // ─────────────────────────────────────────────────────────────────────────
    // Lifecycle
    // ─────────────────────────────────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        isRunning = true     // FIX Bug #8

        Log.d(TAG, "✅ AzanForegroundService created")

        createNotificationChannels()

        // FIX Bug #2: Wake lock with 24h timeout.
        // Original code used .acquire() with no timeout — on process kill the
        // wake lock would never be released, draining battery indefinitely.
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "AzanAlarm::ServiceWakeLock"
        ).also {
            it.acquire(24 * 60 * 60 * 1000L)    // 24h safety timeout
        }

        startForeground(NOTIF_COUNTDOWN, buildCountdownNotification("Starting…"))
        startTicker()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action

        when (action) {
            ACTION_TRIGGER_ALARM -> {
                val prayerName = intent.getStringExtra(AzanAlarmReceiver.EXTRA_PRAYER) ?: "Prayer"
                val alarmId    = intent.getIntExtra(AzanAlarmReceiver.EXTRA_ALARM_ID, 0)
                val soundFile  = intent.getStringExtra(AzanAlarmReceiver.EXTRA_SOUND) ?: "azan.mp3"
                val loopSound  = intent.getBooleanExtra(AzanAlarmReceiver.EXTRA_LOOP, false)
                val notifTitle = intent.getStringExtra(AzanAlarmReceiver.EXTRA_NOTIF_TITLE) ?: "🕌 $prayerName Azan"
                val notifBody  = intent.getStringExtra(AzanAlarmReceiver.EXTRA_NOTIF_BODY) ?: "$prayerName prayer time!"

                Log.d(TAG, "⚡ ACTION_TRIGGER_ALARM received for $prayerName")
                rangToday.add(prayerName)  // prevent Layer A double-fire
                triggerAlarm(prayerName, alarmId, soundFile, loopSound, notifTitle, notifBody)
            }

            ACTION_STOP_ALARM -> {
                Log.d(TAG, "🔇 ACTION_STOP_ALARM received")
                stopAzan()
            }

            else -> {
                // Normal start — service already ticking
                Log.d(TAG, "onStartCommand: normal start (no action)")
            }
        }

        return START_STICKY   // OS restarts us if killed
    }

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false    // FIX Bug #8

        handler.removeCallbacksAndMessages(null)
        stopAzan()

        wakeLock?.let {
            if (it.isHeld) it.release()
        }
        wakeLock = null

        Log.d(TAG, "AzanForegroundService destroyed")
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ─────────────────────────────────────────────────────────────────────────
    // Ticker — checks every second for prayer time
    // ─────────────────────────────────────────────────────────────────────────

    private val tickRunnable = object : Runnable {
        override fun run() {
            checkAndPlayAzan()
            handler.postDelayed(this, 1_000L)
        }
    }

    private fun startTicker() {
        handler.post(tickRunnable)
    }

    private fun checkAndPlayAzan() {
        val prefs  = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val azanOn = prefs.getBoolean("azan_on", true)
        if (!azanOn) {
            updateCountdownNotification("Azan is OFF")
            return
        }

        val now = java.util.Calendar.getInstance()
        val h   = now.get(java.util.Calendar.HOUR_OF_DAY)
        val m   = now.get(java.util.Calendar.MINUTE)
        val d   = now.get(java.util.Calendar.DAY_OF_YEAR)

        // Clear "rang today" set at midnight
        if (d != lastDay) {
            rangToday.clear()
            lastDay = d
        }

        // Read saved prayer times from SharedPrefs (stored by AlarmService.dart)
        val alarmPrefs = getSharedPreferences("azan_alarm_times", Context.MODE_PRIVATE)

        for (alarmId in listOf(0, 1, 2, 3, 4, 5)) {
            val prayerName = alarmPrefs.getString("alarm_prayer_$alarmId", null) ?: continue
            if (prayerName in rangToday) continue

            val savedMs = alarmPrefs.getLong("alarm_time_$alarmId", -1L)
            if (savedMs <= 0L) continue

            val cal = java.util.Calendar.getInstance().apply { timeInMillis = savedMs }
            val pH  = cal.get(java.util.Calendar.HOUR_OF_DAY)
            val pM  = cal.get(java.util.Calendar.MINUTE)

            if (h == pH && m == pM) {
                val toggle = prefs.getBoolean("prayer_toggle_$prayerName", true)
                if (!toggle) continue

                Log.d(TAG, "⏰ Layer A ticker: $prayerName prayer time! ($h:$m)")
                rangToday.add(prayerName)

                val soundFile  = alarmPrefs.getString("alarm_sound_$alarmId", "azan.mp3") ?: "azan.mp3"
                val loopSound  = alarmPrefs.getBoolean("alarm_loop_$alarmId", false)
                val notifTitle = alarmPrefs.getString("alarm_notif_title_$alarmId", "🕌 $prayerName Azan Time") ?: "🕌 $prayerName Azan Time"
                val notifBody  = alarmPrefs.getString("alarm_notif_body_$alarmId", "$prayerName prayer time is now!") ?: "$prayerName prayer time is now!"

                triggerAlarm(prayerName, alarmId, soundFile, loopSound, notifTitle, notifBody)

                // Reschedule for tomorrow
                AzanAlarmReceiver.scheduleAzan(
                    context    = this,
                    prayerName = prayerName,
                    alarmId    = alarmId,
                    triggerAtMs = savedMs + 24 * 60 * 60 * 1000L,
                    soundFile  = soundFile,
                    loopSound  = loopSound,
                    notifTitle = notifTitle,
                    notifBody  = notifBody,
                )
            }
        }

        // Update countdown notification
        val nextPrayer = getNextPrayerCountdown(alarmPrefs, h, m)
        updateCountdownNotification(nextPrayer)
    }

    private fun getNextPrayerCountdown(
        alarmPrefs: android.content.SharedPreferences,
        nowH: Int,
        nowM: Int
    ): String {
        val nowMins  = nowH * 60 + nowM
        var minDiff  = Int.MAX_VALUE
        var nextName = ""

        for (alarmId in listOf(0, 1, 2, 3, 4, 5)) {
            val prayerName = alarmPrefs.getString("alarm_prayer_$alarmId", null) ?: continue
            val savedMs    = alarmPrefs.getLong("alarm_time_$alarmId", -1L)
            if (savedMs <= 0L) continue

            val cal  = java.util.Calendar.getInstance().apply { timeInMillis = savedMs }
            val pMin = cal.get(java.util.Calendar.HOUR_OF_DAY) * 60 + cal.get(java.util.Calendar.MINUTE)
            var diff = pMin - nowMins
            if (diff <= 0) diff += 24 * 60

            if (diff < minDiff) {
                minDiff  = diff
                nextName = prayerName
            }
        }

        if (nextName.isEmpty() || minDiff == Int.MAX_VALUE) return "Waiting for prayer times…"
        val hh = minDiff / 60
        val mm = minDiff % 60
        return "Next: $nextName in ${hh}h ${mm}m"
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Alarm trigger — fires AlarmActivity + plays sound
    // ─────────────────────────────────────────────────────────────────────────

    private fun triggerAlarm(
        prayerName: String,
        alarmId:    Int,
        soundFile:  String,
        loopSound:  Boolean,
        notifTitle: String,
        notifBody:  String,
    ) {
        Log.d(TAG, "🔔 Triggering alarm for $prayerName")

        // Start AlarmActivity (full-screen lock screen activity)
        val actIntent = Intent(this, AlarmActivity::class.java).apply {
            flags       = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("prayer_name", prayerName)
        }
        startActivity(actIntent)

        // Show alarm notification
        showAzanNotification(alarmId, notifTitle, notifBody, prayerName)

        // Play audio
        playAzan(soundFile, loopSound)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Audio
    // ─────────────────────────────────────────────────────────────────────────

    private fun playAzan(soundFile: String, loopSound: Boolean) {
        // FIX Bug #7: Guard against double-trigger race.
        // Layer A and Layer B can both fire at second 0 of prayer minute.
        // This guard ensures the second call is silently ignored.
        if (mediaPlayer != null) {
            Log.d(TAG, "   playAzan() called but already playing — ignoring (race guard)")
            return
        }

        Log.d(TAG, "🔊 Playing: $soundFile (loop=$loopSound)")

        try {
            val afd = assets.openFd("sounds/$soundFile")
            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                isLooping = loopSound
                prepare()
                start()
                setOnCompletionListener {
                    if (!isLooping) stopAzan()
                }
                setOnErrorListener { _, what, extra ->
                    Log.e(TAG, "MediaPlayer error: what=$what extra=$extra")
                    stopAzan()
                    true
                }
            }
            afd.close()
            Log.d(TAG, "   MediaPlayer started")
        } catch (e: IOException) {
            Log.e(TAG, "   Failed to open sound asset '$soundFile': ${e.message}")
            // Fallback: try default ringtone
            try {
                val uri = android.media.RingtoneManager.getDefaultUri(
                    android.media.RingtoneManager.TYPE_ALARM
                )
                mediaPlayer = MediaPlayer().apply {
                    setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .build()
                    )
                    setDataSource(this@AzanForegroundService, uri)
                    isLooping = loopSound
                    prepare()
                    start()
                }
            } catch (e2: Exception) {
                Log.e(TAG, "   Fallback ringtone also failed: ${e2.message}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "   Unexpected error playing azan: ${e.message}")
        }
    }

    private fun stopAzan() {
        try {
            mediaPlayer?.let {
                if (it.isPlaying) it.stop()
                it.release()
            }
        } catch (e: Exception) {
            Log.w(TAG, "stopAzan error: ${e.message}")
        } finally {
            mediaPlayer = null
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Notifications
    // ─────────────────────────────────────────────────────────────────────────

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Countdown channel — silent, persistent, low priority
        nm.createNotificationChannel(
            NotificationChannel(
                CHANNEL_COUNTDOWN,
                "Azan Countdown",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                setSound(null, null)
                enableVibration(false)
                description = "Shows next prayer countdown"
            }
        )

        // Alarm channel — high importance for heads-up notification
        nm.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ALARM,
                "Azan Alarm",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Prayer time alarm notification"
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
        )
    }

    private fun buildCountdownNotification(text: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_COUNTDOWN)
            // FIX Bug #4: Use R.drawable.ic_notification (transparent/monochrome)
            // NOT R.mipmap.ic_launcher — that shows a grey box on Android 5+
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("🕌 Azan Alarm Active")
            .setContentText(text)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setSilent(true)
            .build()
    }

    private fun updateCountdownNotification(text: String) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIF_COUNTDOWN, buildCountdownNotification(text))
    }

    private fun showAzanNotification(
        alarmId:    Int,
        title:      String,
        body:       String,
        prayerName: String,
    ) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Dismiss PendingIntent
        val dismissIntent = Intent(this, AzanDismissReceiver::class.java).apply {
            putExtra("notif_id",   NOTIF_ALARM_BASE + alarmId)
            putExtra("stop_alarm", true)
        }
        val dismissPi = PendingIntent.getBroadcast(
            this,
            alarmId + 100,
            dismissIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notif = NotificationCompat.Builder(this, CHANNEL_ALARM)
            // FIX Bug #4: Use R.drawable.ic_notification
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .addAction(
                R.drawable.ic_notification,
                "🔇 Dismiss",
                dismissPi
            )
            .build()

        nm.notify(NOTIF_ALARM_BASE + alarmId, notif)
    }
}