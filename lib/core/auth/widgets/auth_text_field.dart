import 'package:flutter/material.dart';

/// Labelled, themed text field used by the authentication screens.
///
/// Extracted from `amaan_van_repo/lib/views/widgets/custom_text_field.dart`
/// without `flutter_screenutil`: sizes use logical pixels and colors come from
/// the host application's [ThemeData] instead of the source app palette.
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.enabled = true,
    this.onChanged,
    this.focusNode,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      obscureText: obscureText,
      obscuringCharacter: '*',
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      textCapitalization: textCapitalization,
      onChanged: onChanged,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        isDense: true,
        labelText: label,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      validator: validator,
    );
  }
}
