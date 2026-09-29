/// Writing an export to a file, where the platform has files.
///
/// A browser tab has no writable folder and `dart:io` does not compile there,
/// so the web build reports saving as unavailable and leaves the panel's
/// clipboard copy as the way out.
library;

export 'csv_export_native.dart'
    if (dart.library.js_interop) 'csv_export_web.dart';
