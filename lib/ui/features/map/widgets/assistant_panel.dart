import 'package:flutter/material.dart';
import 'assistant_composer.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:riverside_atlas/domain/models/assistant_settings.dart';
import 'package:riverside_atlas/ui/features/map/widgets/assistant_settings_dialog.dart';
import 'package:riverside_atlas/ui/features/map/view_models/assistant_dictation.dart';
import 'package:riverside_atlas/ui/features/map/view_models/map_assistant.dart';

/// The conversation panel for the map assistant.
///
/// The panel is deliberately plain: a transcript and a box to type in. What
/// makes it useful is the tools behind it, which read the county that is open
/// and can draw on the map, so "what are the demographics inside this circle"
/// is answerable without the user restating where they are.
class AssistantPanel extends StatefulWidget {
  /// Creates the panel over [assistant].
  const AssistantPanel({
    required this.assistant,
    required this.onClose,
    this.dictation,
    this.composer,
    this.compact = false,
    this.contextLabel,
    super.key,
  });

  /// The conversation being shown.
  final MapAssistant assistant;

  /// State retained when the conversation leaves the screen.
  final AssistantComposer? composer;
  final bool compact;
  final String? contextLabel;

  /// Optional controller for embedding or testing; the panel owns its lifetime.
  final AssistantDictation? dictation;

  /// Closes the panel.
  final VoidCallback onClose;

  @override
  State<AssistantPanel> createState() => _AssistantPanelState();
}

