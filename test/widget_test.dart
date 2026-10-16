// Smoke tests for the minimal demo host application in `lib/main.dart`.
//
// The original counter test was replaced together with the counter demo that
// used to live in `main.dart`. The demo app now exposes the extracted auth
// module, which is what these tests verify.

import 'package:flutter_test/flutter_test.dart';
import 'package:reusable_flutter_components/core/auth/auth.dart';
import 'package:reusable_flutter_components/main.dart';

void main() {
  testWidgets('demo app shows entry points to the auth module', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Open login screen'), findsOneWidget);
    expect(find.text('Open signup screen'), findsOneWidget);
  });

  testWidgets('demo app opens the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('Open login screen'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('demo app opens the signup screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('Open signup screen'));
    await tester.pumpAndSettle();

    expect(find.byType(SignupScreen), findsOneWidget);
  });
}
