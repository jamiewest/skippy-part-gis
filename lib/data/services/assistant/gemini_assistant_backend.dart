import 'dart:convert';

import 'package:extensions/ai.dart';
import 'package:http/http.dart' as http;
import 'package:riverside_atlas/data/services/assistant/assistant_backend.dart';

/// Runs the shared map functions through Gemini's generateContent tool loop.
final class GeminiAssistantBackend implements AssistantBackend {
  GeminiAssistantBackend({
    required this.client,
    required this.apiKey,
    required this.model,
    required this.instructions,
    required List<AITool> tools,
  }) : _tools = {
         for (final tool in tools.whereType<AIFunction>()) tool.name: tool,
       };

  final http.Client client;
  final String apiKey;
  final String model;
  final String instructions;
  final Map<String, AIFunction> _tools;
  final List<Object?> _history = [];
  bool _disposed = false;

  @override
  String get label => 'Google Gemini';

  @override
  Future<String?> checkAvailability() async => null;

  @override
  Stream<String> respond(String question) async* {
    final contents = <Object?>[
      ..._history,
      {
        'role': 'user',
        'parts': [
          {'text': question},
        ],
      },
    ];
    for (var round = 0; round < 12 && !_disposed; round++) {
      final response = await client
          .post(
            Uri.https(
              'generativelanguage.googleapis.com',
              '/v1beta/models/$model:generateContent',
            ),
            headers: {
              'x-goog-api-key': apiKey,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'systemInstruction': {
                'parts': [
                  {'text': instructions},
                ],
              },
              'contents': contents,
              if (_tools.isNotEmpty)
                'tools': [
                  {
                    'functionDeclarations': [
                      for (final tool in _tools.values)
                        {
                          'name': tool.name,
                          'description': tool.description ?? '',
                          if (tool.parametersSchema != null)
                            'parametersJsonSchema': tool.parametersSchema,
                        },
                    ],
                  },
                ],
            }),
          )
          .timeout(const Duration(seconds: 90));
      if (_disposed) return;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(switch (response.statusCode) {
          400 || 401 || 403 || 404 =>
            'Google Gemini could not accept the request. Check the API key '
                'and model in AI provider settings.',
          429 =>
            'Google Gemini reached a rate or usage limit. Check your API quota '
                'and retry.',
          _ =>
            'Google Gemini request failed (HTTP ${response.statusCode}). '
                'Please retry.',
        });
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = body['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw StateError(
          'Google Gemini did not return an answer. Please retry.',
        );
      }
      final candidate = candidates.first as Map<String, dynamic>;
      if (candidate['finishReason'] != 'STOP') {
        throw StateError(
          'Google Gemini did not complete the response. Please retry.',
        );
      }
      final content = candidate['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List?;
      if (parts == null || parts.isEmpty) {
        throw StateError(
          'Google Gemini did not return an answer. Please retry.',
        );
      }
      // Preserve the complete model content, including thought signatures,
      // so subsequent tool results and conversation turns remain valid.
      contents.add(content);
      final results = <Object?>[];
      var hasText = false;
      for (final part in parts.cast<Map<String, dynamic>>()) {
        if (_disposed) return;
        final call = part['functionCall'] as Map<String, dynamic>?;
        if (call != null) {
          Object? result;
          try {
            final tool = _tools[call['name']];
            if (tool == null) throw StateError('Unknown map tool');
            final arguments = call['args'] as Map<String, dynamic>? ?? {};
            result = await tool.invoke(AIFunctionArguments(arguments));
          } on Object catch (error) {
            result = {'error': error.toString()};
          }
          if (_disposed) return;
          results.add({
            'functionResponse': {
              'name': call['name'],
              if (call['id'] != null) 'id': call['id'],
              'response': result is Map ? result : {'result': result},
            },
          });
        } else if (part['thought'] != true && part['text'] is String) {
          final text = part['text'] as String;
          if (text.trim().isNotEmpty) {
            hasText = true;
            yield text;
          }
        }
      }
      if (_disposed) return;
      if (results.isEmpty) {
        if (!hasText) {
          throw StateError(
            'Google Gemini did not return an answer. Please retry.',
          );
        }
        _history
          ..clear()
          ..addAll(contents);
        return;
      }
      contents.add({'role': 'user', 'parts': results});
    }
    if (!_disposed) {
      throw StateError(
        'Google Gemini reached the map tool limit. Try a smaller request.',
      );
    }
  }

  @override
  Future<void> reset() async => _history.clear();

  @override
  Future<void> dispose() async {
    _disposed = true;
    await reset();
  }
}
