import 'package:flutter/material.dart';

/// Optional decorative banner shown above the authentication forms.
///
/// Adapted from `amaan_van_repo/lib/views/widgets/custom_signup_widget.dart`.
/// The curved shape is preserved but the source application's green branding
/// and bundled logo asset were removed: the banner uses
/// `Theme.of(context).colorScheme.primary` and an optional [logo] supplied by
/// the host application.
class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    this.label,
    this.logo,
    this.heightFactor = 0.22,
    this.curved = true,
  });

  /// Optional title rendered inside the banner (e.g. the app name).
  final String? label;

  /// Optional logo. Typically an [Icon] or an `Image` provided by the host.
  final Widget? logo;

  /// Banner height as a fraction of the available height (0.22 = 22%).
  final double heightFactor;

  /// When `false` the banner is rendered as a plain rectangle.
  final bool curved;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double height = (MediaQuery.sizeOf(context).height * heightFactor)
        .clamp(96.0, 260.0);
    final Color foreground = theme.colorScheme.onPrimary;

    return SizedBox(
      width: double.infinity,
      height: height,
      child: ClipPath(
        clipper: curved ? _SemiCircleClipper() : null,
        child: ColoredBox(
          color: theme.colorScheme.primary,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                ?logo,
                if (logo != null && label != null) const SizedBox(height: 8),
                if (label != null)
                  Text(
                    label!,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SemiCircleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final double heightOffset = size.height * 0.2;
    final Path path = Path()
      ..lineTo(0, size.height - heightOffset)
      ..cubicTo(
        size.width * 0.25,
        size.height + heightOffset,
        size.width * 0.75,
        size.height + heightOffset,
        size.width,
        size.height - heightOffset,
      )
      ..lineTo(size.width, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
