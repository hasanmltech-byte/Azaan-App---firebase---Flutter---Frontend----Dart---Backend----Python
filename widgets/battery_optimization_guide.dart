import 'package:flutter/material.dart';

class BatteryOptimizationGuide extends StatefulWidget {
  final VoidCallback? onDismiss;
  const BatteryOptimizationGuide({super.key, this.onDismiss});

  @override
  State<BatteryOptimizationGuide> createState() =>
      _BatteryOptimizationGuideState();
}

class _BatteryOptimizationGuideState extends State<BatteryOptimizationGuide> {
  int _currentStep = 0;

  final List<BatteryStep> steps = [
    BatteryStep(
      emoji: '🔋',
      title: 'Disable Battery Optimization',
      description:
          'This is the MOST IMPORTANT step. Many phones aggressively kill apps to save battery.',
      devices: 'Tecno, Infinix, Xiaomi, Oppo, Vivo',
      instructions: [
        '1. Open Settings',
        '2. Go to Battery or Power Management',
        '3. Look for Battery Optimization / Power Saving',
        '4. Find "Azan Alarm" in the list',
        '5. Select → Choose "Don\'t optimize" or "No restrictions"',
      ],
    ),
    BatteryStep(
      emoji: '▶️',
      title: 'Enable Auto-Start Permission',
      description: 'Allows app to restart automatically after device shutdown.',
      devices: 'All phones especially Chinese brands',
      instructions: [
        '1. Go to Settings → Apps / App Management',
        '2. Find "Azan Alarm"',
        '3. Tap Permissions or Advanced Settings',
        '4. Enable "Auto Start" or "Allow Auto Launch"',
      ],
    ),
    BatteryStep(
      emoji: '📲',
      title: 'Allow Background Activity',
      description: 'Keeps the app running in background without interruption.',
      devices: 'All phones',
      instructions: [
        '1. Settings → Apps → Azan Alarm',
        '2. Look for Permissions or Additional Settings',
        '3. Enable:',
        '   • Allow background activity',
        '   • Allow background data',
        '   • Run in background',
      ],
    ),
    BatteryStep(
      emoji: '📌',
      title: 'Lock App in Recent Apps',
      description:
          'Prevents RAM cleaners and system from removing the app from memory.',
      devices: 'Helps on all devices',
      instructions: [
        '1. Open the app',
        '2. Tap Recent Apps icon (or swipe up)',
        '3. Find "Azan Alarm"',
        '4. Long press on it',
        '5. Tap "Lock 🔒" or "Pin" (if available)',
      ],
    ),
    BatteryStep(
      emoji: '⚡',
      title: 'Turn Off Power Saving Mode',
      description:
          'Power saving modes restrict background processes and notifications.',
      devices: 'All phones',
      instructions: [
        '1. Swipe down Quick Settings (top of screen)',
        '2. Look for Power Saver or Battery Saver',
        '3. Make sure it is TURNED OFF',
        '4. Also check Settings → Battery → Power Savings',
        '5. Turn off Ultra Power Saving if present',
      ],
    ),
    BatteryStep(
      emoji: '⏰',
      title: 'Grant Exact Alarm Permission',
      description:
          'Allows alarms to ring at exactly the right time. (Android 12+)',
      devices: 'Android 12 and higher',
      instructions: [
        '1. Go to Settings → Apps → Permissions',
        '2. Look for "Schedule exact alarm" or "Set alarms"',
        '3. Find Azan Alarm and Enable it',
        'This permission is already requested in code.',
      ],
    ),
    BatteryStep(
      emoji: '🎯',
      title: 'Complete Setup',
      description:
          'Once you complete these steps, your alarms will work reliably!',
      devices: 'All devices',
      instructions: [
        '✅ Battery optimization disabled for this app',
        '✅ Auto-start enabled',
        '✅ Background activity allowed',
        '✅ App locked in recents',
        '✅ Power saving mode off',
        'Your alarms are now safe from being killed by the system!',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final step = steps[_currentStep];
    final isLastStep = _currentStep == steps.length - 1;

    return AlertDialog(
      backgroundColor: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Text(
            step.emoji,
            style: const TextStyle(fontSize: 32),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              step.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              step.description,
              style: const TextStyle(
                color: Color(0xFFBEC3CB),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: Text(
                '📱 Devices: ${step.devices}',
                style: const TextStyle(
                  color: Color(0xFFC9A84C),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...step.instructions.map((instruction) {
              final isTitle =
                  instruction.endsWith(':') && !instruction.startsWith('•');
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!instruction.startsWith('•'))
                      const Text(
                        '→ ',
                        style: TextStyle(
                          color: Color(0xFFC9A84C),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        instruction.replaceFirst('→ ', ''),
                        style: TextStyle(
                          color: isTitle
                              ? const Color(0xFFE6EDF3)
                              : const Color(0xFFBEC3CB),
                          fontSize: 13,
                          fontWeight:
                              isTitle ? FontWeight.w600 : FontWeight.normal,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 20),
            // Progress indicator
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_currentStep + 1) / steps.length,
                minHeight: 4,
                backgroundColor: const Color(0xFF30363D),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFFC9A84C),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Step ${_currentStep + 1} of ${steps.length}',
                style: const TextStyle(
                  color: Color(0xFF8B949E),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (_currentStep > 0)
          TextButton(
            onPressed: () {
              setState(() {
                _currentStep--;
              });
            },
            child: const Text(
              '← Back',
              style: TextStyle(color: Color(0xFFC9A84C)),
            ),
          ),
        const Spacer(),
        TextButton(
          onPressed: () {
            if (isLastStep) {
              Navigator.pop(context);
              widget.onDismiss?.call();
            } else {
              setState(() {
                _currentStep++;
              });
            }
          },
          child: Text(
            isLastStep ? '✅ Done' : 'Next →',
            style: const TextStyle(
              color: Color(0xFFC9A84C),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class BatteryStep {
  final String emoji;
  final String title;
  final String description;
  final String devices;
  final List<String> instructions;

  BatteryStep({
    required this.emoji,
    required this.title,
    required this.description,
    required this.devices,
    required this.instructions,
  });
}
