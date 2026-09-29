import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverside_atlas/data/services/assistant/assistant_backend.dart';
import 'package:riverside_atlas/domain/models/assistant_settings.dart';
import 'package:riverside_atlas/ui/features/map/view_models/map_assistant.dart';
import 'package:riverside_atlas/ui/features/map/widgets/assistant_panel.dart';

void main() {
  testWidgets(
    'selects all providers and applies separate keys without build arguments',
    (tester) async {
      final backends = <_Backend>[];
      final assistant = MapAssistant.configurable(
        settings: const AssistantSettings(
          provider: AssistantProvider.anthropic,
        ),
        backendFactory: (settings) {
          final backend = _Backend(settings.provider.label);
          backends.add(backend);
          return backend;
        },
      );
      addTearDown(assistant.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 320,
              child: AssistantPanel(assistant: assistant, onClose: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> select(String provider) async {
        await tester.tap(
          find.byType(DropdownButtonFormField<AssistantProvider>),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(provider).last);
        await tester.pumpAndSettle();
      }

      await tester.tap(find.byKey(const Key('assistant-settings-button')));
      await tester.pumpAndSettle();
      final keyField = find.byKey(const Key('assistant-api-key'));
      expect(tester.widget<TextField>(keyField).obscureText, isTrue);
      await tester.enterText(keyField, 'anthropic-test-key');
      await tester.tap(find.byKey(const Key('assistant-apply-settings')));
      await tester.pumpAndSettle();
      await tester.runAsync(() => assistant.send('first provider'));
      await tester.pumpAndSettle();

      expect(assistant.isThinking, isFalse);
      expect(assistant.messages.last.text, 'answer');
      await select('OpenAI');
      expect(assistant.messages, isEmpty);
      expect(backends[1].disposed, isTrue);
      await tester.tap(find.byKey(const Key('assistant-settings-button')));
      await tester.pumpAndSettle();
      await tester.enterText(keyField, 'openai-test-key');
      await tester.enterText(
        find.byKey(const Key('assistant-model')),
        'custom-model',
      );
      await tester.tap(find.byKey(const Key('assistant-apply-settings')));
      await tester.pumpAndSettle();
      expect(assistant.settings!.apiKey, 'openai-test-key');
      expect(assistant.settings!.effectiveModel, 'custom-model');

      await select('Google Gemini');
      expect(assistant.settings!.effectiveModel, 'gemini-3.8-flash');
      await tester.tap(find.byKey(const Key('assistant-settings-button')));
      await tester.pumpAndSettle();
      expect(find.text('Google Gemini API key'), findsOneWidget);
      expect(tester.widget<TextField>(keyField).obscureText, isTrue);
      await tester.enterText(keyField, 'gemini-test-key');
      await tester.enterText(
        find.byKey(const Key('assistant-model')),
        'custom-gemini-model',
      );
      await tester.tap(find.byKey(const Key('assistant-apply-settings')));
      await tester.pumpAndSettle();

      await select('Apple');
      await tester.tap(find.byKey(const Key('assistant-settings-button')));
      await tester.pumpAndSettle();
      expect(keyField, findsNothing);
      expect(find.textContaining('No API key'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await select('Anthropic');
      expect(assistant.settings!.apiKey, 'anthropic-test-key');
      await select('OpenAI');
      expect(assistant.settings!.apiKey, 'openai-test-key');
      expect(assistant.settings!.effectiveModel, 'custom-model');
      expect(tester.takeException(), isNull);
      await select('Google Gemini');
      expect(assistant.settings!.apiKey, 'gemini-test-key');
      expect(assistant.settings!.effectiveModel, 'custom-gemini-model');
    },
  );

  test('ignores readiness from a provider that was replaced', () async {
    final oldReady = Completer<String?>();
    final assistant = MapAssistant.configurable(
      settings: const AssistantSettings(provider: AssistantProvider.apple),
      backendFactory: (settings) => _Backend(
        settings.provider.label,
        readiness: settings.provider == AssistantProvider.apple
            ? oldReady.future
            : null,
      ),
    );
    addTearDown(assistant.dispose);
    await assistant.configure(
      const AssistantSettings(provider: AssistantProvider.openai),
    );
    oldReady.complete('Old provider unavailable');
    await Future<void>.delayed(Duration.zero);
    expect(assistant.providerLabel, 'OpenAI');
    expect(assistant.available, isTrue);
    expect(assistant.unavailableReason, isNull);
  });

  test('does not switch providers during an answer', () async {
    final chunks = StreamController<String>();
    final assistant = MapAssistant.configurable(
      settings: const AssistantSettings(provider: AssistantProvider.anthropic),
      backendFactory: (settings) =>
          _Backend(settings.provider.label, chunks: chunks.stream),
    );
    addTearDown(assistant.dispose);
    await Future<void>.delayed(Duration.zero);
    final sending = assistant.send('question');
    await assistant.configure(
      const AssistantSettings(provider: AssistantProvider.openai),
    );
    expect(assistant.settings!.provider, AssistantProvider.anthropic);
    chunks.add('answer');
    await chunks.close();
    await sending;
    expect(assistant.messages.last.text, 'answer');
  });
}

class _Backend implements AssistantBackend {
  _Backend(this.label, {this.readiness, this.chunks});
  @override
  final String label;
  final Future<String?>? readiness;
  final Stream<String>? chunks;
  bool disposed = false;
  @override
  Future<String?> checkAvailability() => readiness ?? Future.value();
  @override
  Stream<String> respond(String question) async* {
    if (chunks case final stream?) {
      yield* stream;
    } else {
      yield 'answer';
    }
  }

  @override
  Future<void> reset() async {}
  @override
  Future<void> dispose() async {
    disposed = true;
  }
}
