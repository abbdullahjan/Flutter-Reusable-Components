import 'package:flutter/material.dart';

/// "or" separator used when optional actions (Google, Facebook, ...) are
/// provided by the host application through the `extraActions` parameter of
/// the screens. Extracted from
/// `amaan_van_repo/lib/views/auth_views/components/or_divider.dart`.
class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key, this.label = 'or'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Expanded(child: Divider(endIndent: 8)),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const Expanded(child: Divider(indent: 8)),
      ],
    );
  }
}

/// Row with a question and a highlighted action, e.g.
/// "Don't have an account? Signup".
///
/// Extracted from
/// `amaan_van_repo/lib/views/auth_views/components/signin_signup.dart`.
class AuthLinkRow extends StatelessWidget {
  const AuthLinkRow({
    super.key,
    required this.text,
    required this.actionLabel,
    this.onPressed,
  });

  final String text;
  final String actionLabel;

  /// When `null` the action label is rendered as plain text.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text('$text ', style: theme.textTheme.bodyMedium),
        if (onPressed == null)
          Text(actionLabel, style: theme.textTheme.bodyMedium)
        else
          InkWell(
            onTap: onPressed,
            borderRadius: const BorderRadius.all(Radius.circular(6)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                actionLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
