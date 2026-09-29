import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Whether [saveCsvExport] can write a file the user can get at afterwards.
///
/// iOS has no Downloads folder, but the app declares `UIFileSharingEnabled`
/// and `LSSupportsOpeningDocumentsInPlace`, so its documents folder is the
/// app's folder in Files — a written export is reachable there.
bool get canSaveCsvExport =>
    Platform.isMacOS ||
    Platform.isWindows ||
    Platform.isLinux ||
    Platform.isIOS;

/// Writes [contents] as [fileName] and returns the full path written.
///
/// Exports go to the user's Downloads folder, which is where the rest of the
/// desktop puts a file it produced without asking. A platform without one —
/// iOS, where [getDownloadsDirectory] throws — falls back to the app's own
/// documents folder rather than failing, so the data is never lost for want
/// of a location.
Future<String> saveCsvExport({
  required String fileName,
  required String contents,
}) async {
  Directory? directory;
  try {
    directory = await getDownloadsDirectory();
  } on UnsupportedError {
    directory = null;
  }
  directory ??= await getApplicationDocumentsDirectory();
  await directory.create(recursive: true);
  final file = File(p.join(directory.path, fileName));
  await file.writeAsString(contents, flush: true);
  return file.path;
}
