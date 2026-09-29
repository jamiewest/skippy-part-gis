import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverside_atlas/data/services/assistant/assistant_backend.dart';
import 'package:riverside_atlas/data/services/assistant_settings_store.dart';
import 'package:riverside_atlas/domain/models/assistant_settings.dart';
import 'package:riverside_atlas/ui/features/map/view_models/map_assistant.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  Future<MapAssistant> launch({AssistantSettingsStore? store}) async {
    final assistant = MapAssistant.configurable(
      settings: const AssistantSettings(provider: AssistantProvider.anthropic),
      presets: const [
        AssistantSettings(provider: AssistantProvider.openai, apiKey: 'preset'),
      ],
      settingsStore: store ?? const AssistantSettingsStore(),
      backendFactory: (_) => _Backend(),
    );
    addTearDown(assistant.dispose);
    final ready = Completer<void>();
    void listener() {
      if (!assistant.isChecking && !ready.isCompleted) ready.complete();
    }

    assistant.addListener(listener);
    await ready.future.timeout(const Duration(seconds: 5));
    assistant.removeListener(listener);
    return assistant;
  }

  test(
    'restores separate keys, models and selected provider after restart',
    () async {
      final first = await launch();
      for (final provider in AssistantProvider.values) {
        await first.configure(
          AssistantSettings(
            provider: provider,
            apiKey: provider == AssistantProvider.apple
                ? ''
                : '${provider.name}-key',
            model: '${provider.name}-model',
            appleCloud: provider == AssistantProvider.apple,
          ),
        );
      }
      final reopened = await launch();
      expect(reopened.settings!.provider, AssistantProvider.apple);
      expect(reopened.settings!.appleCloud, isTrue);
      for (final provider in AssistantProvider.values.where(
        (provider) => provider != AssistantProvider.apple,
      )) {
        expect(reopened.settingsFor(provider).apiKey, '${provider.name}-key');
        expect(reopened.settingsFor(provider).model, '${provider.name}-model');
      }
      await reopened.configure(reopened.settingsFor(AssistantProvider.openai));
      final third = await launch();
      expect(third.settings!.provider, AssistantProvider.openai);
      expect(third.settings!.apiKey, 'openai-key');
    },
  );

  test('clearing a key persists and overrides a configured default', () async {
    final first = await launch();
    await first.configure(first.settingsFor(AssistantProvider.openai));
    await first.configure(
      const AssistantSettings(provider: AssistantProvider.openai),
    );
    final reopened = await launch();
    expect(reopened.settings!.apiKey, isEmpty);
  });

  test(
    'load and save errors are visible without exposing credentials',
    () async {
      final assistant = await launch(store: _FailingStore());
      expect(assistant.storageError, contains('could not be loaded'));
      expect(assistant.available, isTrue);
      await assistant.configure(
        const AssistantSettings(
          provider: AssistantProvider.openai,
          apiKey: 'secret',
        ),
      );
      expect(assistant.storageError, contains('could not be saved'));
      expect(assistant.storageError, isNot(contains('secret')));
      expect(assistant.settings!.apiKey, 'secret');
      expect(assistant.available, isTrue);
    },
  );
}

class _Backend implements AssistantBackend {
  @override
  String get label => 'Test';
  @override
  Future<String?> checkAvailability() async => null;
  @override
  Stream<String> respond(String question) => const Stream.empty();
  @override
  Future<void> reset() async {}
  @override
  Future<void> dispose() async {}
}

class _FailingStore extends AssistantSettingsStore {
  @override
  Future<({AssistantProvider? selected, List<AssistantSettings> settings})>
  load() async => throw StateError('secret');
  @override
  Future<void> save(AssistantSettings settings) async =>
      throw StateError('secret');
}
