/// gemini_flutter — plug-and-play Gemini AI package for Flutter.
///
/// Wraps the Gemini REST API into a single, reusable [GeminiService] class.
/// Supports single-turn prompts, multi-turn chat, and streaming responses.
///
/// ## Quick start
///
/// ```dart
/// import 'package:gemini_flutter/gemini_flutter.dart';
///
/// final gemini = GeminiService(apiKey: 'AIza...');
///
/// // Single turn
/// final response = await gemini.sendMessage('What is Flutter?');
/// print(response.text);
///
/// // Streaming
/// await for (final chunk in gemini.streamMessage('Tell me a story')) {
///   print(chunk.text);
/// }
///
/// // Multi-turn chat
/// final history = <ChatMessage>[];
/// history.add(ChatMessage.user('Hi!'));
/// final reply = await gemini.sendChat(history);
/// history.add(ChatMessage.model(reply.text));
/// ```
library gemini_flutter;

export 'src/gemini_service.dart';
export 'src/models.dart';
export 'src/gemini_exceptions.dart';
