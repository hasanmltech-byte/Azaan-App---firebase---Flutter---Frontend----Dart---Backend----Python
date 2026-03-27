package com.example.azaan_ramzan_timings

import android.app.AlarmManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {

    private val BRAND_CHANNEL   = "brand_info"
    private val TTS_CHANNEL     = "tts_channel"
    private val SERVICE_CHANNEL = "azan_service_channel"
    private var tts: TextToSpeech? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        startAzanService()
        requestBatteryOptimizationExemption()
        checkExactAlarmPermission()
        initTts()

        // Brand / settings channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BRAND_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getManufacturer" -> result.success(Build.MANUFACTURER)
                    "openSettings" -> {
                        val packageName = call.argument<String>("package")
                        if (packageName != null) {
                            try {
                                val intent = packageManager.getLaunchIntentForPackage(packageName)
                                if (intent != null) {
                                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    startActivity(intent)
                                    result.success(true)
                                } else {
                                    val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                                    fallback.data = Uri.parse("package:$packageName")
                                    fallback.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    startActivity(fallback)
                                    result.success(false)
                                }
                            } catch (e: Exception) {
                                result.error("OPEN_FAILED", e.message, null)
                            }
                        } else {
                            result.error("NO_PACKAGE", "Package name is null", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // TTS channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TTS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "speak" -> {
                        val text = call.argument<String>("text") ?: ""
                        speakAndWait(text) { result.success(null) }
                    }
                    "stop" -> {
                        tts?.stop()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // Service channel — Flutter sends next prayer info → foreground service shows countdown
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SERVICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateNextPrayer" -> {
                        val name   = call.argument<String>("next_prayer_name") ?: ""
                        val timeMs = call.argument<Long>("next_prayer_time_ms") ?: -1L
                        val intent = Intent(this, AzanForegroundService::class.java).apply {
                            putExtra("next_prayer_name",    name)
                            putExtra("next_prayer_time_ms", timeMs)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(null)
                    }
                    "scheduleNativeAlarm" -> {
                        val prayerName  = call.argument<String>("prayer_name")  ?: ""
                        val alarmId     = call.argument<Int>("alarm_id")        ?: 0
                        val triggerMs   = call.argument<Long>("trigger_ms")     ?: -1L
                        val soundFile   = call.argument<String>("sound_file")   ?: "azan.mp3"
                        val loopSound   = call.argument<Boolean>("loop_sound")  ?: false
                        val notifTitle  = call.argument<String>("notif_title")
                        val notifBody   = call.argument<String>("notif_body")
                        
                        Log.d("MainActivity", "════════════════════════════════════════")
                        Log.d("MainActivity", "🔔 METHOD CHANNEL CALLED: scheduleNativeAlarm")
                        Log.d("MainActivity", "   Prayer:   $prayerName")
                        Log.d("MainActivity", "   ID:       $alarmId")
                        Log.d("MainActivity", "   TriggerMs: $triggerMs")
                        Log.d("MainActivity", "   Sound:    $soundFile")
                        Log.d("MainActivity", "════════════════════════════════════════")
                        
                        if (triggerMs > 0) {
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
                        } else {
                            Log.e("MainActivity", "❌ Invalid triggerMs: $triggerMs")
                        }
                        result.success(null)
                    }
                    "cancelNativeAlarm" -> {
                        val alarmId = call.argument<Int>("alarm_id") ?: 0
                        AzanAlarmReceiver.cancelAzan(this, alarmId)
                        result.success(null)
                    }
                    "setAzanOn" -> {
                        val azanOn = call.argument<Boolean>("azan_on") ?: true
                        getSharedPreferences(AzanForegroundService.PREFS_NAME, MODE_PRIVATE)
                            .edit()
                            .putBoolean("azan_on", azanOn)
                            .apply()
                        result.success(null)
                    }
                    "updatePrayerTimes" -> {
                        // Store prayer times in SharedPreferences
                        // AzanForegroundService reads these every second to check if it's time to ring
                        val prefs = getSharedPreferences(
                            AzanForegroundService.PREFS_NAME, MODE_PRIVATE
                        ).edit()
                        call.arguments<Map<String, Any>>()?.forEach { (key, value) ->
                            prefs.putString(key, value.toString())
                        }
                        prefs.apply()

                        // Also forward to foreground service so it picks up new times immediately
                        val intent = Intent(this, AzanForegroundService::class.java)
                        call.arguments<Map<String, Any>>()?.forEach { (key, value) ->
                            intent.putExtra(key, value.toString())
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun initTts() {
        tts = TextToSpeech(this) { status ->
            if (status == TextToSpeech.SUCCESS) {
                tts?.language = Locale.ENGLISH
                tts?.setSpeechRate(0.9f) // slightly slower — clearer pronunciation
            }
        }
    }

    private fun speakAndWait(text: String, onDone: () -> Unit) {
        val ttsEngine = tts ?: run { onDone(); return }
        val utteranceId = "sehri_announcement"

        ttsEngine.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(id: String?) {}
            override fun onDone(id: String?) { onDone() }
            override fun onError(id: String?) { onDone() }
        })

        ttsEngine.speak(text, TextToSpeech.QUEUE_FLUSH, null, utteranceId)
    }

    override fun onDestroy() {
        tts?.shutdown()
        super.onDestroy()
    }

    private fun requestBatteryOptimizationExemption() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val pm = getSystemService(android.os.PowerManager::class.java)
                if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                    intent.data = Uri.parse("package:$packageName")
                    startActivity(intent)
                }
            }
        } catch (e: Exception) { e.printStackTrace() }
    }

    private fun checkExactAlarmPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val alarmManager = getSystemService(AlarmManager::class.java)
            if (!alarmManager.canScheduleExactAlarms()) {
                val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                intent.data = Uri.parse("package:$packageName")
                startActivity(intent)
            }
        }
    }

    private fun startAzanService() {
        // Layer 1 — Foreground service with PARTIAL_WAKE_LOCK
        val serviceIntent = Intent(this, AzanForegroundService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }

        // Layer 2 — JobScheduler watchdog (every 15 min, survives Tecno battery killer)
        AzanWatchdogJob.schedule(this)

        // Layer 3 — AlarmManager watchdog (every 5 min, backup layer)
        AzanAlarmWatchdog.schedule(this)

        // Layer 4 — WorkManager (most reliable Google-recommended background task)
        AzanKeepAliveWorker.schedule(this)
    }
}