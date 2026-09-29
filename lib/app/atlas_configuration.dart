/// Where the application's settings come from, per platform.
///
/// Keys the application needs but must not carry in its source -- the Census
/// API key and optional assistant defaults -- are read from the environment
/// where there is one and from compile-time defines where there is not.
/// Assistant keys can also be entered in the UI at runtime. A browser tab has no
/// environment, and `dart:io` does not compile there, so the two are split
/// the way `csv_export.dart` splits file writing.
library;

export 'atlas_configuration_native.dart'
    if (dart.library.js_interop) 'atlas_configuration_web.dart';
