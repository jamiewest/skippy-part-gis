import 'dart:convert';

import 'package:extensions/ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation_models/testing.dart';
import 'package:riverside_atlas/data/services/assistant/apple_assistant_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FoundationModelsBindings original;
  late _Host host;

  setUp(() {
    original = FoundationModelsBindings.instance;
    host = _Host();
    FoundationModelsBindings.instance = FoundationModelsBindings(
      host: host,
      platform: _Platform(),
      registerCallbacks: false,
    );
  });
  tearDown(() => FoundationModelsBindings.instance = original);

  test(
    'native tool calls preserve arguments, results and session history',
    () async {
      final calls = <Map<String, Object?>>[];
      final backend = AppleAssistantBackend(
        instructions: 'Use the map tools.',
        tools: [
          AIFunctionFactory.create(
            name: 'census',
            description: 'Reads published Census figures.',
            parametersSchema: const {
              'type': 'object',
              'properties': {
                'tract': {'type': 'string'},
              },
              'required': ['tract'],
            },
            callback: (arguments, {cancellationToken}) async {
              calls.add(Map.of(arguments));
              return {'population': 42, 'wholeTracts': true};
            },
          ),
        ],
      );
      expect(await backend.checkAvailability(), isNull);
      expect(await backend.respond('Population?').join(), '42 people.');
      expect(await backend.respond('And households?').join(), '42 people.');
      expect(calls, [
        {'tract': '06065000100'},
        {'tract': '06065000100'},
      ]);
      expect(host.sessions, hasLength(1));
      expect(host.sessions.single.model.kind, ModelKindMessage.system);
      expect(jsonDecode(host.toolResult!.contentJson!), {
        'population': 42,
        'wholeTracts': true,
      });
      final schema = jsonDecode(
        host.sessions.single.tools.single.parametersJson,
      );
      expect(schema['required'], ['tract']);
      await backend.reset();
      expect(host.released, [1]);
      await backend.respond('New question').drain<void>();
      expect(host.sessions, hasLength(2));
      await backend.dispose();
      expect(host.released, [1, 2]);
    },
  );

  test(
    'explains disabled Apple Intelligence and never falls back to cloud',
    () async {
      host.status = AvailabilityStatusMessage.appleIntelligenceNotEnabled;
      final backend = AppleAssistantBackend(instructions: '', tools: []);
      expect(
        await backend.checkAvailability(),
        contains('Turn on Apple Intelligence'),
      );
      expect(host.sessions, isEmpty);
      await backend.dispose();
    },
  );

  test('cloud selection explicitly creates a cloud model', () async {
    final backend = AppleAssistantBackend(
      instructions: '',
      tools: [],
      cloud: true,
    );
    await backend.respond('Hello').drain<void>();
    expect(
      host.sessions.single.model.kind,
      ModelKindMessage.privateCloudCompute,
    );
    await backend.dispose();
  });
}

class _Platform extends FoundationModelsPlatformApi {
  @override
  Future<bool> isSupported() async => true;
  @override
  Future<bool> isVersion27Supported() async => true;
}

class _Host extends FoundationModelsHostApi {
  final sessions = <SessionConfigMessage>[];
  final released = <int>[];
  AvailabilityStatusMessage status = AvailabilityStatusMessage.available;
  ToolResultMessage? toolResult;

  @override
  Future<AvailabilityMessage> availability(ModelConfigMessage model) async =>
      AvailabilityMessage(status: status);
  @override
  Future<int> createSession(SessionConfigMessage config) async {
    sessions.add(config);
    return sessions.length;
  }

  @override
  Future<void> release(int handle) async => released.add(handle);
  @override
  Future<void> cancelRequest(int requestId) async {}
  @override
  Future<void> startStream(RespondRequestMessage request) async {
    final callbacks = FoundationModelsBindings.instance.callbackHandler;
    if (sessions.last.tools.isNotEmpty) {
      toolResult = await callbacks.callTool(
        ToolCallRequestMessage(
          sessionHandle: request.sessionHandle,
          toolName: 'census',
          argumentsJson: '{"tract":"06065000100"}',
        ),
      );
    }
    final usage = UsageMessage(
      inputTokens: 1,
      cachedInputTokens: 0,
      outputTokens: 2,
      reasoningTokens: 0,
    );
    callbacks.onStreamSnapshot(
      StreamSnapshotMessage(
        requestId: request.requestId,
        text: '42',
        isComplete: false,
        usage: usage,
      ),
    );
    callbacks.onStreamSnapshot(
      StreamSnapshotMessage(
        requestId: request.requestId,
        text: '42 people.',
        isComplete: true,
        usage: usage,
      ),
    );
    callbacks.onStreamDone(
      request.requestId,
      ResponseMessage(
        text: '42 people.',
        isComplete: true,
        entries: [],
        usage: usage,
      ),
    );
  }
}
