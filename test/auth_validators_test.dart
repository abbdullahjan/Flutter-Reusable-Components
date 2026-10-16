import 'package:flutter_test/flutter_test.dart';
import 'package:reusable_flutter_components/core/auth/auth.dart';

void main() {
  group('AuthValidators.validateEmail', () {
    test('returns an error for an empty value', () {
      expect(
        AuthValidators.validateEmail(''),
        AuthValidators.emailRequiredMessage,
      );
      expect(
        AuthValidators.validateEmail(null),
        AuthValidators.emailRequiredMessage,
      );
    });

    test('returns an error for a malformed address', () {
      expect(
        AuthValidators.validateEmail('not-an-email'),
        AuthValidators.invalidEmailMessage,
      );
      expect(
        AuthValidators.validateEmail('user@example'),
        AuthValidators.invalidEmailMessage,
      );
    });

    test('accepts a valid address', () {
      expect(AuthValidators.validateEmail('user@example.com'), isNull);
      expect(AuthValidators.validateEmail('  user@example.com  '), isNull);
    });
  });

  group('AuthValidators.validatePassword', () {
    test('login only requires a non-empty password', () {
      expect(
        AuthValidators.validatePassword('', isLogin: true),
        AuthValidators.passwordRequiredMessage,
      );
      expect(AuthValidators.validatePassword('123', isLogin: true), isNull);
    });

    test('signup requires at least six characters', () {
      expect(
        AuthValidators.validatePassword('', isLogin: false),
        AuthValidators.passwordRequiredMessage,
      );
      expect(
        AuthValidators.validatePassword('12345', isLogin: false),
        AuthValidators.passwordTooShortMessage,
      );
      expect(AuthValidators.validatePassword('123456', isLogin: false), isNull);
    });
  });

  group('AuthValidators.validateConfirmPassword', () {
    test('reports empty and mismatching values', () {
      expect(
        AuthValidators.validateConfirmPassword('', 'secret1'),
        AuthValidators.passwordRequiredMessage,
      );
      expect(
        AuthValidators.validateConfirmPassword('secret2', 'secret1'),
        AuthValidators.passwordMismatchMessage,
      );
      expect(
        AuthValidators.validateConfirmPassword('secret1', 'secret1'),
        isNull,
      );
    });
  });

  group('AuthValidators.validateName', () {
    test('applies the source application rules', () {
      expect(
        AuthValidators.validateName(''),
        AuthValidators.nameRequiredMessage,
      );
      expect(
        AuthValidators.validateName('Jo'),
        AuthValidators.nameTooShortMessage,
      );
      expect(
        AuthValidators.validateName('John123'),
        AuthValidators.nameInvalidMessage,
      );
      expect(AuthValidators.validateName('John Doe'), isNull);
    });
  });

  group('AuthValidators.validateUsername', () {
    test('applies the source application rules', () {
      expect(
        AuthValidators.validateUsername(''),
        AuthValidators.usernameRequiredMessage,
      );
      expect(
        AuthValidators.validateUsername('abc'),
        AuthValidators.usernameTooShortMessage,
      );
      expect(
        AuthValidators.validateUsername('ab cd'),
        AuthValidators.usernameSpaceMessage,
      );
      expect(
        AuthValidators.validateUsername('user@name'),
        AuthValidators.usernameInvalidMessage,
      );
      expect(AuthValidators.validateUsername('john_doe-1'), isNull);
    });
  });

  group('AuthValidators.validatePhone', () {
    test('accepts E.164 numbers only', () {
      expect(
        AuthValidators.validatePhone(''),
        AuthValidators.phoneRequiredMessage,
      );
      expect(
        AuthValidators.validatePhone('123456'),
        AuthValidators.invalidPhoneMessage,
      );
      expect(AuthValidators.validatePhone('+923001234567'), isNull);
    });
  });
}
