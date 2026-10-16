// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reusable_flutter_components/main.dart';

void main() {
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
