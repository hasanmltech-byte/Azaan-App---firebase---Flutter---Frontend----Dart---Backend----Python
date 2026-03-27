import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class FirebaseService {
  static const _platform = MethodChannel('azan_service_channel');
  static const _kFcmToken = 'fcm_token';

  // ← YOUR SERVER URL (same WiFi as phone for testing)
  static const _serverUrl = 'http://192.168.100.121:5000';

  static Future<void> init() async {
    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final token = await messaging.getToken();
    if (token != null) {
      await _saveToken(token);
    }

    messaging.onTokenRefresh.listen((newToken) async {
      await _saveToken(newToken);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleForegroundMessage(message);
    });
  }

  /// Call this after prayer times are fetched — registers device with server
  static Future<void> registerWithServer({
    required double lat,
    required double lon,
    required String city,
    required String timezone,
    required String fiqa,
  }) async {
    final token = await getToken();
    if (token == null) return;

    try {
      final response = await http
          .post(
            Uri.parse('$_serverUrl/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'token': token,
              'lat': lat,
              'lon': lon,
              'city': city,
              'timezone': timezone,
              'fiqa': fiqa,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // ignore: avoid_print
        print('✅ Device registered with server');
      }
    } catch (e) {
      // Server offline — offline mode handles alarms via AlarmManager
      // ignore: avoid_print
      print('⚠️ Server registration failed (offline mode active): $e');
    }
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    final data = message.data;
    if (data.isEmpty) return;

    final prayerName = data['prayer_name'];
    final alarmIdStr = data['alarm_id'];
    if (prayerName == null || alarmIdStr == null) return;

    final alarmId = int.tryParse(alarmIdStr);
    if (alarmId == null) return;

    final triggerMs =
        DateTime.now().add(const Duration(seconds: 2)).millisecondsSinceEpoch;

    _platform.invokeMethod('scheduleNativeAlarm', {
      'prayer_name': prayerName,
      'alarm_id': alarmId,
      'trigger_ms': triggerMs,
      'sound_file': data['sound_file'] ?? 'azan.mp3',
      'loop_sound': data['loop_sound'] == 'true',
      'notif_title': data['notif_title'] ?? '🕌 $prayerName Azan Time',
      'notif_body': data['notif_body'] ?? '$prayerName prayer time is now!',
    }).catchError((_) {});
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kFcmToken) ??
        await FirebaseMessaging.instance.getToken();
  }

  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFcmToken, token);
  }
}
