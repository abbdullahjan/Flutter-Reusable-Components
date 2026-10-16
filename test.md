Flutter changes the approach. Web Push (VAPID, service workers, `web-push`) only works in browsers. A native Flutter app uses **Firebase Cloud Messaging (FCM)**, which delivers to Android through Google and to iOS through Apple's APNs. The server is still needed for payment triggers, but the module changes: instead of `web-push`, the backend uses `firebase-admin`.

## Implementation in this repository

The Flutter test app is implemented in `lib/main.dart` and `lib/services/push_service.dart`. It requests permission, displays and copies the FCM token, logs foreground and notification-tap events, and exposes optional backend register/send actions. You can test delivery without a backend by sending a Firebase Console test message to the copied token.

Run `flutter pub get`, then complete the Firebase setup below. Add the Firebase Android app using application ID `com.abdullah.reusable_flutter_components` and place the downloaded `google-services.json` in `android/app/`. The Android Google Services plugin is applied once that file exists. Without Firebase configuration, the app still opens and reports initialization errors in its event log, but it cannot receive FCM messages.

For the emulator, the backend URL defaults to `http://10.0.2.2:3000`. For a real phone, use the machine's LAN URL when starting Flutter, for example `flutter run --dart-define=PUSH_BASE_URL=http://192.168.1.5:3000`. The app uses `user1` by default; override it with `--dart-define=PUSH_USER_ID=...`. The existing `push notifications/server` folder is the separate web-push implementation; do not replace it to test FCM.

The Android manifest permits cleartext traffic for local backend testing. Use HTTPS and remove that setting before deploying.

The flow:
1. The app gets an **FCM token** and sends it to your backend with the user ID.
2. A payment happens, and your backend calls FCM with that user's token(s).
3. The phone shows the notification, even if the app is closed.

**Platform note for the hackathon:** use **Android**. iOS needs a paid Apple Developer account, an APNs key uploaded to Firebase, and a real device. The same code works on iOS once that's set up.

## 1. Firebase setup (one time)

1. Create a project at console.firebase.google.com.
2. In the Flutter project folder:
```bash
dart pub global activate flutterfire_cli
flutter pub add firebase_core firebase_messaging http
flutterfire configure
```
This registers your app and generates `lib/firebase_options.dart`. The app in this repository uses the native Firebase configuration, so the generated Dart options file is not imported. Check that Android's `google-services.json` landed in `android/app/`; the Google services Gradle plugin is conditionally applied by the Android project.

3. `android/app/src/main/AndroidManifest.xml`: add the permission above `<application>`, and cleartext traffic inside the `<application ...>` tag (needed for plain `http://` to your local backend):
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

<application
    android:usesCleartextTraffic="true"
    ... >
```

## 2. `lib/services/push_service.dart`

```dart
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class PushService {
  // Android emulator -> your PC is 10.0.2.2. Real phone -> your PC's LAN IP, e.g. http://192.168.1.5:3000
  static const baseUrl = 'http://10.0.2.2:3000';
  static const userId = 'user1'; // replace with your logged-in user's id

  static final _fcm = FirebaseMessaging.instance;
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();
  static final token = ValueNotifier<String?>(null);
  static final log = ValueNotifier<List<String>>([]);

  static void _add(String s) => log.value = [s, ...log.value];

  static Future<void> init() async {
    final settings = await _fcm.requestPermission();
    _add('Permission: ${settings.authorizationStatus.name}');

    token.value = await _fcm.getToken();
    debugPrint('FCM TOKEN: ${token.value}');
    _fcm.onTokenRefresh.listen((t) {
      token.value = t;
      register();
    });

    // App open: FCM does not show a system notification, so show it in-app
    FirebaseMessaging.onMessage.listen((m) {
      final n = m.notification;
      _add('Foreground: ${n?.title} - ${n?.body}');
      messengerKey.currentState
          ?.showSnackBar(SnackBar(content: Text('${n?.title}: ${n?.body}')));
    });

    // Tapped while app was in background
    FirebaseMessaging.onMessageOpenedApp
        .listen((m) => _add('Opened from background: ${m.data}'));

    // Tapped while app was terminated
    final initial = await _fcm.getInitialMessage();
    if (initial != null) _add('Opened from terminated: ${initial.data}');
  }

  static Future<void> register() async {
    final t = token.value;
    if (t == null) return;
    try {
      final r = await http.post(
        Uri.parse('$baseUrl/api/push/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId, 'token': t}),
      );
      _add('Register: ${r.statusCode}');
    } catch (e) {
      _add('Register failed: $e');
    }
  }

  static Future<void> sendTest({int delayMs = 0}) async {
    try {
      final r = await http.post(
        Uri.parse('$baseUrl/api/push/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'title': 'Payment received',
          'body': 'You received Rs. 2,500 from Ali',
          'data': {'screen': 'payments'},
          'delay': delayMs,
        }),
      );
      _add('Send: ${r.body}');
    } catch (e) {
      _add('Send failed: $e');
    }
  }
}
```

## 3. lib/main.dart

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/push_service.dart';

// Must be top-level. Notification messages are shown by the system automatically.
@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage m) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_bgHandler);
  await PushService.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        scaffoldMessengerKey: PushService.messengerKey,
        home: const HomePage(),
      );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Push Test')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          ValueListenableBuilder<String?>(
            valueListenable: PushService.token,
            builder: (_, t, __) => Text(
              t == null ? 'Getting token...' : 'Token: ${t.substring(0, 24)}...',
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              final t = PushService.token.value;
              if (t != null) Clipboard.setData(ClipboardData(text: t));
            },
            child: const Text('Copy FCM token'),
          ),
          ElevatedButton(
            onPressed: PushService.register,
            child: const Text('Register with backend'),
          ),
          ElevatedButton(
            onPressed: () => PushService.sendTest(),
            child: const Text('Send test now (via backend)'),
          ),
          ElevatedButton(
            onPressed: () => PushService.sendTest(delayMs: 8000),
            child: const Text('Send in 8s (close the app!)'),
          ),
          const Divider(),
          Expanded(
            child: ValueListenableBuilder<List<String>>(
              valueListenable: PushService.log,
              builder: (_, logs, __) => ListView(
                children: logs.map((l) => Text(l)).toList(),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
```

