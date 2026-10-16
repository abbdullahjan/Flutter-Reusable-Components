# Integration Guide — gemini_flutter

How to add Gemini AI to any Flutter app in minutes.

---

## Get an API key

1. Go to [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Click **Create API key**
3. Copy the key — it starts with `AIza...`

No billing required for the free tier. The key goes **in your Flutter app** (or an `.env`-equivalent). There is no backend involved.

---

## Add the package

In your app's `pubspec.yaml`:

```yaml
dependencies:
  gemini_flutter:
    path: ../gemini_flutter   # adjust relative path as needed
```

Then run:

```bash
flutter pub get
```

---

## Create the service

One instance per app — put it in a provider, singleton, or pass it down the tree.

```dart
import 'package:gemini_flutter/gemini_flutter.dart';

final gemini = GeminiService(
  apiKey: 'AIza_YOUR_KEY_HERE',
  config: const GeminiConfig(
    model: 'gemini-2.0-flash',       // fast and capable — good default
    temperature: 0.7,                 // 0.0 = deterministic, 2.0 = very creative
    maxOutputTokens: 1024,
    systemInstruction: 'You are a helpful assistant.',  // optional
  ),
);
```

Call `gemini.dispose()` when done (e.g. in a widget's `dispose()`).

---

## Single-turn prompt

Best for one-shot questions where you don't need conversation history.

```dart
try {
  final response = await gemini.sendMessage('Explain async/await in Dart');
  print(response.text);
  print(response.isComplete);     // true if finishReason == 'STOP'
  print(response.totalTokenCount);
} on GeminiApiException catch (e) {
  // e.statusCode, e.message, e.hint
  debugPrint('$e');
}
```

---

## Multi-turn chat

Maintain a list of `ChatMessage` objects yourself and pass the full history on each call.

```dart
final history = <ChatMessage>[];

// User sends a message
history.add(ChatMessage.user('Hi, who are you?'));
final reply = await gemini.sendChat(history);

// Append model reply so next turn has context
history.add(ChatMessage.model(reply.text));

// Continue the conversation
history.add(ChatMessage.user('What can you help me with?'));
final reply2 = await gemini.sendChat(history);
history.add(ChatMessage.model(reply2.text));
```

---

## Streaming (typewriter effect)

Use `streamMessage` for a live typing experience — chunks arrive as they are generated.

```dart
final buffer = StringBuffer();

await for (final chunk in gemini.streamMessage('Tell me a story')) {
  buffer.write(chunk.text);
  setState(() => _displayText = buffer.toString());
}

// chunk.isDone is true on the final chunk
```

### Streaming with chat history

```dart
history.add(ChatMessage.user(userInput));
final replyBuffer = StringBuffer();

await for (final chunk in gemini.streamChat(history)) {
  replyBuffer.write(chunk.text);
  setState(() => _displayText = replyBuffer.toString());
}

history.add(ChatMessage.model(replyBuffer.toString()));
```

### Streaming but you just want the final string

```dart
final fullReply = await gemini.streamToString('Summarise the SOLID principles');
```

---

## Overriding config per call

Pass `overrideConfig` to change settings for a single call without modifying the instance.

```dart
final creative = await gemini.sendMessage(
  'Write a poem about the ocean',
  overrideConfig: const GeminiConfig(
    model: 'gemini-1.5-pro',
    temperature: 1.4,
    maxOutputTokens: 512,
  ),
);
```

---

## Available models

| Model ID | Notes |
|----------|-------|
| `gemini-2.5-flash` | Stable, fast — **recommended default** |
| `gemini-2.5-flash-lite` | Lighter, lower cost |
| `gemini-2.5-pro` | Most capable, higher latency |
| `gemini-3.5-flash` | Newer, still maturing |
| `gemini-flash-latest` | Always points to the latest flash model |

Check [Google AI docs](https://ai.google.dev/gemini-api/docs/models) for the latest list.

---

## API reference

### `GeminiService`

| Member | Description |
|--------|-------------|
| `GeminiService(apiKey:, config:)` | Constructor — one instance per app |
| `sendMessage(prompt)` | Single-turn — returns `GeminiResponse` |
| `sendChat(history)` | Multi-turn — returns `GeminiResponse` |
| `streamMessage(prompt)` | Streaming — returns `Stream<GeminiChunk>` |
| `streamChat(history)` | Streaming multi-turn — returns `Stream<GeminiChunk>` |
| `streamToString(prompt)` | Streaming but resolves to a single `String` |
| `dispose()` | Close the HTTP client |

### `GeminiConfig`

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `model` | `String` | `'gemini-2.0-flash'` | Model ID |
| `systemInstruction` | `String?` | null | Global system prompt |
| `temperature` | `double?` | null | Sampling temperature (0.0–2.0) |
| `topP` | `double?` | null | Nucleus sampling |
| `topK` | `int?` | null | Top-k sampling |
| `maxOutputTokens` | `int?` | null | Max tokens in reply |
| `stopSequences` | `List<String>?` | null | Stop generation at these strings |

### Models

| Class | Key fields |
|-------|-----------|
| `ChatMessage` | `role` (`'user'`/`'model'`), `text` |
| `GeminiResponse` | `text`, `finishReason`, `isComplete`, `totalTokenCount` |
| `GeminiChunk` | `text`, `isDone` |

### Exceptions

| Exception | When thrown |
|-----------|------------|
| `GeminiApiException` | Non-2xx API response (`message`, `statusCode`, `hint`) |
| `GeminiParseException` | Response body could not be decoded |
| `GeminiStreamException` | Streaming connection failed |

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `GeminiApiException [403]` | API key is wrong or not enabled for Gemini API |
| `GeminiApiException [429]` | Rate limit hit — add retry with backoff or upgrade quota |
| Response cuts off early | Increase `maxOutputTokens` in `GeminiConfig` |
| Stream never emits chunks | Make sure you `await for` the stream — don't forget `await` |
| `Bad state: Stream already listened to` | Create a new `streamMessage()` call per request — don't reuse the stream |
