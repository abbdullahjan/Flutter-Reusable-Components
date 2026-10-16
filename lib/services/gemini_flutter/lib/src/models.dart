/// All data models used by [GeminiService].

// ─────────────────────────────────────────────────────────────────────────────
//  Config
// ─────────────────────────────────────────────────────────────────────────────

/// Configuration passed to [GeminiService] at construction time.
///
/// ```dart
/// const config = GeminiConfig(
///   model: 'gemini-2.0-flash',
///   temperature: 0.7,
///   maxOutputTokens: 1024,
/// );
/// ```
class GeminiConfig {
  const GeminiConfig({
    this.model = 'gemini-flash-latest',
    this.systemInstruction,
    this.temperature,
    this.topP,
    this.topK,
    this.maxOutputTokens,
    this.stopSequences,
  });

  /// Gemini model ID.
  /// Common values: 'gemini-2.0-flash', 'gemini-1.5-pro', 'gemini-1.5-flash'.
  final String model;

  /// Optional system-level instruction that shapes the model's behaviour
  /// across the entire conversation (e.g. "You are a helpful coding tutor.").
  final String? systemInstruction;

  /// Sampling temperature — 0.0 (deterministic) to 2.0 (very creative).
  final double? temperature;

  /// Nucleus sampling probability mass (0.0–1.0).
  final double? topP;

  /// Top-k sampling — number of tokens considered per step.
  final int? topK;

  /// Hard cap on the number of output tokens.
  final int? maxOutputTokens;

  /// List of strings that will stop generation when encountered.
  final List<String>? stopSequences;

  /// Converts to the `generationConfig` block expected by the Gemini API.
  Map<String, dynamic> toGenerationConfig() {
    final map = <String, dynamic>{};
    if (temperature != null) map['temperature'] = temperature;
    if (topP != null) map['topP'] = topP;
    if (topK != null) map['topK'] = topK;
    if (maxOutputTokens != null) map['maxOutputTokens'] = maxOutputTokens;
    if (stopSequences != null && stopSequences!.isNotEmpty) {
      map['stopSequences'] = stopSequences;
    }
    return map;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Chat message
// ─────────────────────────────────────────────────────────────────────────────

/// A single message in a conversation.
///
/// [role] is either `'user'` or `'model'`.
///
/// ```dart
/// const msg = ChatMessage.user('Hello, who are you?');
/// const reply = ChatMessage.model('I am Gemini, made by Google.');
/// ```
class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.text,
  });

  /// Factory for a user message.
  const ChatMessage.user(String text) : this(role: 'user', text: text);

  /// Factory for a model (assistant) message.
  const ChatMessage.model(String text) : this(role: 'model', text: text);

  /// `'user'` or `'model'`.
  final String role;

  /// Plain-text content of the message.
  final String text;

  /// Serialises to the Gemini API `contents[]` format.
  Map<String, dynamic> toJson() => {
        'role': role,
        'parts': [
          {'text': text}
        ],
      };

  /// Deserialises from a Gemini API response `contents[]` entry.
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final parts = json['parts'] as List<dynamic>;
    final text = (parts.first as Map<String, dynamic>)['text'] as String? ?? '';
    return ChatMessage(
      role: json['role'] as String,
      text: text,
    );
  }

  @override
  String toString() => '[$role]: $text';
}

// ─────────────────────────────────────────────────────────────────────────────
//  Response
// ─────────────────────────────────────────────────────────────────────────────

/// The result returned by [GeminiService.sendMessage] and [GeminiService.sendChat].
class GeminiResponse {
  const GeminiResponse({
    required this.text,
    required this.finishReason,
    this.promptTokenCount,
    this.candidatesTokenCount,
    this.totalTokenCount,
  });

  /// The model's reply as plain text.
  final String text;

  /// Why generation stopped — e.g. `'STOP'`, `'MAX_TOKENS'`, `'SAFETY'`.
  final String finishReason;

  /// Number of tokens in the prompt (may be null if not returned).
  final int? promptTokenCount;

  /// Number of tokens in the generated reply.
  final int? candidatesTokenCount;

  /// Total tokens consumed by this request.
  final int? totalTokenCount;

  factory GeminiResponse.fromJson(Map<String, dynamic> json) {
    final candidates = json['candidates'] as List<dynamic>;
    final first = candidates.first as Map<String, dynamic>;
    final content = first['content'] as Map<String, dynamic>;
    final parts = content['parts'] as List<dynamic>;
    final text = (parts.first as Map<String, dynamic>)['text'] as String? ?? '';
    final finishReason = first['finishReason'] as String? ?? 'UNKNOWN';

    final usage = json['usageMetadata'] as Map<String, dynamic>?;

    return GeminiResponse(
      text: text,
      finishReason: finishReason,
      promptTokenCount: usage?['promptTokenCount'] as int?,
      candidatesTokenCount: usage?['candidatesTokenCount'] as int?,
      totalTokenCount: usage?['totalTokenCount'] as int?,
    );
  }

  /// Convenience — true when Gemini finished naturally (not truncated/blocked).
  bool get isComplete => finishReason == 'STOP';

  @override
  String toString() => text;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Streaming chunk
// ─────────────────────────────────────────────────────────────────────────────

/// A single chunk emitted by [GeminiService.streamMessage].
class GeminiChunk {
  const GeminiChunk({
    required this.text,
    required this.isDone,
  });

  /// Partial text for this chunk.
  final String text;

  /// True on the final chunk — generation is complete.
  final bool isDone;

  @override
  String toString() => text;
}
