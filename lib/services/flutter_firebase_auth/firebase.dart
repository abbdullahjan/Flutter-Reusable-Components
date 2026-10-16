/// Explicit opt-in entry point for the Firebase authentication backend.
///
/// `auth.dart` (the shared entry point) is Firebase-independent. Import this
/// library **only** when you want the Firebase implementation:
///
/// ```dart
/// import 'package:reusable_flutter_components/core/auth/auth.dart';
/// import 'package:reusable_flutter_components/services/flutter_firebase_auth/firebase.dart';
///
/// final config = AuthConfig(service: FirebaseAuthService());
/// ```
///
/// Importing `auth.dart` alone never pulls Firebase into the build, so a host
/// using `RestAuthService` (or a custom backend) does not depend on the
/// `firebase_core` / `firebase_auth` / `cloud_firestore` packages.
library;

export 'firebase_auth_service.dart';
