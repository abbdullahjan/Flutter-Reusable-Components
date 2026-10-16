import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class PushService {
  PushService._();

  static const baseUrl = String.fromEnvironment(
    'PUSH_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );
  static const userId = String.fromEnvironment(
    'PUSH_USER_ID',
    defaultValue: 'user1',
  );

  static final messengerKey = GlobalKey<ScaffoldMessengerState>();
  static final token = ValueNotifier<String?>(null);
  static final status = ValueNotifier<String>('Initializing Firebase...');
  static final log = ValueNotifier<List<String>>([]);

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static bool _initialized = false;

  static void _add(String message) {
    log.value = [message, ...log.value].take(50).toList();
    debugPrint(message);
  }

  static void reportInitializationError(Object error) {
    status.value = 'Firebase initialization failed';
    _add('Firebase initialization failed: $error');
  }

  static Future<void> initialize() async {
    if (_initialized) return;

    final settings = await _messaging.requestPermission();
    _add('Notification permission: ${settings.authorizationStatus.name}');
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    token.value = await _messaging.getToken();
    status.value = token.value == null
        ? 'Firebase is ready, but no FCM token was returned'
        : 'Ready to receive push notifications';
    _add(token.value == null ? 'FCM token unavailable' : 'FCM token ready');

    _messaging.onTokenRefresh.listen((newToken) {
      token.value = newToken;
      _add('FCM token refreshed');
      unawaited(register());
    }, onError: (Object error) => _add('FCM token refresh failed: $error'));

    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      final title = notification?.title ?? 'Push notification';
      final body = notification?.body ?? message.data.toString();
      _add('Foreground: $title - $body');
      messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('$title: $body')),
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _add('Opened from background: ${message.data}');
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _add('Opened from terminated: ${initialMessage.data}');
    }

    _initialized = true;
  }

  static Future<void> register() async {
    final currentToken = token.value;
    if (currentToken == null) {
      _add('Register failed: FCM token is not available');
      return;
    }

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/push/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId, 'token': currentToken}),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _add('Register failed: HTTP ${response.statusCode} ${response.body}');
        return;
      }
      _add('Register succeeded: HTTP ${response.statusCode} ${response.body}');
    } catch (error) {
      _add('Register failed: $error');
    }
  }

  static Future<void> sendTest({int delayMs = 0}) async {
    if (delayMs < 0) {
      _add('Send failed: delay must not be negative');
      return;
    }

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/push/send'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'title': 'Payment received',
              'body': 'You received Rs. 2,500 from Ali',
              'data': {'screen': 'payments'},
              'delay': delayMs,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _add('Send failed: HTTP ${response.statusCode} ${response.body}');
        return;
      }
      _add('Send succeeded: HTTP ${response.statusCode} ${response.body}');
    } catch (error) {
      _add('Send failed: $error');
    }
  }
}
