import 'dart:convert';

import 'package:extensions/ai.dart';
import 'package:extensions/system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:riverside_atlas/app/atlas_assistant.dart';
import 'package:riverside_atlas/domain/models/assistant_settings.dart';

void main() {
  test(
    'OpenAI calls map tools, carries follow-ups, and resets its session',
    () async {
      final requests = <Map<String, dynamic>>[];
      var toolCalls = 0;
      final client = MockClient((request) async {
        expect(request.url.toString(), 'https://api.openai.com/v1/responses');
        expect(request.headers['Authorization'], 'Bearer openai-test');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        requests.add(body);
        expect(body['model'], 'chosen-model');
        expect(body['store'], isFalse);
        expect(body['instructions'], contains('Call describe_map'));
        expect((body['tools'] as List).single['name'], 'describe_map');
        return http.Response(
          jsonEncode({
            'status': 'completed',
            'output': requests.length == 1
                ? [
                    {
                      'type': 'function_call',
                      'name': 'describe_map',
                      'call_id': 'call-1',
                      'arguments': '{}',
                    },
                  ]
                : [
                    {
                      'type': 'message',
                      'role': 'assistant',
                      'content': [
                        {'type': 'output_text', 'text': 'Riverside County.'},
                      ],
                    },
                  ],
          }),
          200,
        );
      });
      final backend = buildAssistantBackend(
        settings: const AssistantSettings(
          provider: AssistantProvider.openai,
          apiKey: 'openai-test',
          model: 'chosen-model',
        ),
        client: client,
        tools: [
          AIFunctionFactory.create(
            name: 'describe_map',
            callback:
                (arguments, {CancellationToken? cancellationToken}) async {
                  toolCalls++;
                  return {'county': 'Riverside'};
                },
          ),
        ],
      );
      addTearDown(backend.dispose);
      addTearDown(client.close);
      expect(await backend.respond('where am I?').join(), 'Riverside County.');
      expect(toolCalls, 1);
      final toolOutput = (requests[1]['input'] as List).last;
      expect(toolOutput['call_id'], 'call-1');
      expect(jsonDecode(toolOutput['output'] as String), {
        'county': 'Riverside',
      });
      await backend.respond('and now?').drain<void>();
      expect((requests.last['input'] as List).length, 5);
      await backend.reset();
      await backend.respond('new conversation').drain<void>();
      expect((requests.last['input'] as List).length, 1);
    },
  );

  test('keyless cloud providers give in-app setup instructions', () async {
    final client = MockClient(
      (_) async => throw StateError('must not request'),
    );
    addTearDown(client.close);
    for (final provider in [
      AssistantProvider.anthropic,
      AssistantProvider.openai,
      AssistantProvider.gemini,
    ]) {
      final backend = buildAssistantBackend(
        settings: AssistantSettings(provider: provider),
        client: client,
        tools: [],
      );
      expect(
        await backend.checkAvailability(),
        contains('AI provider settings'),
      );
      expect(await backend.checkAvailability(), isNot(contains('dart-define')));
      await backend.dispose();
    }
  });

  test('OpenAI authentication errors direct the user to settings', () async {
    final client = MockClient(
      (_) async => http.Response('sensitive provider detail', 401),
    );
    addTearDown(client.close);
    final backend = buildAssistantBackend(
      settings: const AssistantSettings(
        provider: AssistantProvider.openai,
        apiKey: 'invalid',
      ),
      client: client,
      tools: [],
    );
    addTearDown(backend.dispose);
    await expectLater(
      backend.respond('hello').drain<void>(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('AI provider settings'),
        ),
      ),
    );
  });
}
