import 'dart:async';
import 'dart:convert';

import 'package:extensions/ai.dart';
import 'package:extensions/configuration.dart';
import 'package:extensions/dependency_injection.dart';
import 'package:extensions/system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:riverside_atlas/app/atlas_assistant.dart';
import 'package:riverside_atlas/data/services/assistant/assistant_backend.dart';
import 'package:riverside_atlas/data/services/census_service.dart';
import 'package:riverside_atlas/domain/models/assistant_settings.dart';
import 'package:riverside_atlas/ui/features/map/view_models/map_assistant.dart';

http.Response answer(List<Object?> parts, {String finishReason = 'STOP'}) =>
    http.Response(
      jsonEncode({
        'candidates': [
          {
            'finishReason': finishReason,
            'content': {'role': 'model', 'parts': parts},
          },
        ],
      }),
      200,
    );

void main() {
  AssistantBackend backend(
    http.Client client, {
    List<AITool> tools = const [],
  }) {
    addTearDown(client.close);
    final result = buildAssistantBackend(
      settings: const AssistantSettings(
        provider: AssistantProvider.gemini,
        apiKey: ' gemini-test ',
        model: ' chosen-model ',
      ),
      client: client,
      tools: tools,
    );
    addTearDown(result.dispose);
    return result;
  }

  test(
    'Gemini calls tools and preserves signatures, follow-ups and reset',
    () async {
      final requests = <Map<String, dynamic>>[];
      var toolCalls = 0;
      final toolPart = {
        'functionCall': {
          'name': 'describe_map',
          'id': 'call-1',
          'args': {'detail': true},
        },
        'thoughtSignature': 'opaque-signature',
      };
      final client = MockClient((request) async {
        expect(
          request.url.toString(),
          'https://generativelanguage.googleapis.com/v1beta/models/chosen-model:generateContent',
        );
        expect(request.headers['x-goog-api-key'], 'gemini-test');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        requests.add(body);
        expect(
          body['systemInstruction']['parts'][0]['text'],
          contains('Call describe_map'),
        );
        final declaration = body['tools'][0]['functionDeclarations'][0];
        expect(declaration['name'], 'describe_map');
        expect(
          declaration['parametersJsonSchema']['properties']['detail']['type'],
          'boolean',
        );
        return requests.length == 1
            ? answer([toolPart])
            : answer([
                {'text': 'internal summary', 'thought': true},
                {'text': 'Riverside County.'},
              ]);
      });
      final assistant = backend(
        client,
        tools: [
          AIFunctionFactory.create(
            name: 'describe_map',
            parametersSchema: {
              'type': 'object',
              'properties': {
                'detail': {'type': 'boolean'},
              },
            },
            callback:
                (arguments, {CancellationToken? cancellationToken}) async {
                  expect(arguments['detail'], isTrue);
                  toolCalls++;
                  return {'county': 'Riverside'};
                },
          ),
        ],
      );
      expect(assistant.label, 'Google Gemini');
      expect(await assistant.checkAvailability(), isNull);
      expect(
        await assistant.respond('where am I?').join(),
        'Riverside County.',
      );
      expect(toolCalls, 1);
      final contents = requests[1]['contents'] as List;
      expect(contents[1]['parts'], [toolPart]);
      expect(contents.last['parts'][0]['functionResponse'], {
        'name': 'describe_map',
        'id': 'call-1',
        'response': {'county': 'Riverside'},
      });
      await assistant.respond('and now?').drain<void>();
      expect((requests.last['contents'] as List).length, 5);
      await assistant.reset();
      await assistant.respond('new conversation').drain<void>();
      expect((requests.last['contents'] as List).length, 1);
    },
  );

  test(
    'returns multiple tool results, including errors, in one turn',
    () async {
      var requests = 0;
      final assistant = backend(
        MockClient((request) async {
          requests++;
          if (requests == 1) {
            return answer([
              for (final name in ['list_items', 'missing_tool', 'failed_tool'])
                {
                  'functionCall': {'name': name},
                },
            ]);
          }
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final results = body['contents'].last['parts'] as List;
          expect(results, hasLength(3));
          expect(results[0]['functionResponse']['response'], {
            'result': [1, 2],
          });
          expect(
            results[1]['functionResponse']['response']['error'],
            contains('Unknown map tool'),
          );
          expect(
            results[2]['functionResponse']['response']['error'],
            contains('tool failed'),
          );
          return answer([
            {'text': 'Done.'},
          ]);
        }),
        tools: [
          AIFunctionFactory.create(
            name: 'list_items',
            callback:
                (arguments, {CancellationToken? cancellationToken}) async => [
                  1,
                  2,
                ],
          ),
          AIFunctionFactory.create(
            name: 'failed_tool',
            callback:
                (arguments, {CancellationToken? cancellationToken}) async =>
                    throw StateError('tool failed'),
          ),
        ],
      );
      expect(await assistant.respond('run tools').join(), 'Done.');
      expect(requests, 2);
    },
  );

  for (final status in [400, 401, 403, 404, 429, 500]) {
    test('HTTP $status gives a safe, actionable error', () async {
      final assistant = backend(
        MockClient((_) async => http.Response('sensitive detail', status)),
      );
      await expectLater(
        assistant.respond('hello').drain<void>(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            allOf(
              contains(
                status == 429
                    ? 'quota'
                    : status == 500
                    ? 'retry'
                    : 'AI provider settings',
              ),
              isNot(contains('sensitive detail')),
            ),
          ),
        ),
      );
    });
  }

  for (final invalid in [
    http.Response('{"promptFeedback":{"blockReason":"SAFETY"}}', 200),
    answer([
      {'text': 'partial answer'},
    ], finishReason: 'MAX_TOKENS'),
    answer([]),
    answer([
      {'text': 'only thinking', 'thought': true},
    ]),
  ]) {
    test('incomplete responses do not become conversation history', () async {
      var requests = 0;
      final assistant = backend(
        MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body.containsKey('tools'), isFalse);
          expect(body['contents'], hasLength(1));
          return requests++ == 0
              ? invalid
              : answer([
                  {'text': 'Recovered.'},
                ]);
        }),
      );
      await expectLater(
        assistant.respond('hello').drain<void>(),
        throwsStateError,
      );
      expect(await assistant.respond('retry').join(), 'Recovered.');
    });
  }

  test('limits repeated tool calls', () async {
    var requests = 0;
    final assistant = backend(
      MockClient((_) async {
        requests++;
        return answer([
          {
            'functionCall': {'name': 'missing_tool'},
          },
        ]);
      }),
    );
    await expectLater(
      assistant.respond('hello').drain<void>(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('tool limit'),
        ),
      ),
    );
    expect(requests, 12);
  });

  test(
    'disposal ignores pending responses and prevents further requests',
    () async {
      final pending = Completer<http.Response>();
      final started = Completer<void>();
      var requests = 0;
      final assistant = backend(
        MockClient((_) {
          requests++;
          started.complete();
          return pending.future;
        }),
      );
      final response = assistant.respond('hello').join();
      await started.future;
      await assistant.dispose();
      pending.complete(
        answer([
          {'text': 'late answer'},
        ]),
      );
      expect(await response, isEmpty);
      expect(await assistant.respond('again').join(), isEmpty);
      expect(requests, 1);
    },
  );

  for (final provider in ['gemini', 'auto']) {
    test('startup selects Gemini with $provider configuration', () async {
      final configuration =
          (ConfigurationBuilder()..addInMemoryCollection(
                {
                  'ASSISTANT_PROVIDER': provider,
                  'GEMINI_API_KEY': ' configured-key ',
                  'ASSISTANT_MODEL': 'configured-model',
                }.entries,
              ))
              .build();
      final client = MockClient(
        (_) async => throw StateError('must not request'),
      );
      addTearDown(client.close);
      final services =
          (ServiceCollection()
                ..addSingleton<http.Client>((_) => client)
                ..addSingleton<CensusService>((_) => CensusService(client))
                ..addMapAssistant(configuration: configuration))
              .buildServiceProvider();
      final assistant = services.getRequiredService<MapAssistant>();
      addTearDown(assistant.dispose);
      expect(assistant.settings!.provider, AssistantProvider.gemini);
      expect(assistant.settings!.apiKey, 'configured-key');
      expect(assistant.settings!.effectiveModel, 'configured-model');
    });
  }
}
