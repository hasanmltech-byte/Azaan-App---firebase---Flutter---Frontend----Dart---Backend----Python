import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationResult {
  final double lat;
  final double lon;
  final String city;
  final String country;

  const LocationResult({
    required this.lat,
    required this.lon,
    required this.city,
    required this.country,
  });
}

class LocationService {
  // Prefs keys for cached location
  static const _kLat = 'loc_lat';
  static const _kLon = 'loc_lon';
  static const _kCity = 'loc_city';
  static const _kCountry = 'loc_country';
  static const _kTime = 'loc_updated_at'; // timestamp of last GPS update

  /// Called when app is OPEN — always fetches fresh GPS, never uses cache
  static Future<LocationResult> getLocation() async {
    return await _fetchFresh();
  }

  /// Called from alarm callbacks when app is CLOSED
  /// Only uses lastKnownPosition — getCurrentPosition crashes in background isolate
  static Future<LocationResult> getLocationForAlarm() async {
    try {
      // In background isolate, only lastKnownPosition works safely
      // getCurrentPosition requires Activity context which doesn't exist in background
      final pos = await Geolocator.getLastKnownPosition();
      if (pos != null) {
        // Use cached city/country names since geocoding also needs context
        final cached = await _loadCached();
        if (cached != null) {
          // Update coords but keep cached city name
          final updated = LocationResult(
            lat: pos.latitude,
            lon: pos.longitude,
            city: cached.city,
            country: cached.country,
          );
          await _saveCache(updated);
          return updated;
        }
        return LocationResult(
          lat: pos.latitude,
          lon: pos.longitude,
          city: 'Unknown',
          country: '',
        );
      }
    } catch (_) {}

    // Fall back to last cached location
    final cached = await _loadCached();
    return cached ?? _fallback();
  }

  /// Force refresh — called by refresh button in UI
  static Future<LocationResult> forceRefresh() async {
    return await _fetchFresh();
  }

  // ── Private helpers ────────────────────────────────────────────────

  static Future<LocationResult> _fetchFresh() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        return _loadCached().then((c) => c ?? _fallback());
      }

      // Always get current position — never use lastKnown when app is open
      Position? pos;
      for (int attempt = 0; attempt < 3; attempt++) {
        try {
          pos = await Geolocator.getCurrentPosition(
            locationSettings: LocationSettings(
              accuracy: attempt == 0
                  ? LocationAccuracy.high // first try: high accuracy
                  : LocationAccuracy.medium, // retries: medium (faster)
              timeLimit: Duration(seconds: attempt == 0 ? 20 : 10),
            ),
          );
          break; // success — exit loop
        } catch (_) {
          if (attempt < 2) {
            await Future.delayed(const Duration(seconds: 2));
          }
        }
      }

      if (pos != null) {
        final result = await _reverseGeocode(pos.latitude, pos.longitude);
        await _saveCache(result);
        return result;
      }
    } catch (_) {}

    // GPS failed — return cache if available
    final cached = await _loadCached();
    return cached ?? _fallback();
  }

  static Future<LocationResult?> _loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble(_kLat);
      final lon = prefs.getDouble(_kLon);
      final city = prefs.getString(_kCity);
      final country = prefs.getString(_kCountry);
      if (lat == null || lon == null || city == null) return null;
      return LocationResult(
        lat: lat,
        lon: lon,
        city: city,
        country: country ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> _saveCache(LocationResult r) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kLat, r.lat);
    await prefs.setDouble(_kLon, r.lon);
    await prefs.setString(_kCity, r.city);
    await prefs.setString(_kCountry, r.country);
    await prefs.setInt(_kTime, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<LocationResult> _reverseGeocode(double lat, double lon) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final city = p.locality?.isNotEmpty == true
            ? p.locality!
            : p.subLocality?.isNotEmpty == true
                ? p.subLocality!
                : p.subAdministrativeArea?.isNotEmpty == true
                    ? p.subAdministrativeArea!
                    : p.administrativeArea?.isNotEmpty == true
                        ? p.administrativeArea!
                        : p.name?.isNotEmpty == true
                            ? p.name!
                            : '${lat.toStringAsFixed(2)}°, ${lon.toStringAsFixed(2)}°';
        return LocationResult(
          lat: lat,
          lon: lon,
          city: city,
          country: p.country ?? '',
        );
      }
    } catch (_) {}
    // Never return 'Unknown' — show coordinates instead
    return LocationResult(
      lat: lat,
      lon: lon,
      city: '${lat.toStringAsFixed(2)}°, ${lon.toStringAsFixed(2)}°',
      country: '',
    );
  }

  static LocationResult _fallback() => const LocationResult(
        lat: 24.8607,
        lon: 67.0011,
        city: 'Karachi',
        country: 'Pakistan',
      );
}
