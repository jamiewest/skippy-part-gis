/// ClaimIt embeds on native platforms and opens separately on the web.
library;

export 'claimit_search_view_native.dart'
    if (dart.library.js_interop) 'claimit_search_view_web.dart';
