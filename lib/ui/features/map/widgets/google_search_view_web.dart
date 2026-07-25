import 'dart:js_interop';

import 'package:flutter/material.dart';

/// Calls `window.open` on the host page.
@JS('open')
external void _openWindow(String url, String target);

/// Builds a hand-off to a new browser tab showing [searchUri].
///
/// The web build cannot embed the search: `webview_flutter` has no web
/// implementation, and an iframe is refused because `www.google.com` sends
/// `X-Frame-Options: SAMEORIGIN`.
Widget defaultGoogleSearchView(BuildContext context, Uri searchUri) {
  return _GoogleSearchLauncher(searchUri: searchUri);
}

class _GoogleSearchLauncher extends StatelessWidget {
  const _GoogleSearchLauncher({required this.searchUri});

  final Uri searchUri;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.open_in_new,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Google cannot be embedded',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Google refuses to load inside another page, so this search '
              'opens in a new tab instead.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('open-google-search-in-new-tab'),
              onPressed: () => _openWindow(searchUri.toString(), '_blank'),
              icon: const Icon(Icons.search),
              label: const Text('Open search in a new tab'),
            ),
          ],
        ),
      ),
    );
  }
}
