import 'package:flutter/services.dart';

class DeviceBrand {
  static const _brandChannel = MethodChannel('brand_info');

  /// Get device manufacturer (Samsung, Xiaomi, Tecno, etc.)
  static Future<String> getManufacturer() async {
    try {
      final String manufacturer =
          await _brandChannel.invokeMethod('getManufacturer');
      return manufacturer.toLowerCase();
    } catch (e) {
      return 'unknown';
    }
  }

  /// Check if device is a common aggressive optimizer
  static Future<bool> isAggressiveOptimizer() async {
    final brand = await getManufacturer();
    final aggressiveBrands = [
      'samsung',
      'xiaomi',
      'redmi',
      'poco',
      'oppo',
      'vivo',
      'realme',
      'tecno',
      'infinix',
      'oneplus',
      'honor',
    ];
    return aggressiveBrands.contains(brand);
  }

  /// Get device-specific tips
  static Future<String> getDeviceSpecificTips() async {
    final brand = await getManufacturer();

    return switch (brand.toLowerCase()) {
      'samsung' => '''
🔧 Samsung-Specific Fixes:

1. Go to Settings → Apps → Azan Alarm → Permissions
2. Enable "Allow background activity"
3. Settings → Battery → Battery Saver → Exception
4. Add Azan Alarm to exceptions
5. Some Samsung models: Settings → Device Care → Battery → Manage app battery usage
6. Turn OFF "Adaptive battery"
      ''',
      'xiaomi' || 'redmi' || 'poco' => '''
🔧 Xiaomi/Redmi-Specific Fixes:

1. Settings → Apps → Azan Alarm → Permissions
2. Enable all permissions including "Display pop-ups while running in background"
3. Settings → Battery and device care → Battery → App launch
4. Find Azan Alarm and set to "Unrestricted"
5. IMPORTANT: Disable "AI power saving mode"
6. Don't let MIUI lock the app in recent apps
      ''',
      'oppo' || 'vivo' || 'realme' => '''
🔧 Oppo/Vivo/Realme-Specific Fixes:

1. Settings → Apps → Azan Alarm → Permissions
2. Toggle ON all options
3. Settings → Battery → App Launch Assistant
4. Find Azan Alarm → Set to "Allow"
5. Settings → Battery → Power Saving Manager
6. Remove Azan Alarm from restrictions
      ''',
      'tecno' || 'infinix' => '''
🔧 Tecno/Infinix-Specific Fixes:

These brands are known for aggressive app killing:

1. Settings → Apps & Notifications → Azan Alarm
2. Enable "Allow background activity"
3. Settings → Battery → Battery Optimization
4. Find Azan Alarm → "Don't optimize"
5. Settings → Advanced Settings → App Permissions
6. Enable all location and notification permissions
7. Lock the app in Recent Apps (long press and lock)
      ''',
      _ => '''
🔧 General Battery Optimization Guide:

1. Disable battery optimization for this app
2. Enable auto-start permission
3. Allow background activity
4. Lock app in recent apps
5. Turn off power saving modes
6. Grant exact alarm permission (Android 12+)
      '''
    };
  }

  /// Open battery optimization settings
  static Future<void> openBatteryOptimizationSettings() async {
    try {
      await _brandChannel.invokeMethod('openSettings', {
        'package': 'com.android.settings',
      });
    } catch (e) {
      // Fallback: try opening battery settings
      try {
        await _brandChannel.invokeMethod('openSettings', {
          'package': 'com.example.azaan_ramzan_timings',
        });
      } catch (_) {
        // User will have to do it manually
      }
    }
  }

  /// Show setup guide for user based on their device
  static Future<Map<String, dynamic>> getSetupGuideForDevice() async {
    final brand = await getManufacturer();
    final isAggressive = await isAggressiveOptimizer();
    final tips = await getDeviceSpecificTips();

    return {
      'brand': brand,
      'isAggressive': isAggressive,
      'tips': tips,
      'needsGuidance': isAggressive,
    };
  }
}
