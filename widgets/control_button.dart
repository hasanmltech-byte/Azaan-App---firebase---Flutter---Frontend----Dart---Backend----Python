import 'package:flutter/material.dart';
import '../app_colors.dart';

class ControlButton extends StatelessWidget {
  final String label;
  final String icon;
  final bool isOn;
  final String? badge;
  final bool badgeHighlight;
  final VoidCallback? onTap;
  final Color activeColor;
  final Color activeBg;
  final Color activeBorder;

  const ControlButton({
    super.key,
    required this.label,
    required this.icon,
    required this.isOn,
    required this.onTap,
    required this.activeColor,
    required this.activeBg,
    required this.activeBorder,
    this.badge,
    this.badgeHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final bg =
        disabled ? AppColors.surface : (isOn ? activeBg : AppColors.surface);
    final border =
        disabled ? AppColors.border : (isOn ? activeBorder : AppColors.border);
    final txtColor =
        disabled ? AppColors.border : (isOn ? activeColor : AppColors.muted);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: bg,
          border: Border.all(color: border, width: 2),
        ),
        child: Row(
          children: [
            // Pulsing dot for Azan button (no badge)
            if (badge == null) ...[
              _StatusDot(on: isOn && !disabled),
              const SizedBox(width: 10),
            ],

            // Emoji icon for Ramzan button (has badge)
            if (badge != null) ...[
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
            ],

            // Label
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: txtColor,
                  letterSpacing: 0.4,
                ),
              ),
            ),

            // Right side: icon or badge
            if (badge == null)
              Text(icon, style: const TextStyle(fontSize: 18))
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: badgeHighlight ? AppColors.gold : Colors.transparent,
                  border: badgeHighlight
                      ? null
                      : Border.all(color: AppColors.border),
                ),
                child: Text(
                  badge!,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: badgeHighlight ? Colors.black : AppColors.muted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Pulsing status dot ─────────────────────────────────────────────────
class _StatusDot extends StatefulWidget {
  final bool on;
  const _StatusDot({required this.on});
  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 1,
      end: 0.3,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.on ? AppColors.green : AppColors.muted;
    // Fixed: withValues instead of deprecated withOpacity
    return widget.on
        ? FadeTransition(opacity: _anim, child: _dot(color))
        : _dot(color);
  }

  Widget _dot(Color c) => Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: c,
          boxShadow: widget.on
              ? [BoxShadow(color: c.withValues(alpha: 0.7), blurRadius: 6)]
              : null,
        ),
      );
}