## 4. Backend (Node), separate from the web-push server

The demo FCM backend is implemented in `push notifications/fcm-server/server.js`. It keeps registered tokens in memory, removes invalid tokens, and supports optional delayed sends. This is for local testing only; use persistent storage and authenticate the endpoints before production.

In Firebase console, go to Project settings > Service accounts > Generate new private key. Save it as `serviceAccountKey.json` in `push notifications/fcm-server/`. This file is ignored by Git; **never commit the service-account key**.

From that folder, install the dependencies and start the server. In PowerShell:
```powershell
npm install
$env:GOOGLE_APPLICATION_CREDENTIALS = (Resolve-Path .\serviceAccountKey.json).Path
npm start
```

The server listens on port 3000 on all interfaces so a real phone on the same Wi-Fi can reach it. The existing `push notifications/server` code remains the separate web-push implementation.

In your actual payment route, you call it the same way as before:
```js
await sendToUser(toUserId, {
  title: 'Payment received',
  body: `You received Rs. ${amount}`,
  data: { screen: 'payments', paymentId: String(payment._id) },
});
```

## 5. Test it

**Fastest test, no backend needed:**
1. Run the app (`flutter run`) and tap **Copy FCM token**.
2. In Firebase console, go to Engage > Messaging > Create campaign > Notification > **Send test message**, paste the token, and send.

**Full flow test:**
1. Start the FCM server as described above.
2. In the app, tap **Register with backend**. The log should show `Register succeeded: HTTP 201`.
3. Tap **Send test notification now** with the app open. You get an in-app snackbar.
4. Tap **Send in 8 seconds**, then press Home or swipe the app away. A real system notification should appear after about 8 seconds.
5. Tap the notification. The log shows it opened from background or terminated, and `m.data` is where you read `screen` to navigate to the payments page.

## If nothing arrives

- **Emulator:** it must be a **Google Play** image, not a plain "Google APIs" one. A real device is the most reliable.
- **Permission:** Android 13+ needs the notification permission. If you denied it, enable it in App info > Notifications.
- **Register fails:** on a real phone, `10.0.2.2` doesn't work. Use your PC's LAN IP, and check the firewall allows port 3000.
- **Swiped away on some phones:** Xiaomi, Oppo, Vivo and Huawei aggressively kill background apps, so allow autostart and disable battery optimization for your app when demoing.
- **`sent: 0, failed: 1`:** check the terminal for the FCM error code. `registration-token-not-registered` means a stale token, so reinstall the app and register again.

Next, replace the in-memory `Map` with MongoDB (`{ userId, token }` documents with a unique index on `token`) and swap the hard-coded `userId` for your logged-in user's ID. If your backend isn't Node (Django, Spring, Firebase Functions), tell me and I'll port the sender part.