import 'package:flutter/material.dart';
import 'package:guardian/app/theme/app_theme.dart';

enum GuardianStatusTone { neutral, success, warning, emergency }

Color guardianToneColor(BuildContext context, GuardianStatusTone tone) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return switch (tone) {
    GuardianStatusTone.neutral =>
      dark ? AppColors.informationDark : AppColors.information,
    GuardianStatusTone.success =>
      dark ? AppColors.successDark : AppColors.success,
    GuardianStatusTone.warning =>
      dark ? AppColors.warningDark : AppColors.warning,
    GuardianStatusTone.emergency =>
      dark ? AppColors.emergencyDark : AppColors.emergency,
  };
}

class GuardianStatusPill extends StatelessWidget {
  const GuardianStatusPill({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
  });

  final String label;
  final GuardianStatusTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = guardianToneColor(context, tone);
    return Semantics(
      label: 'Status: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon ?? Icons.circle,
                size: icon == null ? 8 : 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GuardianActionCard extends StatelessWidget {
  const GuardianActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.tone = GuardianStatusTone.neutral,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final GuardianStatusTone tone;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final color = guardianToneColor(context, tone);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 88),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(description,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                trailing ??
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GuardianSectionHeader extends StatelessWidget {
  const GuardianSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class GuardianDangerButton extends StatelessWidget {
  const GuardianDangerButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    final style = ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, 52),
    );
    if (icon == null) {
      return ElevatedButton(
        onPressed: onPressed,
        style: style,
        child: Text(label),
      );
    }
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: style,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
