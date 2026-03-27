import 'package:flutter/material.dart'; // required for TimeOfDay

class PrayerTime {
  final String key;
  final String name;
  final String arabic;
  final String emoji;
  TimeOfDay? time;
  bool alarmOn;

  PrayerTime({
    required this.key,
    required this.name,
    required this.arabic,
    required this.emoji,
    this.time,
    this.alarmOn = true,
  });

  // Parse "HH:MM" string from Aladhan API
  static TimeOfDay? parseTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.substring(0, 5).split(':');
    if (parts.length < 2) return null;
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 0,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  // Format to display string e.g. "05:14 AM"
  String get displayTime {
    if (time == null) return '--:--';
    final h = time!.hour;
    final m = time!.minute;
    final ampm = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '${h12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $ampm';
  }

  // Minutes since midnight — used for next-prayer and passed-prayer logic
  int get totalMinutes => time == null ? 0 : time!.hour * 60 + time!.minute;
}

// All 6 prayer slots in display order
List<PrayerTime> defaultPrayers() => [
      PrayerTime(key: 'Fajr', name: 'Fajr', arabic: 'الفجر', emoji: '🌙'),
      PrayerTime(
          key: 'Sunrise', name: 'Sunrise', arabic: 'الشروق', emoji: '🌅'),
      PrayerTime(key: 'Dhuhr', name: 'Dhuhr', arabic: 'الظهر', emoji: '☀️'),
      PrayerTime(key: 'Asr', name: 'Asr', arabic: 'العصر', emoji: '🌤'),
      PrayerTime(
          key: 'Maghrib', name: 'Maghrib', arabic: 'المغرب', emoji: '🌆'),
      PrayerTime(key: 'Isha', name: 'Isha', arabic: 'العشاء', emoji: '🌃'),
    ];
