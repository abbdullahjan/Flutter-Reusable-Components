import 'package:flutter/material.dart';

import '../auth_config.dart';
import '../services/auth_service.dart';
import '../state/auth_state.dart';
import '../validators/auth_validators.dart';
import '../widgets/auth_button.dart';
import '../widgets/auth_text_field.dart';

/// Optional password-reset screen.
///
/// Extracted from `amaan_van_repo/lib/views/auth_views/forgot_password_view/`
/// and `firebase_forgot_password_services.dart`. It is an optional extension of
/// the core module: the login screen only links to it when
/// `AuthConfig.enableForgotPassword` is `true`, and a custom
/// `onForgotPassword` callback can bypass it entirely.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    this.config = const AuthConfig(),
    this.onPasswordResetSent,
    this.onBack,
  });

  final AuthConfig config;

  /// Called after the reset email was sent. When `null` the screen pops.
  final VoidCallback? onPasswordResetSent;

  /// Custom back behaviour. When `null` the screen pops.
  final VoidCallback? onBack;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final LoginState _state = LoginState();

  late final AuthService _service = widget.config.resolveService();

  AuthMessages get _messages => widget.config.messages;

  @override
  void dispose() {
    _state.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _handleBack() {
    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }
    Navigator.of(context).maybePop();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    _state.setLoading(true);
    final AuthResult result = await _service.sendPasswordResetEmail(
      _emailController.text.trim(),
    );
    if (!mounted) {
      return;
    }
    _state.setLoading(false);

    if (result.isSuccess) {
      _showMessage(_messages.passwordResetSent, isError: false);
      if (widget.onPasswordResetSent != null) {
        widget.onPasswordResetSent!();
      } else {
        Navigator.of(context).maybePop();
      }
      return;
    }

    _showMessage(
      result.errorMessage ?? AuthServiceMessages.unknownError,
      isError: true,
    );
  }

  void _showMessage(String message, {required bool isError}) {
    final ThemeData theme = Theme.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          backgroundColor: isError ? theme.colorScheme.error : null,
          content: Row(
            children: <Widget>[
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: isError ? theme.colorScheme.onError : null,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _handleBack),
        title: Text(_messages.forgotPasswordTitle),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: widget.config.contentPadding,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      _messages.forgotPasswordTitle,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _messages.forgotPasswordDescription,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    AuthTextField(
                      controller: _emailController,
                      label: _messages.emailLabel,
                      prefixIcon: const Icon(Icons.email_outlined),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      autofillHints: const <String>[AutofillHints.email],
                      validator: AuthValidators.validateEmail,
                    ),
                    const SizedBox(height: 24),
                    ListenableBuilder(
                      listenable: _state,
                      builder: (context, _) {
                        return AuthButton(
                          label: _messages.forgotPasswordButtonLabel,
                          isLoading: _state.isLoading,
                          onPressed: _submit,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
