import 'package:flutter_test/flutter_test.dart';
import 'package:gemini_flutter/gemini_flutter.dart';

void main() {
  group('ChatMessage', () {
    test('user factory sets correct role', () {
      const msg = ChatMessage.user('Hello');
      expect(msg.role, 'user');
      expect(msg.text, 'Hello');
    });

    test('model factory sets correct role', () {
      const msg = ChatMessage.model('Hi there');
      expect(msg.role, 'model');
      expect(msg.text, 'Hi there');
    });

    test('toJson produces correct structure', () {
      const msg = ChatMessage.user('Test');
      final json = msg.toJson();
      expect(json['role'], 'user');
      expect((json['parts'] as List).first['text'], 'Test');
    });

    test('fromJson round-trips correctly', () {
      const original = ChatMessage.model('Response');
      final json = original.toJson();
      final restored = ChatMessage.fromJson(json);
      expect(restored.role, original.role);
      expect(restored.text, original.text);
    });
  });

  group('GeminiConfig', () {
    test('toGenerationConfig omits nulls', () {
      const config = GeminiConfig();
      expect(config.toGenerationConfig(), isEmpty);
    });

    test('toGenerationConfig includes set values', () {
      const config = GeminiConfig(temperature: 0.5, maxOutputTokens: 512);
      final gen = config.toGenerationConfig();
      expect(gen['temperature'], 0.5);
      expect(gen['maxOutputTokens'], 512);
    });
  });

  group('GeminiResponse', () {
    test('fromJson parses correctly', () {
      final json = {
        'candidates': [
          {
            'content': {
              'role': 'model',
              'parts': [
                {'text': 'Hello world'}
              ],
            },
            'finishReason': 'STOP',
          }
        ],
        'usageMetadata': {
          'promptTokenCount': 10,
          'candidatesTokenCount': 5,
          'totalTokenCount': 15,
        },
      };

      final response = GeminiResponse.fromJson(json);
      expect(response.text, 'Hello world');
      expect(response.finishReason, 'STOP');
      expect(response.isComplete, isTrue);
      expect(response.totalTokenCount, 15);
    });
  });

  group('GeminiApiException', () {
    test('hint returns correct string for 403', () {
      const e = GeminiApiException('Forbidden', statusCode: 403);
      expect(e.hint, contains('API key'));
    });

    test('hint returns correct string for 429', () {
      const e = GeminiApiException('Too many requests', statusCode: 429);
      expect(e.hint, contains('Rate limit'));
    });

    test('toString includes status code', () {
      const e = GeminiApiException('Bad request', statusCode: 400);
      expect(e.toString(), contains('400'));
    });
  });
}
