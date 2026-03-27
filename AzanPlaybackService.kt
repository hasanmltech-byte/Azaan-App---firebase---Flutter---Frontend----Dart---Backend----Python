package com.example.azaan_ramzan_timings

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat

/**
 * ForegroundService that plays azan audio.
 *
 * Started by AzanAlarmReceiver when AlarmManager fires.
 * Runs as foreground service — no time limit, not killed by system.
 * Shows notification with Dismiss button.
 * Stops itself when audio completes or user taps Dismiss.
 *
 * Architecture mirrors the proven 'alarm' Flutter package:
 *   AlarmReceiver (BroadcastReceiver) → AlarmService (ForegroundService)
 *   AzanAlarmReceiver (BroadcastReceiver) → AzanPlaybackService (ForegroundService)
 */
class AzanPlaybackService : Service() {

    companion object {
        const val ACTION_STOP = "com.example.azaan_ramzan_timings.STOP_AZAN_PLAYBACK"
        private const val CHANNEL_ID = "azan_playback_channel"

        private val NOTIF_IDS = mapOf(
            "Fajr"    to 0,
            "Sunrise" to 1,
            "Dhuhr"   to 2,
            "Asr"     to 3,
            "Maghrib" to 4,
            "Isha"    to 5,
            "Test"    to 98,
        )

        var instance: AzanPlaybackService? = null
    }

    private var mediaPlayer: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var audioFocusRequest: AudioFocusRequest? = null
    private var notifId: Int = 0

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Handle stop command from dismiss button
        if (intent?.action == ACTION_STOP) {
            stopPlayback()
            stopSelf()
            return START_NOT_STICKY
        }

        val prayerName = intent?.getStringExtra(AzanAlarmReceiver.EXTRA_PRAYER) ?: "Prayer"
        notifId = NOTIF_IDS[prayerName] ?: 0

        // Acquire wake lock — keeps CPU alive during playback
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "AzanAlarm::PlaybackWakeLock"
        ).also { it.acquire(10 * 60 * 1000L) }

        // Build and show notification FIRST — required before startForeground
        createNotificationChannel()
        val notification = buildNotification(prayerName, notifId)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(notifId + 200, notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(notifId + 200, notification)
        }

        // Request audio focus
        requestAudioFocus()

        // Play azan
        playAzan()

        return START_NOT_STICKY // don't restart if killed — alarm will fire again tomorrow
    }

    private fun playAzan() {
        try {
            stopPlayback()
            val afd = assets.openFd("flutter_assets/assets/sounds/azan.mp3")
            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                prepare()
                start()
                setOnCompletionListener {
                    stopPlayback()
                    stopSelf()
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
            stopSelf()
        }
    }

    private fun stopPlayback() {
        try {
            mediaPlayer?.stop()
            mediaPlayer?.release()
        } catch (_: Exception) {}
        mediaPlayer = null

        abandonAudioFocus()

        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null

        // Cancel the azan notification
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.cancel(notifId + 200)
    }

    private fun requestAudioFocus() {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val attrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .build()
            audioFocusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(attrs)
                .build()
            audioManager.requestAudioFocus(audioFocusRequest!!)
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(null, AudioManager.STREAM_ALARM,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
        }
    }

    private fun abandonAudioFocus() {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioFocusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
        } else {
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(null)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "Azan Alarms",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                setSound(null, null) // audio played via MediaPlayer directly
                enableVibration(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }
    }

    private fun buildNotification(prayerName: String, notifId: Int): Notification {
        // Open app when notification tapped
        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val openPending = PendingIntent.getActivity(
            this, notifId, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Dismiss button — sends ACTION_STOP to this service
        val stopIntent = Intent(this, AzanPlaybackService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPending = PendingIntent.getService(
            this, notifId + 300, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("🕌 $prayerName Azan Time")
            .setContentText("$prayerName prayer time is now!")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setLargeIcon(android.graphics.BitmapFactory.decodeResource(
                resources, R.mipmap.ic_launcher))
            .setContentIntent(openPending)
            .setFullScreenIntent(openPending, true)
            .setOngoing(true)
            .setAutoCancel(false)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .addAction(0, "🔇 Dismiss", stopPending)
            .setDeleteIntent(stopPending) // swipe also stops
            .build()
    }

    override fun onDestroy() {
        stopPlayback()
        instance = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
