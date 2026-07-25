/// The default browser content for the Google search panel.
///
/// `webview_flutter` has no web implementation, and Google cannot be shown in
/// an iframe instead because `www.google.com` is served with
/// `X-Frame-Options: SAMEORIGIN`. The web build therefore hands the search off
/// to a new browser tab rather than embedding it.
library;

export 'google_search_view_native.dart'
    if (dart.library.js_interop) 'google_search_view_web.dart';
