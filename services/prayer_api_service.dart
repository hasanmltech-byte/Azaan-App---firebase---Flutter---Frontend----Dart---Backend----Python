import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/prayer_times_model.dart';

enum FiqaType { hanafi, jafari }

class PrayerApiService {
  // Aladhan API:
  //   Hanafi  → method=1 (Univ. of Islamic Sciences, Karachi)
  //             school=1 → Hanafi Asr (double shadow ratio = later time)
  //             Fajr at 18° standard
  //
  //   Jafari  → method=7 (Shia Ithna Ashari)
  //             Asr: single shadow ratio = EARLIER than Hanafi
  //             Fajr: ~16° = SLIGHTLY EARLIER than Hanafi
  static String _methodQuery(FiqaType fiqa) {
    return fiqa == FiqaType.jafari ? 'method=7' : 'method=1&school=1';
  }

  /// Fetch today's prayer times for given coordinates and fiqa
  static Future<Map<String, String>> fetchTimes({
    required double lat,
    required double lon,
    required FiqaType fiqa,
  }) async {
    final now = DateTime.now();
    final date = '${_pad(now.day)}-${_pad(now.month)}-${now.year}';
    final query = _methodQuery(fiqa);
    final url = Uri.parse(
      'https://api.aladhan.com/v1/timings/$date'
      '?latitude=$lat&longitude=$lon&$query',
    );

    final response = await http.get(url).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('API error ${response.statusCode}');
    }

    final body = jsonDecode(response.body);
    final timings = body['data']['timings'] as Map<String, dynamic>;

    // Return only HH:MM trimmed
    return timings.map((k, v) => MapEntry(k, (v as String).substring(0, 5)));
  }

  /// Apply fetched timings into PrayerTime list
  static void applyTimings(
    List<PrayerTime> prayers,
    Map<String, String> timings,
  ) {
    for (final p in prayers) {
      p.time = PrayerTime.parseTime(timings[p.key]);
    }
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
