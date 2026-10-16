import 'package:flutter/material.dart';

/// Full-width primary action button used by the authentication screens.
///
/// Extracted from `amaan_van_repo/lib/views/widgets/custom_button.dart`.
/// Reimplemented on top of [FilledButton] so it follows the host theme.
/// When [isLoading] is `true` the button is disabled, which prevents duplicate
/// submissions, and shows a progress indicator.
class AuthButton extends StatelessWidget {
  const AuthButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  final String label;

  /// `null` renders the button in its disabled state.
  final VoidCallback? onPressed;

  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? effectiveOnPressed = isLoading ? null : onPressed;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: effectiveOnPressed,
        child: isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(label),
                ],
              ),
      ),
    );
  }
}
