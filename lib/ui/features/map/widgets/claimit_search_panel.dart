import 'package:flutter/material.dart';
import 'package:riverside_atlas/domain/models/unclaimed_property_search.dart';
import 'claimit_search_view.dart';
import 'google_search_panel.dart';
import 'web_search_panel.dart';

/// The official California unclaimed-property search for a parcel owner.
class ClaimItSearchPanel extends StatelessWidget {
  const ClaimItSearchPanel({
    required this.query,
    required this.onClose,
    this.webViewBuilder,
    super.key,
  });

  final UnclaimedPropertyQuery query;
  final VoidCallback onClose;
  final GoogleSearchViewBuilder? webViewBuilder;

  static final searchUri = Uri.https('claimit.ca.gov', '/app/claim-search');

  @override
  Widget build(BuildContext context) => WebSearchPanel(
    panelId: 'claimit-search-panel',
    title: 'ClaimIt search',
    subtitle: 'Owner name • ${query.ownerName}',
    onClose: onClose,
    child:
        webViewBuilder?.call(context, searchUri) ??
        ClaimItSearchView(query: query, searchUri: searchUri),
  );
}
