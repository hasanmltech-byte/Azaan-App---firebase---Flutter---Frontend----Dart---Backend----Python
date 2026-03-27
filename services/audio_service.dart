import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService {
  static final AudioPlayer _player = AudioPlayer();

  // TTS channel — works when app is open (MainActivity alive)
  // When app is closed, native TTS runs in AzanForegroundService directly
  static const _tts = MethodChannel('tts_channel');
  static const _kSehriStop = 'sehri_stop_signal';

  static Future<void> _playWithAlarmContext(String assetPath) async {
    await _player.stop();
    // ignore: prefer_const_constructors
    await _player.setAudioContext(
      AudioContext(
        // ignore: prefer_const_constructors
        android: AudioContextAndroid(
          audioFocus: AndroidAudioFocus.gainTransient,
          usageType: AndroidUsageType.alarm,
          contentType: AndroidContentType.music,
          isSpeakerphoneOn: true,
          stayAwake: true,
        ),
      ),
    );
    await _player.play(AssetSource(assetPath));
  }

  /// Plays azan.mp3 for all 5 prayers
  static Future<void> playAzan() async {
    await _playWithAlarmContext('sounds/azan.mp3');
  }

  /// Sehri loop — runs entirely in native side via tts_service channel
  /// Native side (AzanForegroundService) handles TTS + alarm loop
  /// Flutter side just sends start/stop signals
  static Future<void> playSehriLoop() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSehriStop, false);

    while (true) {
      await prefs.reload();
      if (prefs.getBool(_kSehriStop) ?? false) break;

      // Play alarm ringtone
      await _playWithAlarmContext('sounds/sehri_alarm.mp3');
      await _waitForCompletion();

      await prefs.reload();
      if (prefs.getBool(_kSehriStop) ?? false) break;
    }

    await _player.stop();
  }

  /// Called when user taps Dismiss on Sehri notification
  static Future<void> stopSehri() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSehriStop, true);
    await _player.stop();
    try {
      await _tts.invokeMethod('stop');
    } catch (_) {}
  }

  static Future<void> _waitForCompletion() async {
    final completer = Completer<void>();
    late StreamSubscription sub;
    sub = _player.onPlayerComplete.listen((_) {
      sub.cancel();
      completer.complete();
    });
    await completer.future.timeout(
      const Duration(minutes: 3),
      onTimeout: () {},
    );
  }

  static Future<void> stop() async {
    await _player.stop();
  }
}
