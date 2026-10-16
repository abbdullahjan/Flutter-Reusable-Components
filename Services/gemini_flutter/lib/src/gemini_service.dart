import 'models.dart';
import 'gemini_exceptions.dart';
import 'gemini_http_client.dart';

export 'models.dart';
export 'gemini_exceptions.dart';

/// The single entry-point for all Gemini AI operations.
///
/// ## Setup (once, anywhere before first use)
/// ```dart
/// final gemini = GeminiService(apiKey: 'AIza...');
/// ```
///
/// ## Single-turn
/// ```dart
/// final response = await gemini.sendMessage('What is Flutter?');
/// print(response.text);
/// ```
///
/// ## Multi-turn chat
/// ```dart
/// final history = <ChatMessage>[];
/// history.add(ChatMessage.user('Hi, who are you?'));
/// final reply = await gemini.sendChat(history);
/// history.add(ChatMessage.model(reply.text));
/// ```
///
/// ## Streaming
/// ```dart
/// await for (final chunk in gemini.streamMessage('Tell me a story')) {
///   setState(() => _text += chunk.text);
/// }
/// ```
class GeminiService {
  GeminiService({
    required String apiKey,
    GeminiConfig config = const GeminiConfig(),
  })  : _config = config,
        _http = GeminiHttpClient(apiKey: apiKey);

  final GeminiConfig _config;
  final GeminiHttpClient _http;

  // ──────────────────────────────────────────────────────────────────────────
  //  Single-turn
  // ──────────────────────────────────────────────────────────────────────────

  /// Sends a single [prompt] and returns the model's reply.
  ///
  /// Use [overrideConfig] to change generation settings for this call only.
  ///
  /// ```dart
  /// final response = await gemini.sendMessage('Explain async/await in Dart');
  /// print(response.text);
  /// ```
  ///
  /// Throws [GeminiApiException] on API errors, [GeminiParseException] if the
  /// response cannot be decoded.
  Future<GeminiResponse> sendMessage(
    String prompt, {
    GeminiConfig? overrideConfig,
  }) {
    return sendChat(
      [ChatMessage.user(prompt)],
      overrideConfig: overrideConfig,
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  Multi-turn chat
  // ──────────────────────────────────────────────────────────────────────────

  /// Sends a full conversation [history] and returns the next model reply.
  ///
  /// Maintain the history yourself — append the user message before calling,
  /// then append [GeminiResponse.text] as a `ChatMessage.model` afterwards.
  ///
  /// ```dart
  /// history.add(ChatMessage.user(userInput));
  /// final reply = await gemini.sendChat(history);
  /// history.add(ChatMessage.model(reply.text));
  /// ```
  Future<GeminiResponse> sendChat(
    List<ChatMessage> history, {
    GeminiConfig? overrideConfig,
  }) async {
    final cfg = overrideConfig ?? _config;
    final body = _buildBody(history, cfg);
    final path = '/models/${cfg.model}:generateContent';

    final json = await _http.post(path, body);
    return GeminiResponse.fromJson(json);
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  Streaming
  // ──────────────────────────────────────────────────────────────────────────

  /// Streams the model's reply to [prompt] one chunk at a time.
  ///
  /// Ideal for a typewriter / live-typing effect in your UI.
  ///
  /// ```dart
  /// final buffer = StringBuffer();
  /// await for (final chunk in gemini.streamMessage('Tell me a story')) {
  ///   buffer.write(chunk.text);
  ///   setState(() => _displayText = buffer.toString());
  /// }
  /// ```
  ///
  /// Throws [GeminiStreamException] if the stream fails to open.
  Stream<GeminiChunk> streamMessage(
    String prompt, {
    GeminiConfig? overrideConfig,
  }) {
    return streamChat(
      [ChatMessage.user(prompt)],
      overrideConfig: overrideConfig,
    );
  }

  /// Streaming version of [sendChat] — full conversation history with streaming.
  ///
  /// ```dart
  /// history.add(ChatMessage.user(userInput));
  /// final replyBuffer = StringBuffer();
  /// await for (final chunk in gemini.streamChat(history)) {
  ///   replyBuffer.write(chunk.text);
  ///   setState(() => _displayText = replyBuffer.toString());
  /// }
  /// history.add(ChatMessage.model(replyBuffer.toString()));
  /// ```
  Stream<GeminiChunk> streamChat(
    List<ChatMessage> history, {
    GeminiConfig? overrideConfig,
  }) async* {
    final cfg = overrideConfig ?? _config;
    final body = _buildBody(history, cfg);
    final path = '/models/${cfg.model}:streamGenerateContent';

    await for (final json in _http.postStream(path, body)) {
      final candidates = json['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) continue;

      final first = candidates.first as Map<String, dynamic>;
      final content = first['content'] as Map<String, dynamic>?;
      if (content == null) continue;

      final parts = content['parts'] as List<dynamic>?;
      if (parts == null || parts.isEmpty) continue;

      final text =
          (parts.first as Map<String, dynamic>)['text'] as String? ?? '';
      final finishReason = first['finishReason'] as String?;
      final isDone = finishReason != null && finishReason != 'NULL';

      yield GeminiChunk(text: text, isDone: isDone);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  Convenience
  // ──────────────────────────────────────────────────────────────────────────

  /// Streams the full reply and returns it as a single concatenated string.
  ///
  /// Useful when you want the complete text but still want low latency
  /// (the future resolves as soon as the stream closes, not before).
  ///
  /// ```dart
  /// final answer = await gemini.streamToString('Summarise the SOLID principles');
  /// ```
  Future<String> streamToString(
    String prompt, {
    GeminiConfig? overrideConfig,
  }) async {
    final buffer = StringBuffer();
    await for (final chunk
        in streamMessage(prompt, overrideConfig: overrideConfig)) {
      buffer.write(chunk.text);
    }
    return buffer.toString();
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  Internal
  // ──────────────────────────────────────────────────────────────────────────

  Map<String, dynamic> _buildBody(
    List<ChatMessage> history,
    GeminiConfig cfg,
  ) {
    final body = <String, dynamic>{
      'contents': history.map((m) => m.toJson()).toList(),
    };

    if (cfg.systemInstruction != null) {
      body['systemInstruction'] = {
        'parts': [
          {'text': cfg.systemInstruction}
        ],
      };
    }

    final genConfig = cfg.toGenerationConfig();
    if (genConfig.isNotEmpty) {
      body['generationConfig'] = genConfig;
    }

    return body;
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  Cleanup
  // ──────────────────────────────────────────────────────────────────────────

  void dispose() => _http.dispose();
}
