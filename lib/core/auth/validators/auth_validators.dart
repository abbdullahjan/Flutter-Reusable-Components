/// Form validation rules extracted from `amaan_van_repo/lib/utils/validations.dart`.
///
/// The regexes and error messages are intentionally kept identical to the
/// source application so the extracted screens behave the same way. Only the
/// email/password/name/username/phone rules used by the login and signup flows
/// were extracted; company/license/dropdown validators belong to
/// application-specific features and were left behind.
class AuthValidators {
  AuthValidators._();

  static const String emailRequiredMessage = '🚩 Email is required';
  static const String invalidEmailMessage = '🚩 Invalid email address.';
  static const String passwordRequiredMessage = "🚩 Password can't be empty";
  static const String passwordTooShortMessage =
      '🚩 Password should be six characters.';
  static const String passwordMismatchMessage = '🚩 Password do not match.';
  static const String nameRequiredMessage = "🚩 Name can't be empty.";
  static const String nameTooShortMessage = '🚩 Name is too short.';
  static const String nameInvalidMessage =
      '🚩 Name can only contain letters and spaces.';
  static const String usernameRequiredMessage = "🚩 Username can't be empty";
  static const String usernameTooShortMessage =
      '🚩 Username must be at least 4 characters';
  static const String usernameSpaceMessage =
      '🚩 Username cannot contain spaces';
  static const String usernameInvalidMessage =
      '🚩 Only letters, numbers, and underscores allowed.';
  static const String usernameTakenMessage = '🚩 Username is already taken';
  static const String usernameCheckFailedMessage =
      '🚩 Could not verify username. Please try again.';
  static const String phoneRequiredMessage = "🚩 Phone can't be empty";
  static const String invalidPhoneMessage = '🚩 Invalid phone number format';

  static final RegExp _emailPattern = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
  static final RegExp _phonePattern = RegExp(r'^\+\d{1,3}\d{7,15}$');
  static final RegExp _usernamePattern = RegExp(r'^[a-zA-Z0-9-_]+$');
  static final RegExp _nameInvalidPattern = RegExp(r'[^a-zA-Z\s]');

  /// Email validation used by both the login and the signup screens.
  static String? validateEmail(String? value) {
    final String email = value?.trim() ?? '';
    if (email.isEmpty) {
      return emailRequiredMessage;
    }
    if (!_emailPattern.hasMatch(email)) {
      return invalidEmailMessage;
    }
    return null;
  }

  /// Password validation.
  ///
  /// Login only requires a non-empty password; signup additionally requires at
  /// least six characters (same rule as the source application).
  static String? validatePassword(String? value, {required bool isLogin}) {
    final String password = value ?? '';
    if (password.isEmpty) {
      return passwordRequiredMessage;
    }
    if (!isLogin && password.length < 6) {
      return passwordTooShortMessage;
    }
    return null;
  }

  /// Confirm-password validation for the signup screen.
  static String? validateConfirmPassword(String? value, String password) {
    final String confirmPassword = value ?? '';
    if (confirmPassword.isEmpty) {
      return passwordRequiredMessage;
    }
    if (confirmPassword != password) {
      return passwordMismatchMessage;
    }
    return null;
  }

  /// Full-name validation (signup).
  static String? validateName(String? value) {
    final String name = value?.trim() ?? '';
    if (name.isEmpty) {
      return nameRequiredMessage;
    }
    if (name.length < 3) {
      return nameTooShortMessage;
    }
    if (_nameInvalidPattern.hasMatch(name)) {
      return nameInvalidMessage;
    }
    return null;
  }

  /// Username format validation (signup).
  ///
  /// Availability ("username is already taken") is checked asynchronously
  /// through [AuthService.isUsernameAvailable] and is not handled here.
  static String? validateUsername(String? value) {
    final String username = value?.trim() ?? '';
    if (username.isEmpty) {
      return usernameRequiredMessage;
    }
    if (username.length < 4) {
      return usernameTooShortMessage;
    }
    if (username.contains(' ')) {
      return usernameSpaceMessage;
    }
    if (!_usernamePattern.hasMatch(username)) {
      return usernameInvalidMessage;
    }
    return null;
  }

  /// E.164 phone validation used when the signup phone field is enabled.
  static String? validatePhone(String? value) {
    final String phone = value?.trim() ?? '';
    if (phone.isEmpty) {
      return phoneRequiredMessage;
    }
    if (!_phonePattern.hasMatch(phone)) {
      return invalidPhoneMessage;
    }
    return null;
  }
}
