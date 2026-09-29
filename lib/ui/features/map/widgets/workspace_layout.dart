import 'package:flutter/widgets.dart';

/// Presentation is chosen before the keyboard consumes any layout space.
abstract final class WorkspaceLayout {
  static bool isCompact(Size size) => size.width < 744 || size.height < 600;

  static bool compactOf(BuildContext context) =>
      isCompact(MediaQuery.sizeOf(context));
}
