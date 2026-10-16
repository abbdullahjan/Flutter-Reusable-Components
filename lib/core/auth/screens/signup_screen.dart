import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/phone_number.dart';

import '../auth_config.dart';
import '../services/auth_service.dart';
import '../state/auth_state.dart';
import '../validators/auth_validators.dart';
import '../widgets/auth_button.dart';
import '../widgets/auth_link_row.dart';
import '../widgets/auth_text_field.dart';

/// Reusable email/password signup screen.
///
/// Extracted from `amaan_van_repo/lib/views/auth_views/sign_up_views/sign_up_view.dart`
/// and `firebase_signup_services.dart`.
///
/// Preserved behaviour:
/// * fields: name, email, username, phone, password, confirm password
/// * the same validation rules and messages
/// * the button is only usable after accepting the terms (a message is shown
///   otherwise)
/// * the phone number is mandatory when the phone field is enabled
/// * username uniqueness is checked before creating the account
/// * loading indicator prevents duplicate submissions
///
/// Removed: user-type selection, company-specific fields, `provider`,
/// `flutter_screenutil`, branding, Google/Facebook buttons, the source app's
/// named routes and its post-signup navigation.
class SignupScreen extends StatefulWidget {
  const SignupScreen({
    super.key,
    this.config = const AuthConfig(),
    this.onSignupSuccess,
    this.onNavigateToLogin,
    this.onTermsAndConditions,
    this.onPrivacyPolicy,
    this.onBack,
    this.header,
    this.extraActions = const <Widget>[],
  });

  final AuthConfig config;

  /// Called after a successful signup. When `null` the screen pops.
  ///
  /// Note: Firebase signs the new user in automatically, exactly like the
  /// source application did.
  final ValueChanged<AuthResult>? onSignupSuccess;

  /// Called when the user taps "Sign in". When `null` the screen pops.
  final VoidCallback? onNavigateToLogin;

  /// Called when the user taps the "Terms and Conditions" link.
  final VoidCallback? onTermsAndConditions;

  /// Called when the user taps the "Privacy Policy" link.
  final VoidCallback? onPrivacyPolicy;

  /// Custom back behaviour. When `null` the screen pops.
  final VoidCallback? onBack;

  /// Optional banner shown above the form.
  final Widget? header;

  /// Optional additional buttons (e.g. Google/Facebook) rendered below the
  /// form. When not empty an "or" divider is shown above them.
  final List<Widget> extraActions;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final SignupState _state = SignupState();

  /// Complete (E.164) phone number reported by [IntlPhoneField].
  String _phoneNumber = '';

  late final AuthService _service = widget.config.resolveService();

  AuthMessages get _messages => widget.config.messages;

  @override
  void initState() {
    super.initState();
    _state.setUserType(widget.config.userType);
  }

  @override
  void dispose() {
    _state.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _userNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleBack() {
    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }
    Navigator.of(context).maybePop();
  }

