import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/auth/auth.dart';
import 'services/flutter_firebase_auth/firebase.dart';
import 'services/push_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

/// Minimal demonstration host application for the reusable authentication
/// module and the push-notification service. It shows how a real app opens the
/// login/signup screens, reacts to successful authentication and exercises FCM.
/// The module itself never imports this file.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await PushService.initialize();
  } catch (error) {
    // The demo still runs without Firebase configuration; push and
    // authentication attempts then report a failure instead of crashing.
    PushService.reportInitializationError(error);
    debugPrint('Firebase is not configured for this demo app: $error');
  }

  runApp(const MyApp());
}

/// The backend is injected explicitly: the module has no implicit Firebase
/// default. `FirebaseAuthService` only touches Firebase inside its methods, so
/// building this config never requires `Firebase.initializeApp`.
final AuthConfig _demoConfig = AuthConfig(
  service: FirebaseAuthService(),
  messages: const AuthMessages(
    signInTitle: 'Welcome back',
    signUpTitle: 'Create your account',
    signInButtonLabel: 'Sign in',
    signUpButtonLabel: 'Create account',
  ),
  logo: const Icon(Icons.lock_outline),
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reusable Auth Demo',
      scaffoldMessengerKey: PushService.messengerKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const DemoHomeScreen(),
    );
  }
}

class DemoHomeScreen extends StatelessWidget {
  const DemoHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Push Notification Test')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Reusable authentication',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _openLogin(context),
                        icon: const Icon(Icons.login),
                        label: const Text('Open login screen'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _openSignup(context),
                        icon: const Icon(Icons.person_add_alt),
                        label: const Text('Open signup screen'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'FCM device token',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ValueListenableBuilder<String?>(
                        valueListenable: PushService.token,
                        builder: (context, token, _) => SelectableText(
                          token ?? 'Waiting for Firebase setup...',
                          maxLines: token == null ? 2 : 4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ValueListenableBuilder<String?>(
                        valueListenable: PushService.token,
                        builder: (context, token, _) => FilledButton.icon(
                          onPressed: token == null
                              ? null
                              : () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: token),
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('FCM token copied'),
                                      ),
                                    );
                                  }
                                },
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy FCM token'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ValueListenableBuilder<String>(
                valueListenable: PushService.status,
                builder: (context, status, _) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Status'),
                  subtitle: Text(status),
                ),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<String?>(
                valueListenable: PushService.token,
                builder: (context, token, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    OutlinedButton(
                      onPressed: token == null ? null : PushService.register,
                      child: const Text('Register with backend'),
                    ),
                    OutlinedButton(
                      onPressed: token == null
                          ? null
                          : () => PushService.sendTest(),
                      child: const Text('Send test notification now'),
                    ),
                    OutlinedButton(
                      onPressed: token == null
                          ? null
                          : () => PushService.sendTest(delayMs: 8000),
                      child: const Text('Send in 8 seconds (background test)'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('Event log', style: theme.textTheme.titleMedium),
              const Divider(),
              ValueListenableBuilder<List<String>>(
                valueListenable: PushService.log,
                builder: (context, entries, _) {
                  if (entries.isEmpty) {
                    return const Text('No events yet.');
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: entries
                        .map(
                          (entry) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(entry),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openLogin(BuildContext context) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AuthResult? result = await Navigator.of(context).push<AuthResult>(
      MaterialPageRoute<AuthResult>(
        builder: (routeContext) => LoginScreen(
          config: _demoConfig,
          header: const AuthHeader(
            label: 'Sign in',
            logo: Icon(Icons.lock_outline),
            heightFactor: 0.2,
          ),
          // The host application decides what happens after a successful
          // login: here the screen is popped with the result.
          onLoginSuccess: (AuthResult result) =>
              Navigator.of(routeContext).pop(result),
        ),
      ),
    );

    if (result == null || !result.isSuccess) {
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Signed in as ${result.user?.email ?? result.user?.uid}',
          ),
        ),
      );
  }

  Future<void> _openSignup(BuildContext context) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AuthResult? result = await Navigator.of(context).push<AuthResult>(
      MaterialPageRoute<AuthResult>(
        builder: (routeContext) => SignupScreen(
          config: _demoConfig,
          header: const AuthHeader(
            label: 'Sign up',
            logo: Icon(Icons.person_add_alt),
            heightFactor: 0.2,
          ),
          onSignupSuccess: (AuthResult result) =>
              Navigator.of(routeContext).pop(result),
        ),
      ),
    );

    if (result == null || !result.isSuccess) {
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Account created for ${result.user?.email ?? result.user?.uid}',
          ),
        ),
      );
  }
}
