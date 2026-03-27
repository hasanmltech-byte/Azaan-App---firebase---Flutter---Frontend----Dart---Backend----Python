import 'package:flutter/material.dart';
import '../app_colors.dart';

class NextPrayerCard extends StatelessWidget {
  final String prayerName;
  final String prayerTime;
  final String countdown;

  const NextPrayerCard({
    super.key,
    required this.prayerName,
    required this.prayerTime,
    required this.countdown,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF17251A), AppColors.surface2],
        ),
        border: Border.all(color: AppColors.gold, width: 1),
        boxShadow: [
          BoxShadow(
            // Fixed: withValues instead of deprecated withOpacity
            color: AppColors.gold.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'NEXT PRAYER',
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 2.5,
                  color: AppColors.gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                prayerName,
                style: const TextStyle(
                  fontSize: 28,
                  color: AppColors.gold2,
                  fontWeight: FontWeight.w400,
                ),
              ),
              Text(
                prayerTime,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'IN',
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 1.5,
                  color: AppColors.muted,
                ),
              ),
              Text(
                countdown,
                style: const TextStyle(
                  fontSize: 34,
                  color: AppColors.gold2,
                  fontWeight: FontWeight.w300,
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
