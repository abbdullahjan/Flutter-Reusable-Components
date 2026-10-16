import 'dart:convert';
import 'package:http/http.dart' as http;
import 'stripe_exceptions.dart';

/// Thin wrapper around [http.Client] that:
///  - prefixes every request with [baseUrl]
///  - attaches an optional Bearer token (Firebase ID token)
///  - throws [BackendException] on non-2xx responses
///  - decodes JSON automatically
class StripeHttpClient {
  StripeHttpClient({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// e.g. "https://my-server.com" — no trailing slash.
  final String baseUrl;

  final http.Client _client;

  /// Optional Firebase ID token — set after the user signs in.
  String? _idToken;

  void setIdToken(String? token) => _idToken = token;

  // ──────────────────────────────────────────────────────────────────────────
  //  Low-level helpers
  // ──────────────────────────────────────────────────────────────────────────

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_idToken != null) 'Authorization': 'Bearer $_idToken',
      };

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await _client.post(
      uri,
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> get(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await _client.get(uri, headers: _headers);
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json;
    }

    final message = json['error'] as String? ?? response.reasonPhrase ?? 'Unknown error';
    throw BackendException(message, statusCode: response.statusCode);
  }

  void dispose() => _client.close();
}
