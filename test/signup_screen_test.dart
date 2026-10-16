import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reusable_flutter_components/core/auth/auth.dart';

import 'helpers/fake_auth_service.dart';

void main() {
  Future<void> pumpSignupScreen(
    WidgetTester tester, {
    required FakeAuthService service,
    bool showPhoneField = false,
    bool requireTermsAgreement = true,
    bool checkUsernameAvailability = true,
    ValueChanged<AuthResult>? onSignupSuccess,
    VoidCallback? onNavigateToLogin,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SignupScreen(
          config: AuthConfig(
            service: service,
            showPhoneField: showPhoneField,
            requireTermsAgreement: requireTermsAgreement,
            checkUsernameAvailability: checkUsernameAvailability,
          ),
          onSignupSuccess: onSignupSuccess,
          onNavigateToLogin: onNavigateToLogin,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Fills the name/email/username/password/confirm fields. Only valid while
  /// the phone field is disabled.
  Future<void> fillSignupForm(
    WidgetTester tester, {
    String name = 'John Doe',
    String email = 'new@example.com',
    String userName = 'john_doe',
    String password = '123456',
    String? confirmPassword,
  }) async {
    final Finder fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), name);
    await tester.enterText(fields.at(1), email);
    await tester.enterText(fields.at(2), userName);
    await tester.enterText(fields.at(3), password);
    await tester.enterText(fields.at(4), confirmPassword ?? password);
    await tester.pump();
  }

  Future<void> acceptTerms(WidgetTester tester) async {
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
  }

  Future<void> tapSubmit(WidgetTester tester) async {
    final Finder button = find.byType(AuthButton);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('renders every signup field', (WidgetTester tester) async {
    await pumpSignupScreen(tester, service: FakeAuthService());

    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('User name'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
    expect(find.byType(AuthButton), findsOneWidget);
  });

  testWidgets('renders the phone field when enabled', (
    WidgetTester tester,
  ) async {
    await pumpSignupScreen(
      tester,
      service: FakeAuthService(),
      showPhoneField: true,
    );

    expect(find.text('Phone Number'), findsOneWidget);
  });

  testWidgets('reports a password mismatch', (WidgetTester tester) async {
    final FakeAuthService service = FakeAuthService();
    await pumpSignupScreen(tester, service: service);

    await fillSignupForm(tester, confirmPassword: '654321');
    await acceptTerms(tester);
    await tapSubmit(tester);

    expect(find.text(AuthValidators.passwordMismatchMessage), findsOneWidget);
    expect(service.signUpCalls, 0);
  });

  testWidgets('requires accepting the terms before signup', (
    WidgetTester tester,
  ) async {
    final FakeAuthService service = FakeAuthService();
    await pumpSignupScreen(tester, service: service);

    await fillSignupForm(tester);
    await tapSubmit(tester);

    expect(
      find.text('You must agree to the Terms and Privacy Policy.'),
      findsOneWidget,
    );
    expect(service.signUpCalls, 0);
  });

  testWidgets('reports a taken username', (WidgetTester tester) async {
    final FakeAuthService service = FakeAuthService(
      usernameAvailability: UsernameAvailability.taken,
    );
    await pumpSignupScreen(tester, service: service);

    await fillSignupForm(tester);
    await acceptTerms(tester);
    await tapSubmit(tester);

    expect(find.text(AuthValidators.usernameTakenMessage), findsOneWidget);
    expect(service.usernameAvailabilityCalls, 1);
    expect(service.signUpCalls, 0);
  });

  testWidgets('asks the user to retry when the username check fails', (
    WidgetTester tester,
  ) async {
    final FakeAuthService service = FakeAuthService(
      usernameAvailability: UsernameAvailability.unknown,
    );
    await pumpSignupScreen(tester, service: service);

    await fillSignupForm(tester);
    await acceptTerms(tester);
    await tapSubmit(tester);

    expect(
      find.text(AuthValidators.usernameCheckFailedMessage),
      findsOneWidget,
    );
    expect(find.text(AuthValidators.usernameTakenMessage), findsNothing);
    expect(service.usernameAvailabilityCalls, 1);
    expect(service.signUpCalls, 0);
  });

  testWidgets('skips the username check when it is disabled', (
    WidgetTester tester,
  ) async {
    final FakeAuthService service = FakeAuthService(
      usernameAvailability: UsernameAvailability.taken,
    );
    await pumpSignupScreen(
      tester,
      service: service,
      checkUsernameAvailability: false,
    );

    await fillSignupForm(tester);
    await acceptTerms(tester);
    await tapSubmit(tester);

    expect(service.usernameAvailabilityCalls, 0);
    expect(service.signUpCalls, 1);
    expect(find.text(AuthValidators.usernameTakenMessage), findsNothing);
    expect(find.text(AuthValidators.usernameCheckFailedMessage), findsNothing);
  });

  testWidgets('creates the account and calls onSignupSuccess', (
    WidgetTester tester,
  ) async {
    final FakeAuthService service = FakeAuthService();
    AuthResult? received;
    await pumpSignupScreen(
      tester,
      service: service,
      onSignupSuccess: (AuthResult result) => received = result,
    );

    await fillSignupForm(tester);
    await acceptTerms(tester);
    await tapSubmit(tester);

    expect(service.usernameAvailabilityCalls, 1);
    expect(find.text(AuthValidators.usernameTakenMessage), findsNothing);
    expect(find.text(AuthValidators.usernameCheckFailedMessage), findsNothing);
    expect(service.signUpCalls, 1);
    expect(received, isNotNull);
    expect(received!.isSuccess, isTrue);
    expect(received!.user?.email, 'new@example.com');
    expect(find.text('Signup Successful!'), findsOneWidget);

    final SignUpRequest request = service.lastSignUpRequest!;
    expect(request.email, 'new@example.com');
    expect(request.password, '123456');
    expect(request.fullName, 'John Doe');
    expect(request.userName, 'john_doe');
    expect(request.phoneNumber, isNull);
    expect(request.termsAccepted, isTrue);
  });

  testWidgets('requires a phone number when the phone field is enabled', (
    WidgetTester tester,
  ) async {
    final FakeAuthService service = FakeAuthService();
    await pumpSignupScreen(
      tester,
      service: service,
      showPhoneField: true,
      requireTermsAgreement: false,
    );

    await tapSubmit(tester);

    expect(find.text('Phone number required!'), findsOneWidget);
    expect(service.signUpCalls, 0);
  });

  testWidgets('toggles confirm-password visibility', (
    WidgetTester tester,
  ) async {
    await pumpSignupScreen(tester, service: FakeAuthService());

    final Finder confirmField = find.byType(TextFormField).at(4);
    EditableText editableText() => tester.widget<EditableText>(
      find.descendant(of: confirmField, matching: find.byType(EditableText)),
    );

    expect(editableText().obscureText, isTrue);

    await tester.tap(find.byIcon(Icons.visibility_off).last);
    await tester.pump();

    expect(editableText().obscureText, isFalse);
  });

  testWidgets('uses the host navigation callback for the login link', (
    WidgetTester tester,
  ) async {
    bool opened = false;
    await pumpSignupScreen(
      tester,
      service: FakeAuthService(),
      onNavigateToLogin: () => opened = true,
    );

    final Finder loginAction = find.descendant(
      of: find.byType(AuthLinkRow),
      matching: find.text('Sign in'),
    );
    await tester.ensureVisible(loginAction);
    await tester.tap(loginAction);
    await tester.pumpAndSettle();

    expect(opened, isTrue);
  });
}
