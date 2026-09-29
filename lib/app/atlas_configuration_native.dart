import 'dart:io';

import 'package:extensions/configuration.dart';

/// The prefix every setting this application reads is named with.
///
/// Prefixing keeps an unrelated `PATH` or `HOME` out of the configuration and
/// makes it obvious which variables the application is looking for.
const atlasSettingPrefix = 'ATLAS_';

/// Adds the settings sources available on a platform with an environment.
///
/// Two sources, lowest precedence first, so a shell variable can override a
/// value baked in at build time:
///
/// 1. `--dart-define`, which is how a release build carries a key.
/// 2. Environment variables, which is how a developer sets one for a run.
void addAtlasConfiguration(ConfigurationBuilder builder) {
  builder.addInMemoryCollection(atlasCompiledSettings().entries);
  builder.addInMemoryCollection([
    for (final entry in Platform.environment.entries)
      if (entry.key.startsWith(atlasSettingPrefix))
        MapEntry(entry.key.substring(atlasSettingPrefix.length), entry.value),
  ]);
}

/// Settings compiled in with `--dart-define`.
///
/// `String.fromEnvironment` only reads a literal name known at compile time,
/// so each supported key has to be named here rather than looked up.
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
