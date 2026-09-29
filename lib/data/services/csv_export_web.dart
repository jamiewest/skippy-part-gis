/// Whether [saveCsvExport] can write a file on this platform.
///
/// A browser tab cannot, so the export panel offers the clipboard instead.
bool get canSaveCsvExport => false;

/// Always throws: the web build has nowhere to write a file.
Future<String> saveCsvExport({
  required String fileName,
  required String contents,
}) {
  throw UnsupportedError('The web build cannot write files.');
}
