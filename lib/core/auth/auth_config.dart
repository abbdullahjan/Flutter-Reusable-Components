import 'package:flutter/widgets.dart';

import 'services/auth_service.dart';

/// Every visible string of the authentication screens.
///
/// Defaults match the English strings used by `amaan_van_repo`. A host
/// application can override any label (or localise the whole module) by
/// passing its own [AuthMessages] instance to [AuthConfig].
class AuthMessages {
  const AuthMessages({
    this.signInTitle = 'Sign in',
    this.signUpTitle = 'Signup',
    this.emailLabel = 'Email',
    this.passwordLabel = 'Password',
    this.confirmPasswordLabel = 'Confirm password',
    this.nameLabel = 'Name',
    this.userNameLabel = 'User name',
    this.phoneLabel = 'Phone Number',
    this.forgotPasswordLabel = 'Forgot Password?',
    this.forgotPasswordTitle = 'Forgot Password',
    this.forgotPasswordDescription =
        'Enter your email to receive a password reset link.',
    this.forgotPasswordButtonLabel = 'Send reset link',
    this.orLabel = 'or',
    this.signInButtonLabel = 'Sign in',
    this.signUpButtonLabel = 'Signup',
    this.noAccountText = "Don't have an account?",
    this.haveAccountText = 'Already have an account?',
    this.switchToSignUpLabel = 'Signup',
    this.switchToSignInLabel = 'Sign in',
    this.termsPrefix = 'I agree to the ',
    this.termsLabel = 'Terms and Conditions',
    this.termsJoiner = ' and ',
    this.privacyLabel = 'Privacy Policy',
    this.termsSuffix = '.',
    this.loginSuccess = 'Login successful',
    this.signupSuccess = 'Signup Successful!',
    this.passwordResetSent = 'Password reset email sent.',
    this.phoneRequired = 'Phone number required!',
    this.acceptTermsRequired =
        'You must agree to the Terms and Privacy Policy.',
  });

  final String signInTitle;
  final String signUpTitle;
  final String emailLabel;
  final String passwordLabel;
  final String confirmPasswordLabel;
  final String nameLabel;
  final String userNameLabel;
  final String phoneLabel;
  final String forgotPasswordLabel;
  final String forgotPasswordTitle;
  final String forgotPasswordDescription;
  final String forgotPasswordButtonLabel;
  final String orLabel;
  final String signInButtonLabel;
  final String signUpButtonLabel;
  final String noAccountText;
  final String haveAccountText;
  final String switchToSignUpLabel;
  final String switchToSignInLabel;
  final String termsPrefix;
  final String termsLabel;
  final String termsJoiner;
  final String privacyLabel;
  final String termsSuffix;
  final String loginSuccess;
  final String signupSuccess;
  final String passwordResetSent;
  final String phoneRequired;
  final String acceptTermsRequired;
}

/// Configuration shared by the login, signup and forgot-password screens.
///
/// The module is intentionally theme-independent: no colors, fonts, logos or
/// navigation routes are hardcoded. Everything a host application may want to
/// change lives here (labels, which fields are shown) or is exposed as a
/// callback on the screens.
///
/// This class is Firebase-independent: the backend is selected explicitly by
/// injecting an [AuthService] through [service]. The Firebase implementation
/// lives in `services/flutter_firebase_auth/firebase_auth_service.dart` and is
/// opted into through
/// `package:reusable_flutter_components/services/flutter_firebase_auth/firebase.dart`.
class AuthConfig {
  const AuthConfig({
    this.service,
    this.messages = const AuthMessages(),
    this.showNameField = true,
    this.showUsernameField = true,
    this.showPhoneField = true,
    this.requireTermsAgreement = true,
    this.enableForgotPassword = true,
    this.checkUsernameAvailability = true,
    this.userType,
    this.initialCountryCode = 'US',
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 20,
      vertical: 16,
    ),
    this.headerHeightFactor = 0.22,
    this.logo,
  });

  /// Authentication backend. The host **must** provide one; [resolveService]
  /// returns it or throws a [StateError].
  ///
  /// Use `FirebaseAuthService` (from
  /// `services/flutter_firebase_auth/firebase.dart`) for Firebase,
  /// `RestAuthService` (from `auth.dart`) for a REST backend, or any custom /
  /// fake `AuthService` (e.g. in tests).
  final AuthService? service;

  final AuthMessages messages;

  /// Signup form composition.
  final bool showNameField;
  final bool showUsernameField;
  final bool showPhoneField;

  /// When `true` the signup button stays disabled until the user accepts the
  /// terms and privacy policy (same behaviour as the source application).
  final bool requireTermsAgreement;

  /// Shows the "Forgot Password?" link on the login screen.
  final bool enableForgotPassword;

  /// When `true` the signup screen calls [AuthService.isUsernameAvailable]
  /// before creating the account.
  final bool checkUsernameAvailability;

  /// Stored on `SignupState` and written to the backend profile document by
  /// `FirebaseAuthService.userType`.
  final int? userType;

  /// Initial country shown by the phone field (E.164 output).
  final String initialCountryCode;

  final EdgeInsets contentPadding;

  /// Height of the optional decorative [AuthHeader] relative to the screen.
  final double headerHeightFactor;

  /// Optional logo shown inside the header banner.
  final Widget? logo;

  /// Whether the host application supplied its own [AuthService].
  bool get hasCustomService => service != null;

  /// Returns the injected [service].
  ///
  /// The backend is chosen explicitly: there is no implicit Firebase default.
  /// Throws a [StateError] when no service was provided, so a misconfigured
  /// host fails fast with a clear message instead of silently using the wrong
  /// backend. Evaluated lazily by the screens, so constructing a screen never
  /// requires a backend to be ready.
  AuthService resolveService() {
    final AuthService? injected = service;
    if (injected == null) {
      throw StateError(
        'AuthConfig.service is null. Authentication backends must be injected '
        'explicitly, for example AuthConfig(service: FirebaseAuthService()) '
        'with `import services/flutter_firebase_auth/firebase.dart`, or '
        'AuthConfig(service: RestAuthService(...)) from `core/auth/auth.dart`.',
      );
    }
    return injected;
  }
}
