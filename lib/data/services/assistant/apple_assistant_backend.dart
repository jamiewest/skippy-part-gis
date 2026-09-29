import 'package:extensions/ai.dart';
import 'package:foundation_models/foundation_models.dart' as apple;
import 'package:riverside_atlas/data/services/assistant/assistant_backend.dart';

/// Runs the map's existing functions through Apple's native tool loop.
final class AppleAssistantBackend implements AssistantBackend {
  AppleAssistantBackend({
    required this.instructions,
    required List<AITool> tools,
    this.cloud = false,
  }) : tools = tools.whereType<AIFunction>().map(appleTool).toList();

  final String instructions;
  final List<apple.Tool> tools;
  final bool cloud;
  apple.LanguageModelSession? _session;
  bool _disposed = false;

  apple.LanguageModel get _model => cloud
      ? const apple.PrivateCloudComputeLanguageModel()
      : apple.SystemLanguageModel.defaultModel;

  @override
  String get label =>
      cloud ? 'Apple Private Cloud Compute' : 'Apple · on device';

  @override
  Future<String?> checkAvailability() async {
    if (cloud && !await apple.FoundationModels.isVersion27Supported()) {
      return 'Apple Private Cloud Compute needs iOS or macOS 27 and approved '
          'Private Cloud Compute access for this app.';
    }
    final availability = await _model.availability();
    if (availability.isAvailable) return null;
    return switch (availability.reason) {
      apple.ModelUnavailableReason.appleIntelligenceNotEnabled =>
        'Turn on Apple Intelligence in System Settings, then retry.',
      apple.ModelUnavailableReason.modelNotReady =>
        'Apple is still downloading its language model. Retry when it is ready.',
      apple.ModelUnavailableReason.deviceNotEligible =>
        'This device does not support Apple Intelligence.',
      apple.ModelUnavailableReason.frameworkUnavailable =>
        'Apple inference needs iOS or macOS 26 or later on an Apple '
            'Intelligence device. It is unavailable in a browser.',
      _ =>
        'Apple Intelligence is not ready. ${cloud ? 'Check this app’s Private Cloud Compute entitlement and your iCloud account.' : 'Check System Settings and retry.'}',
    };
  }

  @override
  Stream<String> respond(String question) async* {
    if (_disposed) return;
    final session = _session ??= await apple.LanguageModelSession.create(
      model: _model,
      instructions: instructions,
      tools: tools,
    );
    if (_disposed) {
      await session.dispose();
      return;
    }
    try {
      await for (final snapshot in session.streamResponse(question)) {
        yield snapshot.delta;
      }
    } on apple.FoundationModelsException catch (error) {
      if (error.code == apple.FoundationModelsErrorCode.contextWindowExceeded) {
        throw StateError(
          'Apple’s conversation context is full. Start a new '
          'conversation and ask about a smaller area.',
        );
      }
      if (error.code == apple.FoundationModelsErrorCode.quotaLimitReached) {
        throw StateError(
          'Your Apple cloud allowance has been reached. '
          'Try again after it resets or use the on-device provider.',
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> reset() async {
    final session = _session;
    _session = null;
    await session?.dispose();
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await reset();
  }
}

/// Adapts schemas and results without duplicating the GIS tool implementation.
apple.FunctionTool appleTool(AIFunction function) => apple.FunctionTool(
  name: function.name,
  description: function.description ?? '',
  parameters: apple.GenerationSchema.fromJsonSchema({
    'title': '${function.name}_arguments',
    ...?function.parametersSchema,
    if (function.parametersSchema == null) ...{
      'type': 'object',
      'properties': <String, Object?>{},
      'required': <String>[],
    },
  }),
  handler: (arguments) async => apple.ToolOutput.json(
    await function.invoke(AIFunctionArguments(arguments.asMap)),
  ),
);
