import 'package:flutter/material.dart';
import 'package:riverside_atlas/domain/models/unclaimed_property_search.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'claimit_search_script.dart';
import 'google_search_view_native.dart';

/// Loads ClaimIt's editable form and starts the requested owner search.
class ClaimItSearchView extends StatefulWidget {
  const ClaimItSearchView({
    required this.query,
    required this.searchUri,
    super.key,
  });

  final UnclaimedPropertyQuery query;
  final Uri searchUri;

  @override
  State<ClaimItSearchView> createState() => _ClaimItSearchViewState();
}

class _ClaimItSearchViewState extends State<ClaimItSearchView> {
  int _generation = 0;
  String _message = 'Preparing the owner search…';

  Future<void> _startSearch(WebViewController controller, String url) async {
    final generation = ++_generation;
    final uri = Uri.tryParse(url);
    if (uri?.scheme != 'https' ||
        uri?.host != widget.searchUri.host ||
        uri?.port != 443 ||
        uri?.path != widget.searchUri.path) {
      return;
    }
    final script = claimItSearchScript(widget.query);
    try {
      // Angular can render its form after the browser's page-finished event.
      for (var attempt = 0; attempt < 80; attempt++) {
        if (!mounted || generation != _generation) return;
        final result = await controller.runJavaScriptReturningResult(script);
        if (!mounted || generation != _generation) return;
        final status = result.toString().replaceAll('"', '');
        if (status == 'away') return;
        if (status == 'submitted') {
          setState(() {
            _message =
                'Owner search started. Complete any verification '
                'requested by ClaimIt below. You can edit the name on the page.';
          });
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    } catch (_) {
      // Leave the official form usable if its markup or scripting changes.
    }
    if (mounted && generation == _generation) {
      setState(() {
        _message =
            'Automatic search could not start. Enter or check the '
            'owner name on the page, then select Search.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Text(_message, style: Theme.of(context).textTheme.bodySmall),
      ),
      Expanded(
        child: SearchWebView(
          searchUri: widget.searchUri,
          searchTitle: 'ClaimIt',
          onPageFinished: _startSearch,
        ),
      ),
    ],
  );
}
