import 'package:flutter/material.dart';
import 'package:riverside_atlas/domain/models/assistant_settings.dart';

/// Edits one provider's saved credentials and model.
class AssistantSettingsDialog extends StatefulWidget {
  const AssistantSettingsDialog({required this.settings, super.key});
  final AssistantSettings settings;

  @override
  State<AssistantSettingsDialog> createState() =>
      _AssistantSettingsDialogState();
}

class _AssistantSettingsDialogState extends State<AssistantSettingsDialog> {
  late final _key = TextEditingController(text: widget.settings.apiKey);
  late final _model = TextEditingController(text: widget.settings.model);
  late bool _appleCloud = widget.settings.appleCloud;
  bool _showKey = false;

  @override
  void dispose() {
    _key.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.settings.provider;
    return AlertDialog(
      title: Text('${provider.label} settings'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (provider == AssistantProvider.apple) ...[
                const Text(
                  'Uses Apple Intelligence on this device. No API key '
                  'is needed. Availability is checked when you select Apple.',
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Private Cloud Compute'),
                  subtitle: const Text(
                    'Requires approved cloud access for this app.',
                  ),
                  value: _appleCloud,
                  onChanged: (value) => setState(() => _appleCloud = value),
                ),
              ] else ...[
                TextField(
                  key: const Key('assistant-api-key'),
                  controller: _key,
                  obscureText: !_showKey,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: '${provider.label} API key',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: _showKey ? 'Hide API key' : 'Show API key',
                      onPressed: () => setState(() => _showKey = !_showKey),
                      icon: Icon(
                        _showKey ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('assistant-model'),
                  controller: _model,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'Model (optional)',
                    hintText: provider.defaultModel,
                    helperText: 'Default: ${provider.defaultModel}',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'API keys and settings are saved on this device and restored '
                  'when you reopen Atlas. Clear the key and apply to remove it.',
                ),
              ],
              const SizedBox(height: 12),
              const Text('Applying settings starts a new conversation.'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('assistant-apply-settings'),
          onPressed: () => Navigator.pop(
            context,
            AssistantSettings(
              provider: provider,
              apiKey: _key.text.trim(),
              model: _model.text.trim(),
              appleCloud: _appleCloud,
            ),
          ),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
