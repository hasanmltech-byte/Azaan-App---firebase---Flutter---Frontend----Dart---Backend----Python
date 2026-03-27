import 'package:flutter/material.dart';
import '../services/device_brand_service.dart';

/// Device-specific battery optimization setup guide
class DeviceBatterySetupGuide extends StatefulWidget {
  final VoidCallback? onComplete;

  const DeviceBatterySetupGuide({super.key, this.onComplete});

  @override
  State<DeviceBatterySetupGuide> createState() =>
      _DeviceBatterySetupGuideState();
}

class _DeviceBatterySetupGuideState extends State<DeviceBatterySetupGuide> {
  late Future<Map<String, dynamic>> _setupGuide;

  @override
  void initState() {
    super.initState();
    _setupGuide = DeviceBrand.getSetupGuideForDevice();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _setupGuide,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: const Color(0xFF0D1117),
            appBar: AppBar(
              backgroundColor: const Color(0xFF161B22),
              elevation: 0,
              title: const Text('Setup Guide'),
            ),
            body: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC9A84C)),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: const Color(0xFF0D1117),
            appBar: AppBar(
              backgroundColor: const Color(0xFF161B22),
              elevation: 0,
              title: const Text('Setup Guide'),
            ),
            body: const Center(
              child: Text('Unable to load setup guide'),
            ),
          );
        }

        final guide = snapshot.data!;
        final brand = guide['brand'] as String;
        final tips = guide['tips'] as String;

        return Scaffold(
          backgroundColor: const Color(0xFF0D1117),
          appBar: AppBar(
            backgroundColor: const Color(0xFF161B22),
            elevation: 0,
            title: const Text('⚡ Device Setup Guide'),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Device Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC9A84C).withValues(alpha: 0.1),
                    border: Border.all(color: const Color(0xFFC9A84C)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.phone_android,
                        color: Color(0xFFC9A84C),
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Your Device',
                              style: TextStyle(
                                color: Color(0xFF8B949E),
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              brand.toUpperCase(),
                              style: const TextStyle(
                                color: Color(0xFFC9A84C),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Important Notice
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    border:
                        Border.all(color: Colors.red.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.warning,
                        color: Colors.red,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'These steps are CRITICAL to ensure alarms work reliably.',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Tips
                Text(
                  tips,
                  style: const TextStyle(
                    color: Color(0xFFE6EDF3),
                    fontSize: 14,
                    height: 1.6,
                    fontFamily: 'Courier',
                  ),
                ),
                const SizedBox(height: 32),

                // Action Buttons
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await DeviceBrand.openBatteryOptimizationSettings();
                        },
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Open Battery Settings'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC9A84C),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onComplete?.call();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF30363D),
                          foregroundColor: const Color(0xFFE6EDF3),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Done - Alarms are ready!'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
