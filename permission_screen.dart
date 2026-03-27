import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/device_brand_service.dart';
import 'home_screen.dart';
import 'app_colors.dart';
import 'widgets/device_battery_setup_guide.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});
  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

// Each permission step definition
class _PermStep {
  final String key;
  final String icon;
  final String title;
  final String subtitle;
  final String permission;
  final String desc;
  final String button;
  const _PermStep({
    required this.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.permission,
    required this.desc,
    required this.button,
  });
}

const _allSteps = [
  _PermStep(
    key: 'location',
    icon: '📍',
    title: 'To ensure you\'re on\nthe right Path',
    subtitle: 'Please enable the location permission',
    permission: 'Location Permission',
    desc: 'To obtain accurate prayer times for your city',
    button: 'Continue',
  ),
  _PermStep(
    key: 'notification',
    icon: '🔔',
    title: 'Never miss a prayer',
    subtitle: 'Please enable notification permission',
    permission: 'Notification Permission',
    desc: 'To show Azan alert on your screen',
    button: 'Continue',
  ),
  _PermStep(
    key: 'exactAlarm',
    icon: '⏰',
    title: 'Alarm at exact time',
    subtitle: 'Please enable exact alarm permission',
    permission: 'Exact Alarm Permission',
    desc: 'To fire alarm precisely at prayer time',
    button: 'Continue',
  ),
  _PermStep(
    key: 'battery',
    icon: '🔋',
    title: 'Keep Azan alive',
    subtitle: 'Please enable background permission',
    permission: 'Enable App Background',
    desc: 'The app continues to serve you in the background',
    button: 'Enable',
  ),
  _PermStep(
    key: 'overlay',
    icon: '🖥️',
    title: 'Show on lock screen',
    subtitle: 'Please allow display over other apps',
    permission: 'Display Over Other Apps',
    desc: 'To show Azan alert even when phone is locked',
    button: 'Enable',
  ),
];

class _PermissionScreenState extends State<PermissionScreen> {
  List<_PermStep> _pendingSteps = []; // only missing permissions
  int _stepIndex = 0;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkAndFilter();
  }

  // Check which permissions are already granted — only show missing ones
  Future<void> _checkAndFilter() async {
    final missing = <_PermStep>[];

    for (final step in _allSteps) {
      final granted = await _isGranted(step.key);
      if (!granted) missing.add(step);
    }

    if (missing.isEmpty) {
      // All granted — go straight to home, no permission screen at all
      if (mounted) _goHome();
      return;
    }

    setState(() {
      _pendingSteps = missing;
      _stepIndex = 0;
      _checking = false;
    });
  }

  Future<bool> _isGranted(String key) async {
    switch (key) {
      case 'location':
        return (await Permission.location.status).isGranted;
      case 'notification':
        return (await Permission.notification.status).isGranted;
      case 'exactAlarm':
        return (await Permission.scheduleExactAlarm.status).isGranted;
      case 'battery':
        return (await Permission.ignoreBatteryOptimizations.status).isGranted;
      case 'overlay':
        return (await Permission.systemAlertWindow.status).isGranted;
      default:
        return true;
    }
  }

  Future<void> _handleStep() async {
    final step = _pendingSteps[_stepIndex];
    PermissionStatus status = PermissionStatus.denied;

    switch (step.key) {
      case 'location':
        status = await Permission.location.request();
        break;
      case 'notification':
        status = await Permission.notification.request();
        break;
      case 'exactAlarm':
        status = await Permission.scheduleExactAlarm.request();
        break;
      case 'battery':
        status = await Permission.ignoreBatteryOptimizations.request();
        break;
      case 'overlay':
        status = await Permission.systemAlertWindow.request();
        break;
    }

    // Check if permission was actually granted
    if (status.isGranted) {
      _nextStep();
    } else {
      // Show error message if permission not granted
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${step.title} permission is required to continue',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _nextStep() {
    if (_stepIndex < _pendingSteps.length - 1) {
      setState(() => _stepIndex++);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    if (mounted) {
      // Check if device needs battery optimization setup
      final needsSetup = await DeviceBrand.isAggressiveOptimizer();
      if (needsSetup && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DeviceBatterySetupGuide(
              onComplete: _goHome,
            ),
          ),
        );
      } else {
        if (mounted) _goHome();
      }
    }
  }

  void _goHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Still checking permissions
    if (_checking) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.gold),
        ),
      );
    }

    final step = _pendingSteps[_stepIndex];
    final total = _pendingSteps.length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.5),
                radius: 1.2,
                colors: [Color(0x22C9A84C), AppColors.bg],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),

                // Progress dots — only for pending steps
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                      total,
                      (i) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: i == _stepIndex ? 20 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: i <= _stepIndex
                                  ? AppColors.gold
                                  : AppColors.border,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          )),
                ),

                const Spacer(),

                Text(step.icon, style: const TextStyle(fontSize: 72)),
                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    step.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    step.subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.muted,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 40),

                // Permission card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(step.icon,
                                style: const TextStyle(fontSize: 22)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(step.permission,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  )),
                              const SizedBox(height: 3),
                              Text(step.desc,
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                  )),
                            ],
                          ),
                        ),
                        Container(
                          width: 44,
                          height: 26,
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: EdgeInsets.only(right: 3),
                              child: CircleAvatar(
                                radius: 10,
                                backgroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 4,
                      ),
                      onPressed: _handleStep,
                      child: Text(
                        step.button,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Center(
                    child: Text(
                      'This permission is required to continue',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
