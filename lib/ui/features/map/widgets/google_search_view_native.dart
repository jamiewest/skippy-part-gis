import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Builds an embedded WebView showing [searchUri].
Widget defaultGoogleSearchView(BuildContext context, Uri searchUri) {
  return _GoogleSearchWebView(searchUri: searchUri);
}

class _GoogleSearchWebView extends StatefulWidget {
  const _GoogleSearchWebView({required this.searchUri});

  final Uri searchUri;

  @override
  State<_GoogleSearchWebView> createState() => _GoogleSearchWebViewState();
}

class _GoogleSearchWebViewState extends State<_GoogleSearchWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
            }
          },
          onPageFinished: (_) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted) {
              setState(() {
                _isLoading = false;
                _errorMessage =
                    'Google Search could not be loaded. Check your connection '
                    'and try again.';
              });
            }
          },
        ),
      )
      ..loadRequest(widget.searchUri);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Positioned.fill(child: WebViewWidget(controller: _controller)),
        if (_isLoading)
          const Align(
            alignment: Alignment.topCenter,
            child: LinearProgressIndicator(),
          ),
        if (_errorMessage case final message?)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Material(
              elevation: 3,
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_off_outlined,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        message,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Retry Google search',
                      onPressed: () => _controller.reload(),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
