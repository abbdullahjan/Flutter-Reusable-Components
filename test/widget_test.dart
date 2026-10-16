// Smoke tests for the demo host application in `lib/main.dart`.
//
// The demo app exposes both the extracted auth module and the push
// notification test screen, so these tests cover the entry points and the
// visible push-notification actions of the merged demo.

import 'package:flutter/material.dart';
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

  testWidgets('push test screen exposes token and message actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Push Notification Test'), findsOneWidget);
    expect(find.text('FCM device token'), findsOneWidget);
    expect(find.text('Copy FCM token'), findsOneWidget);
    expect(find.text('Register with backend'), findsOneWidget);
    expect(find.text('Send test notification now'), findsOneWidget);
    expect(find.text('No events yet.'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });
}
