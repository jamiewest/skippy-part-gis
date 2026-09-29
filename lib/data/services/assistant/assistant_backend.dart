import 'package:agents/agents.dart';

/// A conversation provider, independent of the map and its presentation.
abstract interface class AssistantBackend {
  String get label;

  /// Null means ready; otherwise a user-facing explanation.
  Future<String?> checkAvailability();
  Stream<String> respond(String question);
  Future<void> reset();
  Future<void> dispose();
}

/// Keeps the existing agent runtime and its function-calling pipeline.
final class AgentAssistantBackend implements AssistantBackend {
  AgentAssistantBackend(this.agent, {this.label = 'Anthropic'});

  final AIAgent agent;
  AgentSession? _session;

  @override
  final String label;

  @override
  Future<String?> checkAvailability() async => null;

  @override
  Stream<String> respond(String question) async* {
    _session ??= await agent.createSession();
    await for (final update in agent.runStreaming(
      _session,
      null,
      message: question,
    )) {
      yield update.text;
    }
  }

  @override
  Future<void> reset() async => _session = null;

  @override
  Future<void> dispose() => reset();
}

/// Keeps provider setup available in the UI when credentials are missing.
final class UnavailableAssistantBackend implements AssistantBackend {
  UnavailableAssistantBackend(this.label, this.reason);

  @override
  final String label;
  final String reason;

  @override
  Future<String?> checkAvailability() async => reason;
  @override
  Stream<String> respond(String question) => const Stream.empty();
  @override
  Future<void> reset() async {}
  @override
  Future<void> dispose() async {}
}
