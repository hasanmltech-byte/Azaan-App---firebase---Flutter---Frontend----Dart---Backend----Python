import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/prayer_times_model.dart';

/// ALARM ARCHITECTURE:
///
/// Prayer alarms → NATIVE AzanAlarmReceiver (pure Kotlin, no Flutter engine)
///   Scheduled via MethodChannel from MainActivity (UI thread only)
///   AzanAlarmReceiver.kt fires → MediaPlayer plays azan → works when app killed
///   Self-reschedules next day via SharedPreferences
///
/// Primary Layer — AzanForegroundService checks prayer times every second
///   Reads stored prayer times from SharedPreferences
///   When hour:minute matches → plays azan directly
///   → Most reliable, always running 24/7
///
/// Backup Layer — NATIVE AlarmManager (fires even if service killed seconds before)
///
class AlarmService {
  static const _platform = MethodChannel('azan_service_channel');
  static const serviceChannelPrayerTimePrefix = 'prayer_time_';

  static const Map<String, int> _nativeIds = {
    'Fajr': 0,
    'Sunrise': 1,
    'Dhuhr': 2,
    'Asr': 3,
    'Maghrib': 4,
    'Isha': 5,
  };

  static const int _sehriId = 10;
  static const int _iftarId = 11;

  /// Schedule all prayer alarms + send times to foreground service.
  /// Call ONLY from UI thread (MainActivity alive) — MethodChannel requires it.
  static Future<void> scheduleAll(
    List<PrayerTime> prayers, {
    bool ramzanOn = false,
  }) async {
    await cancelAll();

    final Map<String, dynamic> prayerTimeArgs = {};

    for (final p in prayers) {
      if (p.time == null) continue;
      if (p.alarmOn) {
        await _scheduleNativePrayer(p.key, p.time!);
        // Store prayer time as "HH:MM" for foreground service to read every second
        prayerTimeArgs['$serviceChannelPrayerTimePrefix${p.key}'] =
            '${p.time!.hour}:${p.time!.minute.toString().padLeft(2, '0')}';
      }
    }

    // Send all prayer times to foreground service in one call
    if (prayerTimeArgs.isNotEmpty) {
      await _sendPrayerTimesToService(prayerTimeArgs);
    }

    if (ramzanOn) {
      await scheduleRamzanAlarms(prayers);
    }
  }

  /// Schedule native Kotlin alarm via MainActivity MethodChannel
  static Future<void> _scheduleNativePrayer(String key, TimeOfDay time) async {
    final id = _nativeIds[key];
    if (id == null) return;

    var dt = _todayAt(time);
    if (dt.isBefore(DateTime.now())) {
      dt = dt.add(const Duration(days: 1));
    }

    try {
      await _platform.invokeMethod('scheduleNativeAlarm', {
        'prayer_name': key,
        'alarm_id': id,
        'trigger_ms': dt.millisecondsSinceEpoch,
      });
    } catch (_) {}
  }

  /// Cancel native Kotlin alarm
  static Future<void> _cancelNativePrayer(String key) async {
    final id = _nativeIds[key];
    if (id == null) return;
    try {
      await _platform.invokeMethod('cancelNativeAlarm', {'alarm_id': id});
    } catch (_) {}
  }

  /// Send prayer times to foreground service (Layer A)
  /// AzanForegroundService reads these every second to check if it's time to ring
  static Future<void> _sendPrayerTimesToService(
      Map<String, dynamic> args) async {
    try {
      await _platform.invokeMethod('updatePrayerTimes', args);
    } catch (_) {}
  }

  /// Sehri + Iftar alarms — now fully native (no Flutter isolate)
  static Future<void> scheduleRamzanAlarms(List<PrayerTime> prayers) async {
    final fajr = prayers.firstWhere(
      (p) => p.key == 'Fajr',
      orElse: () => prayers[0],
    );
    if (fajr.time != null) {
      var dt = _todayAt(fajr.time!).subtract(const Duration(hours: 1));
      if (dt.isBefore(DateTime.now())) dt = dt.add(const Duration(days: 1));

      await _platform.invokeMethod('scheduleNativeAlarm', {
        'prayer_name': 'Sehri',
        'alarm_id': _sehriId,
        'trigger_ms': dt.millisecondsSinceEpoch,
        'sound_file': 'sehri_alarm.mp3',
        'loop_sound': true,
        'notif_title': '🌙 Sehri Time',
        'notif_body': 'Sehri time is now — please stop eating!',
      });
    }

    final maghrib = prayers.firstWhere(
      (p) => p.key == 'Maghrib',
      orElse: () => prayers[4],
    );
    if (maghrib.time != null) {
      var dt = _todayAt(maghrib.time!);
      if (dt.isBefore(DateTime.now())) dt = dt.add(const Duration(days: 1));

      await _platform.invokeMethod('scheduleNativeAlarm', {
        'prayer_name': 'Iftar',
        'alarm_id': _iftarId,
        'trigger_ms': dt.millisecondsSinceEpoch,
        'sound_file': 'azan.mp3',
        'loop_sound': false,
        'notif_title': '🌅 Iftar Time',
        'notif_body': 'It is time to break your fast!',
      });
    }
  }

  /// Cancel Ramzan alarms
  static Future<void> cancelRamzanAlarms() async {
    try {
      await _platform.invokeMethod('cancelNativeAlarm', {'alarm_id': _sehriId});
      await _platform.invokeMethod('cancelNativeAlarm', {'alarm_id': _iftarId});
    } catch (_) {}
  }

  static Future<void> cancelAll() async {
    // Cancel native prayer alarms
    for (final key in _nativeIds.keys) {
      await _cancelNativePrayer(key);
    }

    // Cancel native Ramzan alarms
    try {
      await _platform.invokeMethod('cancelNativeAlarm', {'alarm_id': _sehriId});
      await _platform.invokeMethod('cancelNativeAlarm', {'alarm_id': _iftarId});
    } catch (_) {}

    // Skip AndroidAlarmManager.cancel() for location IDs
    // — receivers no longer exist, causes interference
  }

  static Future<void> updateOne(PrayerTime prayer) async {
    if (prayer.alarmOn && prayer.time != null) {
      await _scheduleNativePrayer(prayer.key, prayer.time!);
      // Send updated time to foreground service
      await _sendPrayerTimesToService({
        '$serviceChannelPrayerTimePrefix${prayer.key}':
            '${prayer.time!.hour}:${prayer.time!.minute.toString().padLeft(2, '0')}'
      });
    } else {
      await _cancelNativePrayer(prayer.key);
      // Clear time from service so it doesn't ring
      await _sendPrayerTimesToService(
          {'$serviceChannelPrayerTimePrefix${prayer.key}': ''});
    }
  }

  static DateTime _todayAt(TimeOfDay t) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, t.hour, t.minute);
  }
}
