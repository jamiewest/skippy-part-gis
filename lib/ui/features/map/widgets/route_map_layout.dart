import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// Keep a useful map area visible above the panel on narrow screens.
Rect routePanelRect(Size size, EdgeInsets reserved) {
  final compact = size.width < 600;
  final height = math.max(
    120.0,
    compact
        ? math.min(470.0, (size.height - reserved.vertical) * 0.55)
        : size.height - reserved.vertical - 70,
  );
  return Rect.fromLTWH(
    reserved.left + 12,
    compact ? size.height - reserved.bottom - 88 - height : reserved.top + 12,
    math.max(
      180,
      math.min(
        compact ? double.infinity : 390,
        size.width - reserved.horizontal - (compact ? 24 : 90),
      ),
    ),
    height,
  );
}

EdgeInsets routeCameraPadding(Size size, EdgeInsets reserved, bool panelOpen) {
  final panel = routePanelRect(size, reserved);
  return EdgeInsets.fromLTRB(
    panelOpen && size.width >= 600 ? panel.right + 24 : 32,
    reserved.top + 48,
    reserved.right + 110,
    panelOpen && size.width < 600
        ? size.height - panel.top + 24
        : reserved.bottom + 52,
  );
}
