import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reusable_flutter_components/core/auth/auth.dart';

import 'helpers/fake_auth_service.dart';

void main() {
  Future<void> pumpForgotPasswordScreen(
    WidgetTester tester, {
    required FakeAuthService service,
    VoidCallback? onPasswordResetSent,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ForgotPasswordScreen(
          config: AuthConfig(service: service),
          onPasswordResetSent: onPasswordResetSent,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('validates the email before sending', (
    WidgetTester tester,
  ) async {
    final FakeAuthService service = FakeAuthService();
    await pumpForgotPasswordScreen(tester, service: service);

    await tester.tap(find.byType(AuthButton));
    await tester.pumpAndSettle();

    expect(find.text(AuthValidators.emailRequiredMessage), findsOneWidget);
    expect(service.passwordResetCalls, 0);
  });

  testWidgets('sends the reset email and reports success', (
    WidgetTester tester,
  ) async {
    final FakeAuthService service = FakeAuthService();
    bool callbackCalled = false;
    await pumpForgotPasswordScreen(
      tester,
      service: service,
      onPasswordResetSent: () => callbackCalled = true,
    );

    await tester.enterText(find.byType(TextFormField), 'user@example.com');
    await tester.tap(find.byType(AuthButton));
    await tester.pumpAndSettle();

    expect(service.passwordResetCalls, 1);
    expect(service.lastResetEmail, 'user@example.com');
    expect(callbackCalled, isTrue);
    expect(find.text('Password reset email sent.'), findsOneWidget);
  });

  testWidgets('shows the error message when the reset fails', (
    WidgetTester tester,
  ) async {
    final FakeAuthService service = FakeAuthService(
      passwordResetResult: const AuthResult.failure('Invalid Credentials.'),
    );
    await pumpForgotPasswordScreen(tester, service: service);

    await tester.enterText(find.byType(TextFormField), 'user@example.com');
    await tester.tap(find.byType(AuthButton));
    await tester.pumpAndSettle();

    expect(find.text('Invalid Credentials.'), findsOneWidget);
  });
}
