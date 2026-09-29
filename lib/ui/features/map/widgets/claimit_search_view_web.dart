import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:riverside_atlas/domain/models/unclaimed_property_search.dart';

@JS('open')
external void _openWindow(String url, String target);

/// Web browsers cannot fill a form hosted on another origin.
class ClaimItSearchView extends StatelessWidget {
  const ClaimItSearchView({
    required this.query,
    required this.searchUri,
    super.key,
  });

  final UnclaimedPropertyQuery query;
  final Uri searchUri;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.account_balance_outlined, size: 40),
          const SizedBox(height: 16),
          const Text(
            'Open ClaimIt and paste the name into its search form. '
            'Automatic entry is available in the desktop and mobile app.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SelectableText('Last / business name: ${query.lastName}'),
          if (query.firstName.isNotEmpty)
            SelectableText('First name: ${query.firstName}'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              // Open synchronously with the gesture to avoid popup blocking.
              _openWindow(searchUri.toString(), '_blank');
              try {
                await Clipboard.setData(ClipboardData(text: query.lastName));
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Could not copy the name. Select and copy it above.',
                      ),
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Copy last / business name and open ClaimIt'),
          ),
        ],
      ),
    ),
  );
}
