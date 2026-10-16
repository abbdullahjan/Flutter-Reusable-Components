import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/auth/services/auth_service.dart';
import 'rest_auth_adapter.dart';
import 'rest_endpoints.dart';
import 'token_store.dart';

/// [AuthService] implementation that authenticates against a configurable REST
/// API instead of Firebase.
///
/// It is a drop-in alternative to `FirebaseAuthService`: pass an instance
/// through `AuthConfig(service: ...)` and the shared screens work unchanged.
/// The Firebase implementation is not touched.
///
/// All [AuthService] methods are implemented: [signIn], [signUp],
/// [sendPasswordResetEmail], [isUsernameAvailable] and [signOut].
///
/// A signup that creates the account but returns no token is still reported as
/// a success; the service never invents a token. Host applications determine
/// whether a session exists by reading the injected [TokenStore] (a token is
/// present only when the backend returned one).
///
/// Security defaults:
/// * HTTPS is required. `http` is only accepted when [allowInsecureHttp] is
///   explicitly enabled for local development.
/// * Error messages are safe, fixed strings; response bodies are never shown.
/// * Tokens, passwords and request/response bodies are never logged.
class RestAuthService implements AuthService {
  RestAuthService({
    required Uri baseUrl,
    http.Client? client,
    this.endpoints = const RestEndpoints(),
    this.adapter = const JsonRestAuthAdapter(),
    this.defaultHeaders = const <String, String>{},
    this.timeout = const Duration(seconds: 20),
    TokenStore? tokenStore,
    bool allowInsecureHttp = false,
  }) : _baseUrl = _validateBaseUrl(baseUrl, allowInsecureHttp),
       _client = client ?? http.Client(),
       _ownsClient = client == null,
       _tokenStore = tokenStore ?? InMemoryTokenStore();

  static const Map<String, String> _jsonHeaders = <String, String>{
    'Accept': 'application/json',
    'Content-Type': 'application/json; charset=utf-8',
  };

  final Uri _baseUrl;
  final http.Client _client;
  final bool _ownsClient;
  final TokenStore _tokenStore;

  final RestEndpoints endpoints;
  final RestAuthAdapter adapter;

  /// Headers added to every request (for example a static API key). Keys given
  /// here override the defaults, so the contract can be customised.
  final Map<String, String> defaultHeaders;

  final Duration timeout;

  /// The underlying base URL, after validation.
  Uri get baseUrl => _baseUrl;

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final Map<String, dynamic> payload = adapter.encodeLogin(
        email: email.trim(),
        password: password,
      );

      final http.Response response = await _client
          .post(
            _resolve(endpoints.loginPath),
            headers: <String, String>{..._jsonHeaders, ...defaultHeaders},
            body: jsonEncode(payload),
          )
          .timeout(timeout);

      if (_isSuccess(response.statusCode)) {
        final RestAuthSession session = adapter.parseSession(response);
        final String? token = session.token;
        if (token != null) {
          await _tokenStore.save(token);
        }
        return AuthResult.success(session.user);
      }