class _AssistantPanelState extends State<AssistantPanel>
    with WidgetsBindingObserver {
  late final AssistantDictation _dictation;
  String _dictationPrefix = '';
  String _lastDictation = '';

  late final AssistantComposer _composer =
      widget.composer ?? AssistantComposer();
  TextEditingController get _input => _composer.input;
  ScrollController get _transcript => _composer.transcript;
  bool _hasNewMessages = false;
  final FocusNode _inputFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _transcript.addListener(_onScroll);
    widget.assistant.addListener(_scrollToEnd);
    _dictation = widget.dictation ?? AssistantDictation();
    _dictation.addListener(_onDictation);
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreReading());
  }

  /// Returns to the latest message, or to where the reader left off.
  void _restoreReading() {
    if (!mounted || !_transcript.hasClients) return;
    final position = _transcript.position;
    final offset = _composer.followLatest
        ? position.maxScrollExtent
        : (_composer.readingOffset ?? 0).clamp(0.0, position.maxScrollExtent);
    _transcript.jumpTo(offset);
  }

  @override
  void dispose() {
    if (_transcript.hasClients) {
      _composer.readingOffset = _transcript.offset;
    }
    widget.assistant.removeListener(_scrollToEnd);
    _dictation.removeListener(_onDictation);
    _dictation.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _transcript.removeListener(_onScroll);
    if (widget.composer == null) _composer.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _dictation.listening) {
      _dictation.stop();
    }
  }

  void _onScroll() {
    if (!_transcript.hasClients) return;
    _composer.followLatest = _transcript.position.extentAfter < 80;
    if (_composer.followLatest && _hasNewMessages && mounted) {
      setState(() => _hasNewMessages = false);
    }
  }

  void _scrollToEnd() {
    if (!_composer.followLatest) {
      if (mounted) setState(() => _hasNewMessages = true);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _transcript.hasClients) {
        _transcript.jumpTo(_transcript.position.maxScrollExtent);
      }
    });
  }

  void _latest() {
    _composer.followLatest = true;
    setState(() => _hasNewMessages = false);
    _scrollToEnd();
  }

  void _onDictation() {
    if (!mounted) return;
    if (_dictation.text != _lastDictation) {
      _lastDictation = _dictation.text;
      final text = '$_dictationPrefix ${_dictation.text}'.trim();
      _input.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    setState(() {});
  }

  void _toggleDictation() {
    if (_dictation.listening) {
      _dictation.stop();
    } else {
      _dictationPrefix = _input.text.trim();
      _lastDictation = '';
      _dictation.start();
    }
  }

  void _send() {
    if (!widget.assistant.available ||
        widget.assistant.isThinking ||
        _dictation.listening ||
        _dictation.busy) {
      return;
    }
    final text = _input.text.trim();
    if (text.isEmpty) {
      return;
    }
    _composer.followLatest = true;
    _input.clear();
    widget.assistant.send(text);
    _inputFocus.requestFocus();
  }

  Future<void> _mobileSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('AI settings')),
          body: SafeArea(
            child: ListenableBuilder(
              listenable: widget.assistant,
              builder: (context, _) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  DropdownButtonFormField<AssistantProvider>(
                    key: ValueKey(widget.assistant.settings!.provider),
                    initialValue: widget.assistant.settings!.provider,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'AI provider'),
                    items: [
                      for (final provider in AssistantProvider.values)
                        DropdownMenuItem(
                          value: provider,
                          child: Text(provider.label),
                        ),
                    ],
                    onChanged:
                        widget.assistant.isThinking ||
                            widget.assistant.isConfiguring
                        ? null
                        : (provider) {
                            if (provider != null) {
                              widget.assistant.configure(
                                widget.assistant.settingsFor(provider),
                              );
                            }
                          },
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Credentials and model'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap:
                        widget.assistant.isThinking ||
                            widget.assistant.isConfiguring
                        ? null
                        : _editSettings,
                  ),
                  const Text('Changing providers starts a new conversation.'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editSettings() async {
    final settings = await showDialog<AssistantSettings>(
      context: context,
      builder: (_) =>
          AssistantSettingsDialog(settings: widget.assistant.settings!),
    );
    if (mounted && settings != null) {
      await widget.assistant.configure(settings);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      key: const Key('assistant-panel'),
      color: theme.colorScheme.surface,
      elevation: 8,
      child: ListenableBuilder(
        listenable: widget.assistant,
        builder: (context, _) {
          final messages = widget.assistant.messages;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                color: theme.colorScheme.surfaceContainerHigh,
                child: Padding(
                  padding: widget.compact
                      ? const EdgeInsets.symmetric(horizontal: 8)
                      : const EdgeInsets.fromLTRB(18, 10, 8, 10),
                  child: Row(
                    children: [
                      if (widget.compact)
                        TextButton.icon(
                          key: const Key('assistant-map-button'),
                          onPressed: widget.onClose,
                          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                          label: const Text('Map'),
                        )
                      else
                        Icon(
                          Icons.auto_awesome_outlined,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.compact
                              ? (MediaQuery.textScalerOf(context).scale(1) > 1.3
                                    ? ''
                                    : 'Ask AI')
                              : widget.assistant.providerLabel,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      if (messages.isNotEmpty)
                        IconButton(
                          key: const Key('assistant-clear-button'),
                          tooltip: 'Start a new conversation',
                          onPressed: widget.assistant.isThinking
                              ? null
                              : widget.assistant.clear,
                          icon: const Icon(Icons.refresh, size: 18),
                        ),
                      if (widget.compact && widget.assistant.canConfigure)
                        IconButton(
                          key: const Key('assistant-settings-button'),
                          tooltip: 'AI settings',
                          onPressed: _dictation.listening || _dictation.busy
                              ? null
                              : _mobileSettings,
                          icon: const Icon(Icons.tune),
                        ),
                      if (!widget.compact)
                        IconButton(
                          key: const Key('assistant-close-button'),
                          tooltip: 'Close',
                          onPressed: widget.onClose,
                          icon: const Icon(Icons.close, size: 18),
                        ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              if (widget.contextLabel != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Text(
                    widget.contextLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              if (widget.assistant.canConfigure && !widget.compact)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<AssistantProvider>(
                          key: ValueKey(widget.assistant.settings!.provider),
                          initialValue: widget.assistant.settings!.provider,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'AI provider',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            for (final provider in AssistantProvider.values)
                              DropdownMenuItem(
                                value: provider,
                                child: Text(provider.label),
                              ),
                          ],
                          onChanged:
                              widget.assistant.isThinking ||
                                  widget.assistant.isConfiguring ||
                                  _dictation.listening ||
                                  _dictation.busy
                              ? null
                              : (provider) {
                                  if (provider != null &&
                                      provider !=
                                          widget.assistant.settings!.provider) {
                                    widget.assistant.configure(
                                      widget.assistant.settingsFor(provider),
                                    );
                                  }
                                },
                        ),
                      ),
                      IconButton(
                        key: const Key('assistant-settings-button'),
                        tooltip: 'AI provider settings',
                        onPressed:
                            widget.assistant.isThinking ||
                                widget.assistant.isConfiguring ||
                                _dictation.listening ||
                                _dictation.busy
                            ? null
                            : _editSettings,
                        icon: const Icon(Icons.tune),
                      ),
                    ],
                  ),
                ),
              if (widget.assistant.storageError case final error?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    error,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              Expanded(
                child: widget.assistant.isChecking
                    ? const Center(child: CircularProgressIndicator())
                    : widget.assistant.available
                    ? _Transcript(
                        messages: messages,
                        controller: _transcript,
                        isThinking: widget.assistant.isThinking,
                      )
                    : _Unavailable(
                        reason: widget.assistant.unavailableReason ?? '',
                      ),
              ),
              if (_hasNewMessages)
                TextButton.icon(
                  onPressed: _latest,
                  icon: const Icon(Icons.arrow_downward),
                  label: const Text('Latest message'),
                ),
              if (!widget.assistant.available &&
                  !widget.assistant.isChecking &&
                  widget.assistant.canRetry)
                TextButton(
                  onPressed: widget.assistant.initialize,
                  child: Text(
                    widget.assistant.providerLabel.startsWith('Apple')
                        ? 'Retry Apple Intelligence'
                        : 'Retry provider',
                  ),
                ),
              if (_dictation.error case final error?)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    error,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              if (_dictation.needsModel)
                TextButton(
                  onPressed: _dictation.busy ? null : _dictation.installModel,
                  child: const Text('Download English speech model'),
                ),
              if (_dictation.listening || _dictation.busy)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    _dictation.busy
                        ? 'Preparing dictation…'
                        : 'Listening on device… Tap stop, review, then send.',
                  ),
                ),
              if (widget.assistant.available) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('assistant-input'),
                          controller: _input,
                          readOnly: _dictation.listening || _dictation.busy,
                          focusNode: _inputFocus,
                          minLines: 1,
                          maxLines: 4,
                          keyboardType: TextInputType.multiline,
                          textInputAction: widget.compact
                              ? TextInputAction.newline
                              : TextInputAction.send,
                          onSubmitted: widget.compact ? null : (_) => _send(),
                          decoration: const InputDecoration(
                            hintText: 'Ask about the area on the map',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_dictation.supported)
                        IconButton(
                          key: const Key('assistant-microphone-button'),
                          tooltip: _dictation.listening
                              ? 'Stop dictation'
                              : 'Dictate a question',
                          onPressed:
                              widget.assistant.isThinking || _dictation.busy
                              ? null
                              : _toggleDictation,
                          icon: Icon(
                            _dictation.listening
                                ? Icons.stop_circle
                                : Icons.mic_none,
                          ),
                        ),
                      IconButton.filled(
                        key: const Key('assistant-send-button'),
                        tooltip: 'Send message',
                        onPressed:
                            widget.assistant.isThinking ||
                                _dictation.listening ||
                                _dictation.busy
                            ? null
                            : _send,
                        icon: const Icon(Icons.arrow_upward, size: 18),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// The conversation so far, or an invitation when there is none.
class _Transcript extends StatelessWidget {
  const _Transcript({
    required this.messages,
    required this.controller,
    required this.isThinking,
  });

  final List<AssistantMessage> messages;
  final ScrollController controller;
  final bool isThinking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (messages.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.draw_outlined,
                size: 30,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 14),
              Text(
                'Draw a circle or a rectangle on the map, then ask about it — '
                'or just say where to look.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '“What are the demographics here?”\n'
                '“Draw a half-mile circle around this corner.”\n'
                '“How many addresses are in the area I drew?”',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.7,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      controller: controller,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final last = index == messages.length - 1;
        return _Bubble(
          message: message,
          // An empty trailing assistant line is the answer that has not
          // started arriving yet, which is what the spinner is for.
          pending: last && isThinking && message.text.isEmpty,
        );
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.pending});

  final AssistantMessage message;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (background, foreground, alignment) = switch (message.role) {
      AssistantRole.user => (
        theme.colorScheme.primaryContainer,
        theme.colorScheme.onPrimaryContainer,
        Alignment.centerRight,
      ),
      AssistantRole.assistant => (
        theme.colorScheme.surfaceContainerHighest,
        theme.colorScheme.onSurface,
        Alignment.centerLeft,
      ),
      AssistantRole.error => (
        theme.colorScheme.errorContainer,
        theme.colorScheme.onErrorContainer,
        Alignment.centerLeft,
      ),
    };
    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 640),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: pending
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : message.role == AssistantRole.error
            ? SelectableText(
                message.text,
                style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
              )
            : MarkdownBody(
                data: message.text,
                selectable: true,
                fitContent: true,
                styleSheet:
                    MarkdownStyleSheet.fromTheme(
                      theme.copyWith(
                        textTheme: theme.textTheme.apply(
                          bodyColor: foreground,
                          displayColor: foreground,
                        ),
                      ),
                    ).copyWith(
                      p: theme.textTheme.bodyMedium?.copyWith(
                        color: foreground,
                      ),
                      code: theme.textTheme.bodySmall?.copyWith(
                        color: foreground,
                        fontFamily: 'monospace',
                        backgroundColor: background,
                      ),
                    ),
                onTapLink: (_, href, _) async {
                  final uri = Uri.tryParse(href ?? '');
                  if (uri == null ||
                      !const ['https', 'http', 'mailto'].contains(uri.scheme)) {
                    return;
                  }
                  try {
                    if (await launchUrl(uri)) return;
                  } catch (_) {
                    // Report unsupported links without interrupting the chat.
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Could not open this link.'),
                      ),
                    );
                  }
                },
              ),
      ),
    );
  }
}

/// Says what the assistant needs before it can answer anything.
class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.key_off_outlined,
              size: 30,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            Text(
              reason,
              key: const Key('assistant-unavailable-reason'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
