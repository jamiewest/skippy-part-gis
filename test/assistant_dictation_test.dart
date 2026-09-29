import 'dart:async';

import 'package:apple_speech/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverside_atlas/ui/features/map/view_models/assistant_dictation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SpeechBindings original;
  late _Host host;
  late AssistantDictation dictation;

  setUp(() {
    original = SpeechBindings.instance;
    host = _Host();
    SpeechBindings.instance = SpeechBindings(
      host: host,
      platform: _Platform(),
      registerCallbacks: false,
    );
    dictation = AssistantDictation();
  });
  tearDown(() async {
    dictation.dispose();
    await Future<void>.delayed(Duration.zero);
    SpeechBindings.instance = original;
  });

  test('partial hypotheses replace rather than duplicate words', () async {
    await dictation.start();
    host.words('show me', finalResult: false);
    host.words('show me Census', finalResult: false);
    await Future<void>.delayed(Duration.zero);
    expect(dictation.text, 'show me Census');
    host.words('show me Census', finalResult: true);
    host.words('data here', finalResult: false);
    await Future<void>.delayed(Duration.zero);
    expect(dictation.text, 'show me Census data here');
    await dictation.stop();
    expect(dictation.listening, isFalse);
    expect(host.finishes, 1);
  });

  test('denied microphone permission never starts capture', () async {
    host.authorized = false;
    await dictation.start();
    expect(host.request, isNull);
    expect(dictation.error, contains('Allow microphone access'));
    expect(dictation.busy, isFalse);
  });

  test('missing speech assets offer an explicit download', () async {
    host.installed = false;
    await dictation.start();
    expect(dictation.needsModel, isTrue);
    expect(host.permissionRequests, 0);
    expect(host.downloads, 0);
    await dictation.installModel();
    expect(host.downloads, 1);
    await dictation.start();
    expect(dictation.listening, isTrue);
  });

  test('disposing during native startup cancels the late capture', () async {
    final pending = Completer<void>();
    host.startup = pending.future;
    final start = dictation.start();
    while (host.request == null) {
      await Future<void>.delayed(Duration.zero);
    }
    dictation.dispose();
    pending.complete();
    await start;
    expect(host.cancellations, 1);
    // A fresh controller lets the common teardown dispose exactly once.
    dictation = AssistantDictation();
  });
}

class _Platform extends AppleSpeechPlatformApi {
  @override
  Future<bool> isAnalyzerSupported() async => true;
}

class _Host extends AppleSpeechHostApi {
  bool authorized = true;
  bool installed = true;
  int finishes = 0;
  int cancellations = 0;
  int permissionRequests = 0;
  int downloads = 0;
  AnalysisRequestMessage? request;
  Future<void>? startup;

  void words(String text, {required bool finalResult}) {
    SpeechBindings.instance.callbackHandler.onAnalyzerResult(
      AnalyzerResultMessage(
        requestId: request!.requestId,
        moduleIndex: 0,
        rangeStart: 0,
        rangeEnd: 1,
        resultsFinalizationTime: 1,
        isFinal: finalResult,
        text: text,
        segments: [],
        alternatives: [],
      ),
    );
  }

  @override
  Future<bool> speechTranscriberIsAvailable() async => true;
  @override
  Future<String?> supportedLocaleEquivalent(
    ModuleKindMessage kind,
    String locale,
  ) async => 'en-US';
  @override
  Future<List<String>> installedLocales(ModuleKindMessage kind) async =>
      installed ? ['en-US'] : [];
  @override
  Future<bool> installAssets(int id, List<ModuleConfigMessage> modules) async {
    downloads++;
    installed = true;
    return true;
  }

  @override
  Future<AuthorizationStatusMessage> requestMicrophoneAuthorization() async {
    permissionRequests++;
    return authorized
        ? AuthorizationStatusMessage.authorized
        : AuthorizationStatusMessage.denied;
  }

  @override
  Future<void> startAnalysis(AnalysisRequestMessage value) async {
    request = value;
    await startup;
  }

  @override
  Future<void> cancelRequest(int id) async => cancellations++;
  @override
  Future<void> finishRequest(int id) async {
    finishes++;
    SpeechBindings.instance.callbackHandler.onRequestDone(id, 1);
  }
}
