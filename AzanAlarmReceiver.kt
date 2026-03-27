package com.example.azaan_ramzan_timings

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class AzanAlarmReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "AzanAlarm"
        const val ACTION_AZAN    = "com.example.azaan_ramzan_timings.AZAN_ALARM"
        const val EXTRA_PRAYER   = "prayer_name"
        const val EXTRA_ALARM_ID = "alarm_id"
        const val EXTRA_SOUND    = "sound_file"
        const val EXTRA_LOOP     = "loop_sound"
        const val EXTRA_NOTIF_TITLE = "notif_title"
        const val EXTRA_NOTIF_BODY  = "notif_body"

        fun saveAlarmInfo(
            context: Context,
            prayerName: String,
            alarmId: Int,
            triggerAtMs: Long,
            soundFile: String = "azan.mp3",
            loopSound: Boolean = false,
            notifTitle: String? = null,
            notifBody: String? = null,
        ) {
            val prefs = context.getSharedPreferences("azan_alarm_times", Context.MODE_PRIVATE)
            prefs.edit().apply {
                putLong("alarm_time_$alarmId", triggerAtMs)
                putString("alarm_prayer_$alarmId", prayerName)
                putString("alarm_sound_$alarmId", soundFile)
                putBoolean("alarm_loop_$alarmId", loopSound)
                putString("alarm_notif_title_$alarmId", notifTitle ?: "🕌 $prayerName Azan Time")
                putString("alarm_notif_body_$alarmId", notifBody ?: "$prayerName prayer time is now!")
                apply()
            }
        }

        fun rescheduleAllFromStorage(context: Context) {
            val prefs = context.getSharedPreferences("azan_alarm_times", Context.MODE_PRIVATE)
            val now = System.currentTimeMillis()
            Log.d(TAG, "Rescheduling ALL alarms from persistent storage...")

            for (alarmId in listOf(0, 1, 2, 3, 4, 5, 10, 11)) {
                val savedMs    = prefs.getLong("alarm_time_$alarmId", -1L)
                val prayerName = prefs.getString("alarm_prayer_$alarmId", null)
                val soundFile  = prefs.getString("alarm_sound_$alarmId", "azan.mp3") ?: "azan.mp3"
                val loopSound  = prefs.getBoolean("alarm_loop_$alarmId", false)
                val notifTitle = prefs.getString("alarm_notif_title_$alarmId", null)
                val notifBody  = prefs.getString("alarm_notif_body_$alarmId", null)

                if (savedMs > 0 && prayerName != null) {
                    val nextMs = if (savedMs > now) savedMs else savedMs + 24 * 60 * 60 * 1000L
                    Log.d(TAG, "Rescheduling $prayerName for ${java.util.Date(nextMs)}")
                    scheduleAzan(context, prayerName, alarmId, nextMs, soundFile, loopSound, notifTitle, notifBody)
                }
            }
        }

        fun scheduleAzan(
            context: Context,
            prayerName: String,
            alarmId: Int,
            triggerAtMs: Long,
            soundFile: String = "azan.mp3",
            loopSound: Boolean = false,
            notifTitle: String? = null,
            notifBody: String? = null,
        ) {
            val now = System.currentTimeMillis()

            if (triggerAtMs <= now) {
                val nextDay = triggerAtMs + 24 * 60 * 60 * 1000L
                Log.w(TAG, "⚠️ Trigger past — rescheduling $prayerName for tomorrow")
                scheduleAzan(context, prayerName, alarmId, nextDay, soundFile, loopSound, notifTitle, notifBody)
                return
            }

            Log.d(TAG, "📅 SCHEDULING: $prayerName (ID:$alarmId) at ${java.util.Date(triggerAtMs)}")

            saveAlarmInfo(context, prayerName, alarmId, triggerAtMs, soundFile, loopSound, notifTitle, notifBody)

            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, AzanAlarmReceiver::class.java).apply {
                action = ACTION_AZAN
                putExtra(EXTRA_PRAYER,      prayerName)
                putExtra(EXTRA_ALARM_ID,    alarmId)
                putExtra(EXTRA_SOUND,       soundFile)
                putExtra(EXTRA_LOOP,        loopSound)
                putExtra(EXTRA_NOTIF_TITLE, notifTitle ?: "🕌 $prayerName Azan Time")
                putExtra(EXTRA_NOTIF_BODY,  notifBody  ?: "$prayerName prayer time is now!")
            }
            val pending = PendingIntent.getBroadcast(
                context, alarmId, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            try {
                val alarmClockInfo = AlarmManager.AlarmClockInfo(triggerAtMs, null)
                alarmManager.setAlarmClock(alarmClockInfo, pending)
                Log.d(TAG, "✅ setAlarmClock() scheduled for $prayerName")
            } catch (e: Exception) {
                Log.e(TAG, "❌ setAlarmClock failed, falling back: ${e.message}")
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMs, pending)
                    } else {
                        alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMs, pending)
                    }
                } catch (e2: Exception) {
                    Log.e(TAG, "❌ Fallback also failed: ${e2.message}")
                }
            }
        }

        fun cancelAzan(context: Context, alarmId: Int) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, AzanAlarmReceiver::class.java).apply {
                action = ACTION_AZAN
            }
            val pending = PendingIntent.getBroadcast(
                context, alarmId, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pending)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_AZAN) return

        val prayerName = intent.getStringExtra(EXTRA_PRAYER)      ?: "Prayer"
        val alarmId    = intent.getIntExtra(EXTRA_ALARM_ID, 0)
        val soundFile  = intent.getStringExtra(EXTRA_SOUND)        ?: "azan.mp3"
        val loopSound  = intent.getBooleanExtra(EXTRA_LOOP, false)
        val notifTitle = intent.getStringExtra(EXTRA_NOTIF_TITLE)  ?: "🕌 Azan Time"
        val notifBody  = intent.getStringExtra(EXTRA_NOTIF_BODY)   ?: "Prayer time is now!"

        Log.d(TAG, "🔔 ALARM FIRED: $prayerName (ID:$alarmId)")

        // Delegate to foreground service for reliable audio playback
        val serviceIntent = Intent(context, AzanForegroundService::class.java).apply {
            action = AzanForegroundService.ACTION_TRIGGER_ALARM
            putExtra(EXTRA_PRAYER,      prayerName)
            putExtra(EXTRA_ALARM_ID,    alarmId)
            putExtra(EXTRA_SOUND,       soundFile)
            putExtra(EXTRA_LOOP,        loopSound)
            putExtra(EXTRA_NOTIF_TITLE, notifTitle)
            putExtra(EXTRA_NOTIF_BODY,  notifBody)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }
}