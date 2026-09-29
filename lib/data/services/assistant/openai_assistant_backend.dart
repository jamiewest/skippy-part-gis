import 'dart:convert';

import 'package:extensions/ai.dart';
import 'package:http/http.dart' as http;
import 'package:riverside_atlas/data/services/assistant/assistant_backend.dart';

/// Runs the shared map functions through the OpenAI Responses tool loop.
final class OpenAIAssistantBackend implements AssistantBackend {
  OpenAIAssistantBackend({
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
  String get label => 'OpenAI';

  @override
  Future<String?> checkAvailability() async => null;

  @override
  Stream<String> respond(String question) async* {
    final input = <Object?>[
      ..._history,
      {'role': 'user', 'content': question},
    ];
    for (var round = 0; round < 12 && !_disposed; round++) {
      final response = await client
          .post(
            Uri.parse('https://api.openai.com/v1/responses'),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': model,
              'instructions': instructions,
              'store': false,
              'include': ['reasoning.encrypted_content'],
              'input': input,
              'tools': [
                for (final tool in _tools.values)
                  {
                    'type': 'function',
                    'name': tool.name,
                    'description': tool.description ?? '',
                    'strict': false,
                    'parameters':
                        tool.parametersSchema ??
                        {'type': 'object', 'properties': <String, Object?>{}},
                  },
              ],
            }),
          )
          .timeout(const Duration(seconds: 90));
      if (_disposed) return;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(switch (response.statusCode) {
          401 =>
            'OpenAI rejected the API key. Update it in AI provider settings.',
          403 || 404 =>
            'OpenAI could not access this model. Check the model and API key in AI provider settings.',
          429 =>
            'OpenAI reached a rate or usage limit. Check your API quota and retry.',
          _ =>
            'OpenAI request failed (HTTP ${response.statusCode}). Please retry.',
        });
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['status'] != 'completed') {
        throw StateError('OpenAI did not complete the response. Please retry.');
      }
      final output = (body['output'] as List).cast<Map<String, dynamic>>();
      input.addAll(output);
      var calledTool = false;
      for (final item in output) {
        if (_disposed) return;
        if (item['type'] == 'function_call') {
          calledTool = true;
          final tool = _tools[item['name']];
          Object? result;
          try {
            if (tool == null) throw StateError('Unknown map tool');
            final arguments =
                jsonDecode(item['arguments'] as String) as Map<String, dynamic>;
            result = await tool.invoke(AIFunctionArguments(arguments));
          } on Object catch (error) {
            result = {'error': error.toString()};
          }
          input.add({
            'type': 'function_call_output',
            'call_id': item['call_id'],
            'output': jsonEncode(result),
          });
        } else if (item['type'] == 'message') {
          for (final content in item['content'] as List) {
            if (content['type'] == 'output_text') {
              yield content['text'] as String;
            } else if (content['type'] == 'refusal') {
              yield content['refusal'] as String;
            }
          }
        }
      }
      if (!calledTool) {
        _history
          ..clear()
          ..addAll(input);
        return;
      }
    }
    if (!_disposed) {
      throw StateError(
        'OpenAI reached the map tool limit. Try a smaller request.',
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
