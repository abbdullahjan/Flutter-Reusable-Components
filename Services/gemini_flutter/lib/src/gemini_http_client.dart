import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'gemini_exceptions.dart';

/// Base URL for the Gemini REST API.
const _kBaseUrl = 'https://generativelanguage.googleapis.com/v1beta';

/// Low-level HTTP client for the Gemini REST API.
///
/// Handles:
/// - URL construction with API key query param
/// - JSON encoding / decoding
/// - Error mapping to typed exceptions
/// - Server-Sent Events (SSE) parsing for streaming
///
/// You should not need to use this directly — use [GeminiService] instead.
class GeminiHttpClient {
  GeminiHttpClient({
    required String apiKey,
    http.Client? client,
  })  : _apiKey = apiKey,
        _client = client ?? http.Client();

  final String _apiKey;
  final http.Client _client;

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
  };

  // ──────────────────────────────────────────────────────────────────────────
  //  Non-streaming POST
  // ──────────────────────────────────────────────────────────────────────────

  /// Sends a POST request to [path] (e.g. `/models/gemini-2.0-flash:generateContent`)
  /// and returns the decoded JSON body.
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = _uri(path);
    final response = await _client.post(
      uri,
      headers: _headers,
      body: jsonEncode(body),
    );
    return _decodeResponse(response);
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  Streaming POST (SSE)
  // ──────────────────────────────────────────────────────────────────────────

  /// Sends a POST to [path] with `alt=sse` and returns a stream of raw
  /// JSON maps, one per SSE `data:` line.
  ///
  /// Each emitted map is one streaming candidate chunk from Gemini.
  Stream<Map<String, dynamic>> postStream(
    String path,
    Map<String, dynamic> body,
  ) async* {
    final uri = _uri(path, sse: true);

    final request = http.Request('POST', uri)
      ..headers.addAll(_headers)
      ..body = jsonEncode(body);

    final http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await _client.send(request);
    } catch (e) {
      throw GeminiStreamException('Failed to open stream: $e');
    }

    if (streamedResponse.statusCode < 200 ||
        streamedResponse.statusCode >= 300) {
      final body = await streamedResponse.stream.bytesToString();
      _throwFromBody(body, streamedResponse.statusCode);
    }

    // Gemini SSE format: lines starting with "data: " followed by a JSON object.
    // A "[DONE]" sentinel marks the end of the stream.
    final buffer = StringBuffer();

    await for (final chunk
        in streamedResponse.stream.transform(utf8.decoder)) {
      buffer.write(chunk);
      final lines = buffer.toString().split('\n');

      // Keep the last (potentially incomplete) line in the buffer.
      buffer
        ..clear()
        ..write(lines.last);

      for (final line in lines.sublist(0, lines.length - 1)) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        if (!trimmed.startsWith('data:')) continue;

        final data = trimmed.substring(5).trim();
        if (data == '[DONE]') return;

        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          yield json;
        } catch (_) {
          // Malformed chunk — skip rather than crash the stream.
        }
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  Helpers
  // ──────────────────────────────────────────────────────────────────────────

  Uri _uri(String path, {bool sse = false}) {
    final params = <String, String>{'key': _apiKey};
    if (sse) params['alt'] = 'sse';
    return Uri.parse('$_kBaseUrl$path').replace(queryParameters: params);
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        throw GeminiParseException(
          'Could not parse Gemini response: $e',
          raw: response.body,
        );
      }
    }
    _throwFromBody(response.body, response.statusCode);
  }

  Never _throwFromBody(String body, int statusCode) {
    String message;
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final error = json['error'] as Map<String, dynamic>?;
      message = error?['message'] as String? ?? body;
    } catch (_) {
      message = body.isNotEmpty ? body : 'HTTP $statusCode';
    }
    throw GeminiApiException(message, statusCode: statusCode);
  }

  void dispose() => _client.close();
}
