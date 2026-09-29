import 'package:extensions/configuration.dart';

/// The prefix every setting this application reads is named with.
const atlasSettingPrefix = 'ATLAS_';

/// Adds the settings sources available in a browser tab.
///
/// A browser has no process environment. These optional build defaults can
/// be overridden by the assistant's in-app provider settings.
void addAtlasConfiguration(ConfigurationBuilder builder) {
  builder.addInMemoryCollection(atlasCompiledSettings().entries);
}

/// Settings compiled in with `--dart-define`.
Map<String, String> atlasCompiledSettings() {
  const routeSnapUrl = String.fromEnvironment('ATLAS_ROUTE_SNAP_URL');
  const routingUrl = String.fromEnvironment('ATLAS_ROUTING_URL');
  const geocodingUrl = String.fromEnvironment('ATLAS_GEOCODING_URL');
  const routeCameraUrl = String.fromEnvironment('ATLAS_ROUTE_CAMERA_URL');
  const censusApiKey = String.fromEnvironment('ATLAS_CENSUS_API_KEY');
  const anthropicApiKey = String.fromEnvironment('ATLAS_ANTHROPIC_API_KEY');
  const openaiApiKey = String.fromEnvironment('ATLAS_OPENAI_API_KEY');
  const geminiApiKey = String.fromEnvironment('ATLAS_GEMINI_API_KEY');
  const model = String.fromEnvironment('ATLAS_ASSISTANT_MODEL');
  const provider = String.fromEnvironment('ATLAS_ASSISTANT_PROVIDER');
  return {
    if (routeSnapUrl.isNotEmpty) 'ROUTE_SNAP_URL': routeSnapUrl,
    if (routingUrl.isNotEmpty) 'ROUTING_URL': routingUrl,
    if (geocodingUrl.isNotEmpty) 'GEOCODING_URL': geocodingUrl,
    if (routeCameraUrl.isNotEmpty) 'ROUTE_CAMERA_URL': routeCameraUrl,
    if (censusApiKey.isNotEmpty) 'CENSUS_API_KEY': censusApiKey,
    if (anthropicApiKey.isNotEmpty) 'ANTHROPIC_API_KEY': anthropicApiKey,
    if (openaiApiKey.isNotEmpty) 'OPENAI_API_KEY': openaiApiKey,
    if (geminiApiKey.isNotEmpty) 'GEMINI_API_KEY': geminiApiKey,
    if (model.isNotEmpty) 'ASSISTANT_MODEL': model,
    if (provider.isNotEmpty) 'ASSISTANT_PROVIDER': provider,
  };
}
