import 'dart:async';

import 'package:agents/agents.dart';
import 'package:extensions/ai.dart';
import 'package:extensions/system.dart';
import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverside_atlas/ui/features/map/view_models/map_assistant.dart';
import 'package:riverside_atlas/ui/features/map/view_models/assistant_dictation.dart';
import 'package:riverside_atlas/data/services/assistant/assistant_backend.dart';
import 'package:riverside_atlas/ui/features/map/widgets/assistant_panel.dart';

void main() {
  group('MapAssistant', () {
    test(
      'automatically supplies current discovery before every answer',
      () async {
        final agent = _FakeAgent(['Found a candidate.']);
        var focus = 'first area';
        final assistant = MapAssistant(
          agent: agent,
          prepareContext: () async =>
              'Parcel outline and owner samples for $focus',
        );
        addTearDown(assistant.dispose);
        await assistant.send('what is here?');
        focus = 'second area';
        await assistant.send('and here?');
        expect(agent.questions.first, contains('samples for first area'));
        expect(agent.questions.last, contains('samples for second area'));
        expect(assistant.messages.first.text, 'what is here?');
      },
    );

    test('discovery failure does not prevent an assistant response', () async {
      final agent = _FakeAgent(['Source unavailable.']);
      final assistant = MapAssistant(
        agent: agent,
        prepareContext: () async => throw StateError('offline'),
      );
      addTearDown(assistant.dispose);
      await assistant.send('what is here?');
      expect(agent.questions.single, contains('discovery is unavailable'));
      expect(assistant.messages.last.text, 'Source unavailable.');
    });

    test('streams an answer into the transcript as it arrives', () async {
      final assistant = MapAssistant(agent: _FakeAgent(['Denver ', 'County.']));
      addTearDown(assistant.dispose);

      await assistant.send('where am I?');

      check(assistant.messages).length.equals(2);
      check(assistant.messages.first.role).equals(AssistantRole.user);
      check(assistant.messages.first.text).equals('where am I?');
      check(assistant.messages.last.role).equals(AssistantRole.assistant);
      check(assistant.messages.last.text).equals('Denver County.');
      check(assistant.isThinking).isFalse();
    });

    test('reuses one session so a follow-up has the earlier turn', () async {
      final agent = _FakeAgent(['ok']);
      final assistant = MapAssistant(agent: agent);
      addTearDown(assistant.dispose);

      await assistant.send('first');
      await assistant.send('second');

      check(agent.sessionsCreated).equals(1);
      check(agent.questions).deepEquals(['first', 'second']);
    });

    test('shows a failure in place of the answer, not a blank line', () async {
      final assistant = MapAssistant(agent: _FakeAgent.failing());
      addTearDown(assistant.dispose);

      await assistant.send('anything');

      check(assistant.messages.last.role).equals(AssistantRole.error);
      check(assistant.messages.last.text).contains('could not answer');
      check(assistant.isThinking).isFalse();
    });

    test('says an empty answer is empty rather than showing nothing', () async {
      final assistant = MapAssistant(agent: _FakeAgent(const []));
      addTearDown(assistant.dispose);

      await assistant.send('anything');

      check(assistant.messages.last.text).equals('No answer came back.');
    });

    test('starts a new conversation when cleared', () async {
      final agent = _FakeAgent(['ok']);
      final assistant = MapAssistant(agent: agent);
      addTearDown(assistant.dispose);

      await assistant.send('first');
      assistant.clear();
      await assistant.send('second');

      check(assistant.messages).length.equals(2);
      check(agent.sessionsCreated).equals(2);
    });

    test('ignores an empty question', () async {
      final assistant = MapAssistant(agent: _FakeAgent(['ok']));
      addTearDown(assistant.dispose);

      await assistant.send('   ');

      check(assistant.messages).isEmpty();
    });

    test('answers nothing at all when no key configured one', () async {
      final assistant = MapAssistant(unavailableReason: 'No key.');
      addTearDown(assistant.dispose);

      await assistant.send('anything');

      check(assistant.available).isFalse();
      check(assistant.messages).isEmpty();
    });
  });

  group('AssistantPanel', () {
    testWidgets('dictates into the draft and sends only after review', (
      tester,
    ) async {
      final agent = _FakeAgent(['Two tracts.']);
      final assistant = MapAssistant(agent: agent);
      final dictation = _Dictation();
      addTearDown(assistant.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: AssistantPanel(
            assistant: assistant,
            dictation: dictation,
            onClose: () {},
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('assistant-input')),
        'Please',
      );
      await tester.tap(find.byKey(const Key('assistant-microphone-button')));
      dictation.words('show population here');
      await tester.pump();
      expect(find.text('Please show population here'), findsOneWidget);
      expect(agent.questions, isEmpty);
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('assistant-send-button')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const Key('assistant-microphone-button')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('assistant-send-button')));
      await tester.pumpAndSettle();
      expect(agent.questions, ['Please show population here']);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(dictation.disposed, isTrue);
    });

    testWidgets('blocks input until native readiness is known', (tester) async {
      final backend = _PendingBackend();
      final assistant = MapAssistant.withBackend(backend);
      addTearDown(assistant.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: AssistantPanel(assistant: assistant, onClose: () {}),
        ),
      );
      expect(find.byKey(const Key('assistant-input')), findsNothing);
      backend.ready.complete('Enable Apple Intelligence.');
      await tester.pumpAndSettle();
      expect(find.text('Enable Apple Intelligence.'), findsOneWidget);
      expect(find.text('Retry Apple Intelligence'), findsOneWidget);
    });

    testWidgets('offers no input when the assistant cannot answer', (
      tester,
    ) async {
      final assistant = MapAssistant(
        unavailableReason: 'Set ATLAS_ANTHROPIC_API_KEY.',
      );
      addTearDown(assistant.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: AssistantPanel(assistant: assistant, onClose: () {}),
        ),
      );

      // An input box that cannot send anywhere is worse than an explanation.
      expect(find.byKey(const Key('assistant-input')), findsNothing);
      expect(find.byKey(const Key('assistant-unavailable-reason')), findsOne);
      expect(find.textContaining('ATLAS_ANTHROPIC_API_KEY'), findsOne);
    });

    testWidgets('renders selectable Markdown as answers stream in', (
      tester,
    ) async {
      final assistant = MapAssistant(
        agent: _FakeAgent([
          '## Area summary\n\n**Two',
          ' tracts** with *nearby parcels*.\n\n- First tract\n- Second tract\n\n'
              'Use `parcel_id`.\n\n```text\nSELECT parcels\n```\n\n'
              '| Area | Count |\n| --- | --- |\n| North | 2 |\n\n'
              '[Source](https://example.com)',
        ]),
      );
      addTearDown(assistant.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 390,
                child: AssistantPanel(assistant: assistant, onClose: () {}),
              ),
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('assistant-input')),
        'Summarize',
      );
      await tester.tap(find.byKey(const Key('assistant-send-button')));
      await tester.pumpAndSettle();
      final markdown = tester.widgetList<MarkdownBody>(
        find.byType(MarkdownBody),
      );
      expect(markdown.length, 2);
      expect(markdown.every((body) => body.selectable), isTrue);
      expect(find.text('Area summary', findRichText: true), findsOneWidget);
      expect(
        find.text('Two tracts with nearby parcels.', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('First tract', findRichText: true), findsOneWidget);
      expect(
        find.textContaining('SELECT parcels', findRichText: true),
        findsOneWidget,
      );
      expect(find.byType(Table), findsOneWidget);
      expect(find.text('Source', findRichText: true), findsOneWidget);
      expect(find.textContaining('**Two tracts**'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows the conversation and takes another question', (
      tester,
    ) async {
      final assistant = MapAssistant(agent: _FakeAgent(['Two tracts.']));
      addTearDown(assistant.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: AssistantPanel(assistant: assistant, onClose: () {}),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('assistant-input')),
        'demographics here?',
      );
      await tester.tap(find.byKey(const Key('assistant-send-button')));
      await tester.pumpAndSettle();

      expect(find.text('demographics here?'), findsOne);
      expect(find.text('Two tracts.'), findsOne);
    });
  });
}

