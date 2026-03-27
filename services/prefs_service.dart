import 'package:shared_preferences/shared_preferences.dart';
import 'prayer_api_service.dart';

class PrefsService {
  static late SharedPreferences _p;

  static Future<void> init() async {
    _p = await SharedPreferences.getInstance();
  }

  // Azan master switch
  static bool get azanOn => _p.getBool('azanOn') ?? true;
  static Future<void> setAzanOn(bool v) => _p.setBool('azanOn', v);

  // Ramzan mode
  static bool get ramzanOn => _p.getBool('ramzanOn') ?? false;
  static Future<void> setRamzanOn(bool v) => _p.setBool('ramzanOn', v);

  // Fiqa selection
  static FiqaType get fiqa {
    final s = _p.getString('fiqa') ?? 'hanafi';
    return s == 'jafari' ? FiqaType.jafari : FiqaType.hanafi;
  }

  static Future<void> setFiqa(FiqaType f) =>
      _p.setString('fiqa', f == FiqaType.jafari ? 'jafari' : 'hanafi');

  // Individual prayer toggles
  static bool getPrayerToggle(String key) => _p.getBool('tog_$key') ?? true;
  static Future<void> setPrayerToggle(String key, bool v) =>
      _p.setBool('tog_$key', v);
}
