/// Configurable endpoint paths used by [RestAuthService].
///
/// Paths are appended to the service base URL. A leading `/` is optional; the
/// base URL may contain a path prefix (e.g. `https://host/api/v2`) that is
/// preserved.
///
/// The defaults describe a conventional JSON contract. Because no backend
/// contract is assumed, every path (and, through [RestAuthAdapter], every
/// request/response shape and error mapping) can be overridden.
class RestEndpoints {
  const RestEndpoints({
    this.loginPath = '/auth/login',
    this.signupPath = '/auth/signup',
    this.forgotPasswordPath = '/auth/forgot-password',
    this.usernameAvailabilityPath,
  });

  /// `POST` endpoint used by `AuthService.signIn`.
  final String loginPath;

  /// `POST` endpoint reserved for `AuthService.signUp`.
  final String signupPath;

  /// `POST` endpoint reserved for `AuthService.sendPasswordResetEmail`.
  final String forgotPasswordPath;

  /// Optional `GET` endpoint used by `AuthService.isUsernameAvailable`.
  ///
  /// When `null` the service reports usernames as available without a network
  /// call, so the optional endpoint never breaks the [AuthService] contract.
  final String? usernameAvailabilityPath;
}