/// An agent that replays fixed chunks, or fails.
final class _FakeAgent extends AIAgent {
  _FakeAgent(this.chunks) : _fails = false;

  _FakeAgent.failing() : chunks = const [], _fails = true;

  final List<String> chunks;
  final bool _fails;
  final List<String> questions = [];
  int sessionsCreated = 0;

  @override
  Future<AgentSession> createSessionCore({
    CancellationToken? cancellationToken,
  }) async {
    sessionsCreated++;
    return _FakeSession();
  }

  @override
  Stream<AgentResponseUpdate> runCoreStreaming(
    Iterable<ChatMessage> messages, {
    AgentSession? session,
    AgentRunOptions? options,
    CancellationToken? cancellationToken,
  }) async* {
    questions.add(messages.last.text);
    if (_fails) {
      throw StateError('the provider refused');
    }
    for (final chunk in chunks) {
      yield AgentResponseUpdate(
        role: ChatRole.assistant,
        contents: [TextContent(chunk)],
      );
    }
  }

  @override
  Future<AgentResponse> runCore(
    Iterable<ChatMessage> messages, {
    AgentSession? session,
    AgentRunOptions? options,
    CancellationToken? cancellationToken,
  }) async => AgentResponse(messages: const []);

  @override
  Future<dynamic> serializeSessionCore(
    AgentSession session, {
    Object? jsonSerializerOptions,
    CancellationToken? cancellationToken,
  }) async => const <String, Object?>{};

  @override
  Future<AgentSession> deserializeSessionCore(
    dynamic serializedSession, {
    Object? jsonSerializerOptions,
    CancellationToken? cancellationToken,
  }) async => _FakeSession();
}

final class _FakeSession extends AgentSession {}

class _Dictation extends AssistantDictation {
  bool active = false;
  bool disposed = false;
  String wordsSoFar = '';
  @override
  bool get supported => true;
  @override
  bool get listening => active;
  @override
  String get text => wordsSoFar;
  @override
  Future<void> start() async {
    active = true;
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    active = false;
    notifyListeners();
  }

  void words(String value) {
    wordsSoFar = value;
    notifyListeners();
  }

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

class _PendingBackend implements AssistantBackend {
  final ready = Completer<String?>();
  @override
  String get label => 'Apple';
  @override
  Future<String?> checkAvailability() => ready.future;
  @override
  Stream<String> respond(String question) => const Stream.empty();
  @override
  Future<void> reset() async {}
  @override
  Future<void> dispose() async {}
}
