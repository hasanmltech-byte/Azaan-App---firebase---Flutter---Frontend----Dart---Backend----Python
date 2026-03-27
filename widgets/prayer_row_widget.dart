import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../models/prayer_times_model.dart';

class PrayerRowWidget extends StatelessWidget {
  final PrayerTime prayer;
  final bool isNext;
  final bool isPassed;
  final bool showToggle;
  final VoidCallback onToggle;

  const PrayerRowWidget({
    super.key,
    required this.prayer,
    required this.isNext,
    required this.isPassed,
    required this.showToggle,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: isPassed ? 0.42 : 1.0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isNext ? const Color(0xFF1A2A14) : AppColors.surface,
          border: Border.all(
            color: isNext ? AppColors.gold : AppColors.border,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Gold left bar on next prayer
            if (isNext)
              Container(
                width: 3,
                height: 40,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),

            // Emoji
            Text(prayer.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),

            // Name + Arabic
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prayer.name,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: isNext ? AppColors.gold2 : AppColors.textMain,
                    ),
                  ),
                  Text(
                    prayer.arabic,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),

            // Time
            Text(
              prayer.displayTime,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isNext ? AppColors.gold2 : AppColors.textMain,
              ),
            ),

            // Individual alarm toggle
            if (showToggle) ...[
              const SizedBox(width: 12),
              GestureDetector(
                onTap: isPassed ? null : onToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 42,
                  height: 24,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: (prayer.alarmOn && !isPassed)
                        ? AppColors.teal
                        : AppColors.border,
                  ),
                  alignment: (prayer.alarmOn && !isPassed)
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(blurRadius: 3, color: Colors.black38),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
