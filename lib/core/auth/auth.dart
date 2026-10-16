/// Public API of the reusable authentication module.
///
/// Import this single file from the host application:
///
/// ```dart
/// import 'package:reusable_flutter_components/core/auth/auth.dart';
/// import 'package:reusable_flutter_components/services/flutter_firebase_auth/firebase.dart';
///
/// final config = AuthConfig(service: FirebaseAuthService());
///
/// Navigator.of(context).push(
///   MaterialPageRoute(
///     builder: (_) => LoginScreen(
///       config: config,
///       onLoginSuccess: (result) => Navigator.of(context).pop(result),
///     ),
///   ),
/// );
/// ```
///
/// The module was extracted from the `amaan_van_repo` Flutter project
/// (Firebase Authentication + Cloud Firestore) and keeps the original
/// validation, error handling and loading behaviour while being independent
/// from that application's theme, branding, navigation and business features.
///
/// The backend is selected explicitly by injecting an `AuthService` into
/// `AuthConfig`. This library is **Firebase-independent**: nothing exported
/// here imports Firebase, so REST-only hosts do not need the Firebase packages.
/// The example above opts into Firebase through the `firebase.dart` entry
/// point; use `RestAuthService` (exported here) or a custom `AuthService` for
/// other backends.
library;

export 'auth_config.dart';
export 'screens/forgot_password_screen.dart';
export 'screens/login_screen.dart';
export 'screens/signup_screen.dart';
export 'services/auth_service.dart';
export '../../services/flutter_REST_auth/rest_auth_adapter.dart';
export '../../services/flutter_REST_auth/rest_auth_service.dart';
export '../../services/flutter_REST_auth/rest_endpoints.dart';
export '../../services/flutter_REST_auth/token_store.dart';
export 'state/auth_state.dart';
export 'validators/auth_validators.dart';
export 'widgets/auth_button.dart';
export 'widgets/auth_header.dart';
export 'widgets/auth_link_row.dart';
export 'widgets/auth_text_field.dart';