  void _goToLogin() {
    if (widget.onNavigateToLogin != null) {
      widget.onNavigateToLogin!();
      return;
    }
    Navigator.of(context).maybePop();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final AuthConfig config = widget.config;

    if (config.requireTermsAgreement && !_state.agreedToTerms) {
      _showMessage(_messages.acceptTermsRequired, isError: true);
      return;
    }

    if (config.showPhoneField && _phoneNumber.isEmpty) {
      _showMessage(_messages.phoneRequired, isError: true);
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    _state.setLoading(true);

    final String userName = config.showUsernameField
        ? _userNameController.text.trim()
        : '';

    if (config.showUsernameField &&
        userName.isNotEmpty &&
        config.checkUsernameAvailability) {
      final UsernameAvailability availability = await _service
          .isUsernameAvailable(userName);
      if (!mounted) {
        return;
      }
      switch (availability) {
        case UsernameAvailability.taken:
          _state.setLoading(false);
          _showMessage(AuthValidators.usernameTakenMessage, isError: true);
          return;
        case UsernameAvailability.unknown:
          _state.setLoading(false);
          _showMessage(
            AuthValidators.usernameCheckFailedMessage,
            isError: true,
          );
          return;
        case UsernameAvailability.available:
          break;
      }
    }

    final AuthResult result = await _service.signUp(
      SignUpRequest(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: config.showNameField ? _nameController.text.trim() : null,
        userName: userName.isEmpty ? null : userName,
        phoneNumber: config.showPhoneField ? _phoneNumber : null,
        termsAccepted: _state.agreedToTerms,
      ),
    );
    if (!mounted) {
      return;
    }
    _state.setLoading(false);

    if (result.isSuccess) {
      _showMessage(_messages.signupSuccess, isError: false);
      if (widget.onSignupSuccess != null) {
        widget.onSignupSuccess!(result);
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

  Widget _buildPhoneField(BuildContext context) {
    return IntlPhoneField(
      initialCountryCode: widget.config.initialCountryCode,
      decoration: InputDecoration(
        isDense: true,
        labelText: _messages.phoneLabel,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      onChanged: (PhoneNumber value) {
        _phoneNumber = value.completeNumber;
      },
      validator: (PhoneNumber? phone) {
        if (phone == null || phone.number.isEmpty) {
          return AuthValidators.phoneRequiredMessage;
        }
        return null;
      },
    );
  }

  Widget _buildTermsAgreement(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? linkStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.primary,
      decoration: TextDecoration.underline,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ListenableBuilder(
          listenable: _state,
          builder: (context, _) {
            return Checkbox(
              value: _state.agreedToTerms,
              onChanged: (bool? value) =>
                  _state.updateAgreement(value ?? false),
            );
          },
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              children: <Widget>[
                Text(_messages.termsPrefix, style: theme.textTheme.bodyMedium),
                GestureDetector(
                  onTap: widget.onTermsAndConditions,
                  child: Text(_messages.termsLabel, style: linkStyle),
                ),
                Text(_messages.termsJoiner, style: theme.textTheme.bodyMedium),
                GestureDetector(
                  onTap: widget.onPrivacyPolicy,
                  child: Text(_messages.privacyLabel, style: linkStyle),
                ),
                Text(_messages.termsSuffix, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AuthConfig config = widget.config;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _handleBack),
        title: Text(_messages.signUpTitle),
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
                    padding: config.contentPadding,
                    child: AutofillGroup(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Text(
                              _messages.signUpTitle,
                              style: theme.textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 24),
                            if (config.showNameField) ...<Widget>[
                              AuthTextField(
                                controller: _nameController,
                                label: _messages.nameLabel,
                                prefixIcon: const Icon(Icons.person_outline),
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                autofillHints: const <String>[
                                  AutofillHints.name,
                                ],
                                validator: AuthValidators.validateName,
                              ),
                              const SizedBox(height: 16),
                            ],
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
                            if (config.showUsernameField) ...<Widget>[
                              AuthTextField(
                                controller: _userNameController,
                                label: _messages.userNameLabel,
                                prefixIcon: const Icon(Icons.alternate_email),
                                textInputAction: TextInputAction.next,
                                autofillHints: const <String>[
                                  AutofillHints.newUsername,
                                ],
                                validator: AuthValidators.validateUsername,
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (config.showPhoneField) ...<Widget>[
                              _buildPhoneField(context),
                              const SizedBox(height: 16),
                            ],
                            ListenableBuilder(
                              listenable: _state,
                              builder: (context, _) {
                                return AuthTextField(
                                  controller: _passwordController,
                                  label: _messages.passwordLabel,
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  obscureText: _state.isPasswordHidden,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const <String>[
                                    AutofillHints.newPassword,
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
                                        isLogin: false,
                                      ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            ListenableBuilder(
                              listenable: _state,
                              builder: (context, _) {
                                return AuthTextField(
                                  controller: _confirmPasswordController,
                                  label: _messages.confirmPasswordLabel,
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  obscureText: _state.isConfirmPasswordHidden,
                                  textInputAction: TextInputAction.done,
                                  suffixIcon: IconButton(
                                    tooltip: _state.isConfirmPasswordHidden
                                        ? 'Show password'
                                        : 'Hide password',
                                    onPressed:
                                        _state.toggleConfirmPasswordVisibility,
                                    icon: Icon(
                                      _state.isConfirmPasswordHidden
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                  ),
                                  validator: (String? value) =>
                                      AuthValidators.validateConfirmPassword(
                                        value,
                                        _passwordController.text,
                                      ),
                                );
                              },
                            ),
                            if (config.requireTermsAgreement) ...<Widget>[
                              const SizedBox(height: 8),
                              _buildTermsAgreement(context),
                            ],
                            const SizedBox(height: 16),
                            ListenableBuilder(
                              listenable: _state,
                              builder: (context, _) {
                                return AuthButton(
                                  label: _messages.signUpButtonLabel,
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
                              text: _messages.haveAccountText,
                              actionLabel: _messages.switchToSignInLabel,
                              onPressed: _goToLogin,
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
