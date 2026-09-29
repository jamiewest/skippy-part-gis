/// Providers that can be selected without rebuilding the application.
enum AssistantProvider {
  anthropic('Anthropic', 'claude-sonnet-5'),
  openai('OpenAI', 'gpt-4.1'),
  gemini('Google Gemini', 'gemini-3.8-flash'),
  apple('Apple', '');

  const AssistantProvider(this.label, this.defaultModel);
  final String label;
  final String defaultModel;
}

/// Configuration for one provider. Credentials are persisted in secure storage.
final class AssistantSettings {
  const AssistantSettings({
    required this.provider,
    this.apiKey = '',
    this.model = '',
    this.appleCloud = false,
  });

  final AssistantProvider provider;
  final String apiKey;
  final String model;
  final bool appleCloud;

  String get effectiveModel =>
      model.trim().isEmpty ? provider.defaultModel : model.trim();
}
