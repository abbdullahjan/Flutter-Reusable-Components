import 'package:flutter/material.dart';

import '../auth_config.dart';
import '../services/auth_service.dart';
import '../state/auth_state.dart';
import '../validators/auth_validators.dart';
import '../widgets/auth_button.dart';
import '../widgets/auth_link_row.dart';
import '../widgets/auth_text_field.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';

/// Reusable email/password login screen.
///
/// Extracted from `amaan_van_repo/lib/views/auth_views/login_views/login_view.dart`
/// and `firebase_login_services.dart`, with the application-specific parts
/// removed:
///
/// * no `provider`, `flutter_screenutil`, branding colors or bundled assets
/// * no named routes or app home screen: the host application reacts through
///   [onLoginSuccess] (and the other callbacks)
/// * no Google/Facebook buttons (optional extensions can be injected through
///   [extraActions])
/// * feedback uses a themed [SnackBar] instead of the source app's flushbar
///
/// Everything else is preserved: form validation, loading indicator that also
/// prevents duplicate submissions, password visibility toggle and the same
/// credential error messages.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.config = const AuthConfig(),
    this.onLoginSuccess,
    this.onNavigateToSignup,
    this.onForgotPassword,
    this.onBack,
    this.header,
    this.extraActions = const <Widget>[],
  });

  final AuthConfig config;

  /// Called after a successful login. When `null` the screen simply pops.
  final ValueChanged<AuthResult>? onLoginSuccess;

  /// Called when the user taps "Signup". When `null` the module pushes its own
  /// [SignupScreen].
  final VoidCallback? onNavigateToSignup;

  /// Called when the user taps "Forgot Password?". When `null` the module
  /// pushes its own [ForgotPasswordScreen].
  final VoidCallback? onForgotPassword;

  /// Custom back behaviour. When `null` the screen pops.
  final VoidCallback? onBack;

  /// Optional banner shown above the form.
  final Widget? header;

  /// Optional additional buttons (e.g. Google/Facebook) rendered below the
  /// form. When not empty an "or" divider is shown above them.
  final List<Widget> extraActions;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final LoginState _state = LoginState();

  /// Resolved lazily so constructing the screen never initialises Firebase.
  late final AuthService _service = widget.config.resolveService();

  AuthMessages get _messages => widget.config.messages;

  @override
  void dispose() {
    _state.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleBack() {
    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }
    Navigator.of(context).maybePop();
  }

  void _openSignup() {
    if (widget.onNavigateToSignup != null) {
      widget.onNavigateToSignup!();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SignupScreen(
          config: widget.config,
          extraActions: widget.extraActions,
        ),
      ),
    );
  }

  void _openForgotPassword() {
    if (widget.onForgotPassword != null) {
      widget.onForgotPassword!();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ForgotPasswordScreen(config: widget.config),
      ),
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    _state.setLoading(true);
    final AuthResult result = await _service.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted) {
      return;
    }
    _state.setLoading(false);

    if (result.isSuccess) {
      _showMessage(_messages.loginSuccess, isError: false);
      if (widget.onLoginSuccess != null) {
        widget.onLoginSuccess!(result);
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
        title: Text(_messages.signInTitle),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (widget.header != null) widget.header!,
                  Padding(
                    padding: widget.config.contentPadding,
                    child: AutofillGroup(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Text(
                              _messages.signInTitle,
                              style: theme.textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 24),
                            AuthTextField(
                              controller: _emailController,
                              label: _messages.emailLabel,
                              prefixIcon: const Icon(Icons.email_outlined),
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const <String>[
                                AutofillHints.email,
                              ],
                              validator: AuthValidators.validateEmail,
                            ),
                            const SizedBox(height: 16),
                            ListenableBuilder(
                              listenable: _state,
                              builder: (context, _) {
                                return AuthTextField(
                                  controller: _passwordController,
                                  label: _messages.passwordLabel,
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  obscureText: _state.isPasswordHidden,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const <String>[
                                    AutofillHints.password,
                                  ],
                                  suffixIcon: IconButton(
                                    tooltip: _state.isPasswordHidden
                                        ? 'Show password'
                                        : 'Hide password',
                                    onPressed: _state.togglePasswordVisibility,
                                    icon: Icon(
                                      _state.isPasswordHidden
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                  ),
                                  validator: (String? value) =>
                                      AuthValidators.validatePassword(
                                        value,
                                        isLogin: true,
                                      ),
                                );
                              },
                            ),
                            if (widget.config.enableForgotPassword)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _openForgotPassword,
                                  child: Text(_messages.forgotPasswordLabel),
                                ),
                              )
                            else
                              const SizedBox(height: 8),
                            const SizedBox(height: 8),
                            ListenableBuilder(
                              listenable: _state,
                              builder: (context, _) {
                                return AuthButton(
                                  label: _messages.signInButtonLabel,
                                  isLoading: _state.isLoading,
                                  onPressed: _submit,
                                );
                              },
                            ),
                            if (widget.extraActions.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 24),
                              AuthOrDivider(label: _messages.orLabel),
                              const SizedBox(height: 16),
                              for (final Widget action in widget.extraActions)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: action,
                                ),
                            ],
                            const SizedBox(height: 20),
                            AuthLinkRow(
                              text: _messages.noAccountText,
                              actionLabel: _messages.switchToSignUpLabel,
                              onPressed: _openSignup,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
