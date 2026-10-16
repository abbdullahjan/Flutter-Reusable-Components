import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reusable_flutter_components/core/auth/auth.dart';

import 'helpers/fake_auth_service.dart';

void main() {
  Future<void> pumpLoginScreen(
    WidgetTester tester, {
    required FakeAuthService service,
    ValueChanged<AuthResult>? onLoginSuccess,
    VoidCallback? onNavigateToSignup,
    bool enableForgotPassword = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          config: AuthConfig(
            service: service,
            enableForgotPassword: enableForgotPassword,
          ),
          onLoginSuccess: onLoginSuccess,
          onNavigateToSignup: onNavigateToSignup,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fillCredentials(
    WidgetTester tester, {
    String email = 'user@example.com',
    String password = 'secret1',
  }) async {
    await tester.enterText(find.byType(TextFormField).at(0), email);
    await tester.enterText(find.byType(TextFormField).at(1), password);
    await tester.pump();
  }

  Future<void> tapSubmit(WidgetTester tester) async {
    final Finder button = find.byType(AuthButton);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('renders the login form', (WidgetTester tester) async {
    await pumpLoginScreen(tester, service: FakeAuthService());

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.byType(AuthButton), findsOneWidget);
  });

  testWidgets('validates empty fields and never calls the service', (
    WidgetTester tester,
  ) async {
    final FakeAuthService service = FakeAuthService();
    await pumpLoginScreen(tester, service: service);

    await tapSubmit(tester);

    expect(find.text(AuthValidators.emailRequiredMessage), findsOneWidget);
    expect(find.text(AuthValidators.passwordRequiredMessage), findsOneWidget);
    expect(service.signInCalls, 0);
  });

  testWidgets('shows the service error message on failed login', (
    WidgetTester tester,
  ) async {
    final FakeAuthService service = FakeAuthService(
      signInResult: const AuthResult.failure('Invalid Credentials.'),
    );
    await pumpLoginScreen(tester, service: service);

    await fillCredentials(tester, password: 'wrong-password');
    await tapSubmit(tester);

    expect(find.text('Invalid Credentials.'), findsOneWidget);
    expect(service.signInCalls, 1);
    expect(service.lastEmail, 'user@example.com');
    expect(service.lastPassword, 'wrong-password');
  });

  testWidgets('invokes onLoginSuccess after a successful login', (
    WidgetTester tester,
  ) async {
    final FakeAuthService service = FakeAuthService();
    AuthResult? received;
    await pumpLoginScreen(
      tester,
      service: service,
      onLoginSuccess: (AuthResult result) => received = result,
    );

    await fillCredentials(tester);
    await tapSubmit(tester);

    expect(service.signInCalls, 1);
    expect(received, isNotNull);
    expect(received!.isSuccess, isTrue);
    expect(received!.user?.email, 'user@example.com');
    expect(find.text('Login successful'), findsOneWidget);
  });

  testWidgets('toggles password visibility', (WidgetTester tester) async {
    await pumpLoginScreen(tester, service: FakeAuthService());

    final Finder passwordField = find.byType(TextFormField).at(1);
    EditableText editableText() => tester.widget<EditableText>(
      find.descendant(of: passwordField, matching: find.byType(EditableText)),
    );

    expect(editableText().obscureText, isTrue);

    await tester.tap(find.byIcon(Icons.visibility_off));
    await tester.pump();

    expect(editableText().obscureText, isFalse);
    expect(find.byIcon(Icons.visibility), findsOneWidget);
  });

  testWidgets('prevents duplicate submissions while loading', (
    WidgetTester tester,
  ) async {
    final FakeAuthService service = FakeAuthService(
      delay: const Duration(milliseconds: 100),
    );
    await pumpLoginScreen(tester, service: service);

    await fillCredentials(tester);
    final Finder button = find.byType(AuthButton);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    await tester.tap(button, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(service.signInCalls, 1);
  });

  testWidgets('opens the module signup screen when no callback is provided', (
    WidgetTester tester,
  ) async {
    await pumpLoginScreen(tester, service: FakeAuthService());

    final Finder signupAction = find.descendant(
      of: find.byType(AuthLinkRow),
      matching: find.text('Signup'),
    );
    await tester.ensureVisible(signupAction);
    await tester.tap(signupAction);
    await tester.pumpAndSettle();

    expect(find.byType(SignupScreen), findsOneWidget);
  });

  testWidgets('uses the host navigation callback when provided', (
    WidgetTester tester,
  ) async {
    bool opened = false;
    await pumpLoginScreen(
      tester,
      service: FakeAuthService(),
      onNavigateToSignup: () => opened = true,
    );

    final Finder signupAction = find.descendant(
      of: find.byType(AuthLinkRow),
      matching: find.text('Signup'),
    );
    await tester.ensureVisible(signupAction);
    await tester.tap(signupAction);
    await tester.pumpAndSettle();

    expect(opened, isTrue);
    expect(find.byType(SignupScreen), findsNothing);
  });
}
