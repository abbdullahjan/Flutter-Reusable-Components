/// User information returned by the authentication service.
///
/// This is a small, dependency-free view of the signed-in user so screens and
/// host applications never have to import `firebase_auth` (or any other
/// backend package) directly. The Firebase-specific mapping from a Firebase
/// `User` lives in `firebase_auth_service.dart`.
class AuthUser {
  const AuthUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
    this.emailVerified = false,
  });

  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final bool emailVerified;
}

/// Outcome of an authentication call.
///
/// An [AuthService] implementation never throws for expected failures; it
/// returns [AuthResult.failure] with a user-friendly message that a screen can
/// show.
class AuthResult {
  const AuthResult.success(this.user) : isSuccess = true, errorMessage = null;

  const AuthResult.failure(this.errorMessage) : isSuccess = false, user = null;

  final bool isSuccess;
  final AuthUser? user;
  final String? errorMessage;
}

/// Data collected by the signup form.
class SignUpRequest {
  const SignUpRequest({
    required this.email,
    required this.password,
    this.fullName,
    this.userName,
    this.phoneNumber,
    this.termsAccepted = false,
  });

  final String email;
  final String password;
  final String? fullName;
  final String? userName;
  final String? phoneNumber;
  final bool termsAccepted;
}

/// Default, source-identical error messages.
///
/// Screens surface [AuthResult.errorMessage] directly, so these strings can be
/// edited here if a host application needs different wording.
class AuthServiceMessages {
  AuthServiceMessages._();

  static const String invalidCredentials = 'Invalid Credentials.';
  static const String unknownError = 'An unknown error occurred.';
  static const String somethingWentWrong = 'Something went wrong.';
  static const String emailAlreadyInUse = 'This email is already in use.';
  static const String invalidEmail = 'Invalid email address.';
  static const String weakPassword = 'Password should be six characters.';
}

/// Result of an asynchronous username-availability check.
///
/// A bare boolean cannot distinguish "the username is taken" from "the check
/// could not be completed", so callers would otherwise show a misleading
/// "already taken" message whenever the backend was simply unreachable.
enum UsernameAvailability {
  /// The username is free to use.
  available,

  /// The username is already registered.
  taken,

  /// Availability could not be determined (network failure, timeout, server
  /// error or an unexpected response). Callers should treat this as "not yet
  /// verified" and let the user retry instead of reporting the username as
  /// taken.
  unknown,
}

/// Authentication abstraction used by the auth screens.
///
/// Keeping the screens behind this interface means the UI can be widget-tested
/// with a fake implementation and means a host application can plug in another
/// backend without touching the screens.
///
/// This interface and the models above are intentionally backend-independent:
/// this library imports nothing, so consuming it never pulls in Firebase (or
/// any other backend package). Concrete backends live in their own libraries:
/// * Firebase – `services/flutter_firebase_auth/firebase_auth_service.dart`
///   (opt-in via `services/flutter_firebase_auth/firebase.dart`)
/// * REST – `services/flutter_REST_auth/rest_auth_service.dart`
abstract class AuthService {
  Future<AuthResult> signIn({required String email, required String password});

  Future<AuthResult> signUp(SignUpRequest request);

  Future<AuthResult> sendPasswordResetEmail(String email);

  /// Reports whether [userName] is free to use.
  ///
  /// Returns [UsernameAvailability.unknown] when the check cannot be completed,
  /// so callers can offer a retry instead of claiming the username is taken.
  Future<UsernameAvailability> isUsernameAvailable(String userName);

  Future<void> signOut();
}
