import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Builds an embedded WebView showing [searchUri].
Widget defaultGoogleSearchView(BuildContext context, Uri searchUri) {
  return SearchWebView(searchUri: searchUri);
}

/// Embedded browser with optional initialization after a page loads.
class SearchWebView extends StatefulWidget {
  const SearchWebView({
    required this.searchUri,
    this.searchTitle = 'Google Search',
    this.onPageFinished,
    super.key,
  });

  final Uri searchUri;
  final String searchTitle;
  final Future<void> Function(WebViewController controller, String url)?
  onPageFinished;

  @override
  State<SearchWebView> createState() => _SearchWebViewState();
}

class _SearchWebViewState extends State<SearchWebView> {
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
          onPageFinished: (url) async {
            if (mounted) {
              setState(() => _isLoading = false);
              await widget.onPageFinished?.call(_controller, url);
            }
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted) {
              setState(() {
                _isLoading = false;
                _errorMessage =
                    '${widget.searchTitle} could not be loaded. Check your connection '
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
                      tooltip: 'Retry ${widget.searchTitle}',
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
