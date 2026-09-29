import 'dart:async';

import 'package:apple_speech/apple_speech.dart';
import 'package:flutter/foundation.dart';

/// Owns microphone capture for one assistant panel. Audio stays on device.
class AssistantDictation extends ChangeNotifier {
  SpeechAnalysis? _analysis;
  StreamSubscription<AnalysisResult>? _results;
  bool _disposed = false;
  bool _busy = false;
  bool _listening = false;
  String _text = '';
  String? _error;
  String? _missingLocale;
  final StringBuffer _finalText = StringBuffer();

  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.iOS);
  bool get busy => _busy;
  bool get listening => _listening;
  String get text => _text;
  String? get error => _error;
  bool get needsModel => _missingLocale != null;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  /// Permission is requested only after the user presses the microphone.
  Future<void> start() async {
    if (_disposed || _busy || _listening) return;
    _busy = true;
    _error = null;
    _text = '';
    _finalText.clear();
    _changed();
    try {
      if (!await Speech.isAnalyzerSupported() ||
          !await SpeechTranscriber.isAvailable()) {
        throw StateError(
          'On-device dictation needs a supported Apple device '
          'running iOS or macOS 26 or later.',
        );
      }
      final locale = await SpeechTranscriber.supportedLocale(
        equivalentTo: 'en-US',
      );
      if (locale == null) {
        throw StateError('English dictation is not supported on this device.');
      }
      if (!(await SpeechTranscriber.installedLocales()).contains(locale)) {
        _missingLocale = locale;
        throw StateError(
          'The English speech model is not installed. '
          'Use Download speech model, then try the microphone again.',
        );
      }
      if (_disposed) return;
      if (await Speech.requestMicrophoneAuthorization() !=
          AuthorizationStatus.authorized) {
        throw StateError(
          'Allow microphone access in System Settings to dictate.',
        );
      }
      if (_disposed) return;
      final analysis = await SpeechAnalyzer.analyze(
        source: const AudioSource.microphone(),
        modules: [
          SpeechTranscriber(
            locale: locale,
            preset: SpeechTranscriberPreset.progressiveTranscription,
          ),
        ],
      );
      if (_disposed) {
        await analysis.cancel();
        return;
      }
      _analysis = analysis;
      _listening = true;
      _results = analysis.results.listen(
        (result) {
          final words = result.text;
          if (words == null) return;
          if (result.isFinal) {
            _finalText.write('$words ');
            _text = _finalText.toString().trim();
          } else {
            _text = '${_finalText.toString()}$words'.trim();
          }
          _changed();
        },
        onError: (Object error) {
          _error = 'Dictation failed: $error';
          _listening = false;
          _changed();
        },
        onDone: () {
          _listening = false;
          _analysis = null;
          _changed();
        },
      );
    } on Object catch (error) {
      _error = 'Dictation could not start: $error';
    } finally {
      _busy = false;
      _changed();
    }
  }

  /// Downloads only after the user explicitly selects the download action.
  Future<void> installModel() async {
    final locale = _missingLocale;
    if (_disposed || _busy || locale == null) return;
    _busy = true;
    _error = null;
    _changed();
    try {
      await AssetInventory.installAssets([SpeechTranscriber(locale: locale)]);
      _missingLocale = null;
    } on Object catch (error) {
      _error = 'Speech model download failed: $error';
    } finally {
      _busy = false;
      _changed();
    }
  }

  /// Stops audio input and allows the final words to reach the text field.
  Future<void> stop() async {
    if (_disposed || _busy || !_listening) return;
    _busy = true;
    _changed();
    final analysis = _analysis;
    try {
      await analysis?.finish().timeout(const Duration(seconds: 10));
    } on Object catch (error) {
      _error = 'Dictation could not finish: $error';
    } finally {
      await analysis?.cancel();
      _analysis = null;
      _listening = false;
      _busy = false;
      _changed();
    }
  }

  Future<void> _release() async {
    await _results?.cancel();
    await _analysis?.cancel();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_release());
    super.dispose();
  }
}
