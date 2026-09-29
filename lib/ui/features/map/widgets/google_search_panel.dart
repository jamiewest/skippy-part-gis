import 'package:flutter/material.dart';
import 'package:riverside_atlas/ui/features/map/widgets/google_search_view.dart';

import 'web_search_panel.dart';

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
    return WebSearchPanel(
      panelId: 'google-search-panel',
      title: 'Google search',
      subtitle: '$searchSubject • $query',
      onClose: onClose,
      child: webViewBuilder(context, searchUri),
    );
  }
}
