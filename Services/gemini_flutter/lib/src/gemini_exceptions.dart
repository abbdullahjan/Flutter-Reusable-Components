/// Thrown when the Gemini REST API returns a non-2xx response.
///
/// ```dart
/// try {
///   final response = await gemini.sendMessage('Hello');
/// } on GeminiApiException catch (e) {
///   print('${e.statusCode}: ${e.message}');
/// }
/// ```
class GeminiApiException implements Exception {
  const GeminiApiException(this.message, {this.statusCode});

  final String message;

  /// HTTP status code from the API (e.g. 400, 403, 429, 500).
  final int? statusCode;

  /// Common cause hints based on status code.
  String get hint {
    switch (statusCode) {
      case 400:
        return 'Bad request — check your prompt or config values.';
      case 403:
        return 'Invalid or missing API key.';
      case 429:
        return 'Rate limit exceeded — slow down requests or upgrade your quota.';
      case 500:
        return 'Gemini server error — try again shortly.';
      default:
        return '';
    }
  }

  @override
  String toString() {
    final code = statusCode != null ? '[$statusCode] ' : '';
    final hintStr = hint.isNotEmpty ? ' ($hint)' : '';
    return 'GeminiApiException: $code$message$hintStr';
  }
}

/// Thrown when the response body cannot be parsed.
class GeminiParseException implements Exception {
  const GeminiParseException(this.message, {this.raw});

  final String message;

  /// The raw response body that failed to parse (for debugging).
  final String? raw;

  @override
  String toString() => 'GeminiParseException: $message';
}

/// Thrown when a streaming request fails mid-stream.
class GeminiStreamException implements Exception {
  const GeminiStreamException(this.message);

  final String message;

  @override
  String toString() => 'GeminiStreamException: $message';
}
