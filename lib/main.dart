import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/auth/auth.dart';
import 'services/flutter_firebase_auth/firebase.dart';

/// Minimal demonstration host application for the reusable authentication
/// module. It shows how a real app opens the login/signup screens and reacts to
/// successful authentication. The module itself never imports this file.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (error) {
    // The demo still runs without Firebase configuration; authentication
    // attempts will then report a failure instead of crashing.
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
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
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
      appBar: AppBar(title: const Text('Reusable auth demo')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.flutter_dash,
                  size: 72,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Extracted login and signup module',
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'The demo injects FirebaseAuthService() explicitly (from '
                  'services/flutter_firebase_auth/firebase.dart). Add your '
                  'Firebase configuration '
                  '(google-services.json / firebase_options.dart) to '
                  'authenticate for real.',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                AuthButton(
                  label: 'Open login screen',
                  icon: Icons.login,
                  onPressed: () => _openLogin(context),
                ),
                const SizedBox(height: 12),
                AuthButton(
                  label: 'Open signup screen',
                  icon: Icons.person_add_alt,
                  onPressed: () => _openSignup(context),
                ),
              ],
            ),
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
