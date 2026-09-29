import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverside_atlas/domain/models/assistant_settings.dart';

/// Device-local provider settings; secrets never enter the GIS database.
class AssistantSettingsStore {
  const AssistantSettingsStore({
    this.storage = const FlutterSecureStorage(
      // No cross-app sharing: use the login Keychain without provisioning.
      mOptions: MacOsOptions(usesDataProtectionKeychain: false),
    ),
  });

  final FlutterSecureStorage storage;
  static const _prefix = 'atlas.assistant.v1';

  Future<({AssistantProvider? selected, List<AssistantSettings> settings})>
  load() async {
    final settings = <AssistantSettings>[];
    for (final provider in AssistantProvider.values) {
      final value = await storage.read(key: '$_prefix.${provider.name}');
      if (value == null) continue;
      final json = jsonDecode(value) as Map<String, dynamic>;
      settings.add(
        AssistantSettings(
          provider: provider,
          apiKey: json['apiKey'] as String? ?? '',
          model: json['model'] as String? ?? '',
          appleCloud: json['appleCloud'] as bool? ?? false,
        ),
      );
    }
    final selected = await storage.read(key: '$_prefix.selected');
    return (
      selected: AssistantProvider.values
          .where((provider) => provider.name == selected)
          .firstOrNull,
      settings: settings,
    );
  }

  /// Writes only this provider, preserving other providers even after a read
  /// failure. An empty key explicitly replaces a previously saved credential.
  Future<void> save(AssistantSettings settings) async {
    await storage.write(
      key: '$_prefix.${settings.provider.name}',
      value: jsonEncode({
        'apiKey': settings.apiKey,
        'model': settings.model,
        'appleCloud': settings.appleCloud,
      }),
    );
    await storage.write(
      key: '$_prefix.selected',
      value: settings.provider.name,
    );
  }
}
