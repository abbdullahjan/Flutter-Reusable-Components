import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/auth/services/auth_service.dart';

/// A parsed REST authentication response.
///
/// Backend-independent: it carries the shared [AuthUser] plus the optional
/// bearer [token] returned by the backend. It is intentionally separate from
/// [AuthResult] so no REST-specific field leaks into the shared models.
class RestAuthSession {
  const RestAuthSession({required this.user, this.token});

  final AuthUser user;

  /// Bearer token returned by the backend, or `null` when the endpoint did not
  /// start a session (for example a signup that only creates an account).
  final String? token;
}

/// Translates between HTTP requests/responses and the module's models.
///
/// The default [JsonRestAuthAdapter] implements a conventional JSON contract.
/// Implement this interface to support a different server contract (custom
/// field names, envelope objects, specific status-code meanings, ...) without
/// changing [RestAuthService] or the shared models.
abstract class RestAuthAdapter {
  /// Builds the login request body from the credentials.
  Map<String, dynamic> encodeLogin({
    required String email,
    required String password,
  });

  /// Builds the signup request body from the signup form data.
  Map<String, dynamic> encodeSignup(SignUpRequest request);

  /// Builds the password-reset request body from the email address.
  Map<String, dynamic> encodePasswordReset(String email);

  /// Builds the query parameters for the username-availability request.
  Map<String, String> encodeUsernameAvailability(String userName);

  /// Parses a successful (2xx) response.
  ///
  /// Throws a [FormatException] when the body does not match the expected
  /// contract; [RestAuthService] turns that into a safe failure.
  RestAuthSession parseSession(http.Response response);

  /// Parses a successful (2xx) username-availability response into a boolean.
  ///
  /// Throws a [FormatException] when the body does not match the contract, so
  /// availability is never reported when the response is invalid.
  bool parseUsernameAvailability(http.Response response);

  /// Maps a non-2xx response to a user-facing message.
  ///
  /// The default implementation ignores the response body and maps only the
  /// status code, so raw server errors are never shown.
  String parseErrorMessage(http.Response response);
}

/// Default [RestAuthAdapter] implementing a conventional flat JSON contract:
///
/// ```json
/// {
///   "token": "jwt-or-opaque",
///   "user": {
///     "id": "user-123",
///     "email": "a@b.com",
///     "displayName": "Jane",
///     "photoUrl": "https://...",
///     "emailVerified": true
///   }
/// }
/// ```
///
/// Every field name is configurable. A `null` or empty `token` is accepted and
/// treated as "no session started".
///
/// The username-availability endpoint (when configured) is expected to return
/// a JSON object with a boolean flag:
///
/// ```json
/// { "available": true }
/// ```
///
/// Both the query parameter name ([usernameQueryField]) and the response flag
/// name ([availableField]) are configurable. When the flag is missing or is not
/// a boolean the response is treated as invalid and availability is not
/// reported.
class JsonRestAuthAdapter implements RestAuthAdapter {
  const JsonRestAuthAdapter({
    this.tokenField = 'token',
    this.userField = 'user',
    this.uidField = 'id',
    this.emailField = 'email',
    this.displayNameField = 'displayName',
    this.photoUrlField = 'photoUrl',
    this.emailVerifiedField = 'emailVerified',
    this.usernameQueryField = 'userName',
    this.availableField = 'available',
  });

  final String tokenField;
  final String userField;
  final String uidField;
  final String emailField;
  final String displayNameField;
  final String photoUrlField;
  final String emailVerifiedField;

  /// Query parameter used to send the username being checked.
  final String usernameQueryField;

  /// Boolean field in the availability response indicating whether the
  /// username is free.
  final String availableField;

  @override
  Map<String, dynamic> encodeLogin({
    required String email,
    required String password,
  }) {
    return <String, dynamic>{'email': email, 'password': password};
  }

  @override
  Map<String, dynamic> encodeSignup(SignUpRequest request) {
    return <String, dynamic>{
      'email': request.email,
      'password': request.password,
      if (request.fullName != null) 'fullName': request.fullName,
      if (request.userName != null) 'userName': request.userName,
      if (request.phoneNumber != null) 'phoneNumber': request.phoneNumber,
      'termsAccepted': request.termsAccepted,
    };
  }

  @override
  Map<String, dynamic> encodePasswordReset(String email) {
    return <String, dynamic>{'email': email};
  }

  @override
  Map<String, String> encodeUsernameAvailability(String userName) {
    return <String, String>{usernameQueryField: userName};
  }

  @override
  RestAuthSession parseSession(http.Response response) {
    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Unexpected authentication response.');
    }

    final Object? rawUser = decoded[userField];
    if (rawUser is! Map<String, dynamic>) {
      throw const FormatException('Missing user in authentication response.');
    }

    final Object? rawUid = rawUser[uidField];
    if (rawUid == null) {
      throw const FormatException(
        'Missing user id in authentication response.',
      );
    }

    final Object? rawToken = decoded[tokenField];
    final String? token = rawToken is String && rawToken.isNotEmpty
        ? rawToken
        : null;

    return RestAuthSession(
      token: token,
      user: AuthUser(
        uid: rawUid.toString(),
        email: _stringOrNull(rawUser[emailField]),
        displayName: _stringOrNull(rawUser[displayNameField]),
        photoUrl: _stringOrNull(rawUser[photoUrlField]),
        emailVerified: rawUser[emailVerifiedField] == true,
      ),
    );
  }

  @override
  bool parseUsernameAvailability(http.Response response) {
    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Unexpected username availability response.');
    }

    final Object? value = decoded[availableField];
    if (value is! bool) {
      throw const FormatException(
        'Missing availability flag in username availability response.',
      );
    }
    return value;
  }

  @override
  String parseErrorMessage(http.Response response) {
    final int status = response.statusCode;
    if (status == 400 || status == 401 || status == 403) {
      return AuthServiceMessages.invalidCredentials;
    }
    if (status == 409) {
      return AuthServiceMessages.emailAlreadyInUse;
    }
    if (status >= 500) {
      return AuthServiceMessages.somethingWentWrong;
    }
    return AuthServiceMessages.unknownError;
  }

  String? _stringOrNull(Object? value) => value is String ? value : null;
}
