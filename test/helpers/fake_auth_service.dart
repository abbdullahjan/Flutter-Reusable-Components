import 'package:reusable_flutter_components/core/auth/auth.dart';

/// Test double for [AuthService].
///
/// Lets the widgets be tested without Firebase: every call is recorded and the
/// returned [AuthResult] can be configured per test.
class FakeAuthService implements AuthService {
  FakeAuthService({
    AuthResult? signInResult,
    AuthResult? signUpResult,
    AuthResult? passwordResetResult,
    this.usernameAvailability = UsernameAvailability.available,
    this.delay = Duration.zero,
  }) : signInResult =
           signInResult ??
           const AuthResult.success(
             AuthUser(uid: 'uid-1', email: 'user@example.com'),
           ),
       signUpResult =
           signUpResult ??
           const AuthResult.success(
             AuthUser(uid: 'uid-2', email: 'new@example.com'),
           ),
       passwordResetResult =
           passwordResetResult ?? const AuthResult.success(null);

  AuthResult signInResult;
  AuthResult signUpResult;
  AuthResult passwordResetResult;
  UsernameAvailability usernameAvailability;
  Duration delay;

  int signInCalls = 0;
  int signUpCalls = 0;
  int passwordResetCalls = 0;
  int usernameAvailabilityCalls = 0;
  int signOutCalls = 0;

  String? lastEmail;
  String? lastPassword;
  String? lastResetEmail;
  SignUpRequest? lastSignUpRequest;

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    lastEmail = email;
    lastPassword = password;
    await _wait();
    return signInResult;
  }

  @override
  Future<AuthResult> signUp(SignUpRequest request) async {
    signUpCalls++;
    lastSignUpRequest = request;
    await _wait();
    return signUpResult;
  }

  @override
  Future<AuthResult> sendPasswordResetEmail(String email) async {
    passwordResetCalls++;
    lastResetEmail = email;
    await _wait();
    return passwordResetResult;
  }

  @override
  Future<UsernameAvailability> isUsernameAvailable(String userName) async {
    usernameAvailabilityCalls++;
    await _wait();
    return usernameAvailability;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }

  Future<void> _wait() async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
  }
}
