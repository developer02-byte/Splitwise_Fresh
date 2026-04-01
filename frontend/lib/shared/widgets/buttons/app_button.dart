import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// AppButton — Fully accessible, themed button component.
/// All interactive elements must be >= 48dp tall (WCAG 2.1 AA).
/// Extracted to shared/widgets to prevent code duplication across features.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDestructive;
  final IconData? icon;
  final String? semanticLabel;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isDestructive = false,
    this.icon,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;

    return Semantics(
      label: semanticLabel ?? label,
      button: true,
      child: SizedBox(
        // WCAG 2.1 AA: minimum 48dp tap target height
        height: 48,
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            disabledBackgroundColor: color.withOpacity(0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18),
                      const SizedBox(width: 8.0),
                    ],
                    Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Ghost / outline button variant
class AppOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const AppOutlineButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: SizedBox(
        height: 48,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            side: BorderSide(color: Theme.of(context).colorScheme.outline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8.0),
              ],
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
