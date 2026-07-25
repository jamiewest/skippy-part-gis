import 'package:flutter/material.dart';
import 'package:riverside_atlas/ui/features/map/widgets/google_search_view.dart';

/// Builds the browser content displayed inside [GoogleSearchPanel].
typedef GoogleSearchViewBuilder =
    Widget Function(BuildContext context, Uri searchUri);

/// A side panel that displays a Google search for the current selection.
///
/// Desktop builds embed the search in a WebView. The web build hands it off
/// to a new browser tab; see `google_search_view.dart`.
class GoogleSearchPanel extends StatelessWidget {
  /// Creates a panel for [query].
  const GoogleSearchPanel({
    required this.query,
    required this.searchSubject,
    required this.onClose,
    this.webViewBuilder = defaultGoogleSearchView,
    super.key,
  });

  /// The text sent to Google.
  final String query;

  /// A short description of what is being searched.
  final String searchSubject;

  /// Closes the side panel.
  final VoidCallback onClose;

  /// Builds the panel's browser content.
  final GoogleSearchViewBuilder webViewBuilder;

  /// The encoded Google Search URL for [query].
  Uri get searchUri => Uri.https('www.google.com', '/search', {'q': query});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      key: const Key('google-search-panel'),
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: theme.colorScheme.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 8, 12),
              child: Row(
                children: [
                  Icon(Icons.manage_search, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Google search',
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          '$searchSubject • $query',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('close-google-search-panel'),
                    tooltip: 'Close Google search',
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: webViewBuilder(context, searchUri)),
        ],
      ),
    );
  }
}
