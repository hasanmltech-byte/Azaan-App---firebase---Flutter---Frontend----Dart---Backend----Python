import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../services/prayer_api_service.dart';

class FiqaDropdown extends StatelessWidget {
  final FiqaType selected;
  final bool updating;
  final ValueChanged<FiqaType> onSelected;

  const FiqaDropdown({
    super.key,
    required this.selected,
    required this.updating,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.surface2,
        border: Border.all(
          // Fixed: withValues instead of deprecated withOpacity
          color: AppColors.gold.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info header
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Calculation method — times update automatically',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.muted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                if (updating)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: AppColors.gold,
                    ),
                  ),
              ],
            ),
          ),

          // Hanafi option
          _FiqaOption(
            label: 'Fiqa Hanafi',
            detail: 'Asr: later (double shadow) • Fajr: 18°',
            isSelected: selected == FiqaType.hanafi,
            onTap: () => onSelected(FiqaType.hanafi),
          ),

          const SizedBox(height: 3),

          // Jafari option
          _FiqaOption(
            label: 'Fiqa Jafari',
            detail: 'Asr: earlier (single shadow) • Fajr: ~16°',
            isSelected: selected == FiqaType.jafari,
            onTap: () => onSelected(FiqaType.jafari),
          ),
        ],
      ),
    );
  }
}

class _FiqaOption extends StatelessWidget {
  final String label;
  final String detail;
  final bool isSelected;
  final VoidCallback onTap;

  const _FiqaOption({
    required this.label,
    required this.detail,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          // Fixed: both withValues instead of deprecated withOpacity
          color: isSelected
              ? AppColors.gold.withValues(alpha: 0.11)
              : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? AppColors.gold.withValues(alpha: 0.5)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? AppColors.gold2 : AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.muted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isSelected ? 1.0 : 0.0,
              child: const Icon(
                Icons.check_rounded,
                color: AppColors.gold2,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