      return AuthResult.failure(adapter.parseErrorMessage(response));
    } on TimeoutException {
      return const AuthResult.failure(AuthServiceMessages.somethingWentWrong);
    } on FormatException {
      return const AuthResult.failure(AuthServiceMessages.unknownError);
    } catch (e) {
      debugPrint('RestAuthService.signIn failed: ${e.runtimeType}');
      return const AuthResult.failure(AuthServiceMessages.somethingWentWrong);
    }
  }

  @override
  Future<AuthResult> signUp(SignUpRequest request) async {
    try {
      final Map<String, dynamic> payload = adapter.encodeSignup(request);

      final http.Response response = await _client
          .post(
            _resolve(endpoints.signupPath),
            headers: <String, String>{..._jsonHeaders, ...defaultHeaders},
            body: jsonEncode(payload),
          )
          .timeout(timeout);

      if (_isSuccess(response.statusCode)) {
        // The account was created. A token may or may not be returned; the
        // result is a success either way and a token is only stored when the
        // backend actually provided one.
        final RestAuthSession session = adapter.parseSession(response);
        final String? token = session.token;
        if (token != null) {
          await _tokenStore.save(token);
        }
        return AuthResult.success(session.user);
      }

      return AuthResult.failure(adapter.parseErrorMessage(response));
    } on TimeoutException {
      return const AuthResult.failure(AuthServiceMessages.somethingWentWrong);
    } on FormatException {
      return const AuthResult.failure(AuthServiceMessages.unknownError);
    } catch (e) {
      debugPrint('RestAuthService.signUp failed: ${e.runtimeType}');
      return const AuthResult.failure(AuthServiceMessages.somethingWentWrong);
    }
  }

  @override
  Future<AuthResult> sendPasswordResetEmail(String email) async {
    try {
      final Map<String, dynamic> payload = adapter.encodePasswordReset(
        email.trim(),
      );

      final http.Response response = await _client
          .post(
            _resolve(endpoints.forgotPasswordPath),
            headers: <String, String>{..._jsonHeaders, ...defaultHeaders},
            body: jsonEncode(payload),
          )
          .timeout(timeout);

      if (_isSuccess(response.statusCode)) {
        // A password-reset request carries no session payload, so a 2xx is a
        // success. The response body is neither read nor exposed.
        return const AuthResult.success(null);
      }

      return AuthResult.failure(adapter.parseErrorMessage(response));
    } on TimeoutException {
      return const AuthResult.failure(AuthServiceMessages.somethingWentWrong);
    } on FormatException {
      return const AuthResult.failure(AuthServiceMessages.unknownError);
    } catch (e) {
      debugPrint(
        'RestAuthService.sendPasswordResetEmail failed: ${e.runtimeType}',
      );
      return const AuthResult.failure(AuthServiceMessages.somethingWentWrong);
    }
  }

  @override
  Future<UsernameAvailability> isUsernameAvailable(String userName) async {
    final String? path = endpoints.usernameAvailabilityPath;
    if (path == null) {
      // The endpoint is optional. When it is not configured the documented
      // contract is to report the username as available without a request.
      return UsernameAvailability.available;
    }

    final String name = userName.trim();
    if (name.isEmpty) {
      // Nothing to look up; matches the Firebase implementation.
      return UsernameAvailability.available;
    }

    try {
      final Uri endpoint = _resolve(path);
      final Uri uri = endpoint.replace(
        queryParameters: <String, String>{
          ...endpoint.queryParameters,
          ...adapter.encodeUsernameAvailability(name),
        },
      );

      final http.Response response = await _client
          .get(
            uri,
            headers: <String, String>{..._jsonHeaders, ...defaultHeaders},
          )
          .timeout(timeout);

      if (_isSuccess(response.statusCode)) {
        return adapter.parseUsernameAvailability(response)
            ? UsernameAvailability.available
            : UsernameAvailability.taken;
      }

      // A non-2xx response means availability could not be established, so
      // report it as unknown rather than as "taken".
      return UsernameAvailability.unknown;
    } on TimeoutException {
      return UsernameAvailability.unknown;
    } on FormatException {
      return UsernameAvailability.unknown;
    } catch (e) {
      debugPrint(
        'RestAuthService.isUsernameAvailable failed: ${e.runtimeType}',
      );
      return UsernameAvailability.unknown;
    }
  }

  /// Signs the user out by clearing the locally stored token.
  ///
  /// The documented REST contract defines no server-side logout endpoint, so
  /// sign-out is local: the token is removed from the [TokenStore] and no HTTP
  /// request is made. Clearing is idempotent, so repeated sign-out (or sign-out
  /// when no token is stored) is safe. There is no remote request and therefore
  /// no remote failure mode that could leave the user locally authenticated;
  /// if a host-supplied [TokenStore] throws, the error propagates rather than
  /// being swallowed while the token remains usable.
  @override
  Future<void> signOut() async {
    await _tokenStore.clear();
  }

  /// Closes the underlying HTTP client when this service created it.
  ///
  /// An injected client is owned by the caller and is left open.
  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }

  Uri _resolve(String path) {
    final String base = _baseUrl.toString();
    final String withoutTrailingSlash = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    final String withLeadingSlash = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$withoutTrailingSlash$withLeadingSlash');
  }

  static bool _isSuccess(int statusCode) =>
      statusCode >= 200 && statusCode < 300;

  static Uri _validateBaseUrl(Uri baseUrl, bool allowInsecureHttp) {
    final String scheme = baseUrl.scheme.toLowerCase();
    if (scheme == 'https') {
      return baseUrl;
    }
    if (scheme == 'http' && allowInsecureHttp) {
      return baseUrl;
    }
    throw ArgumentError.value(
      baseUrl,
      'baseUrl',
      'RestAuthService requires an HTTPS base URL. Set allowInsecureHttp to '
          'true only for local development.',
    );
  }
}
