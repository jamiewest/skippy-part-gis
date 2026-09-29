import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// Platform boundary for sharing property text and exported address lists.
abstract interface class ContentSharing {
  Future<void> shareText(String text, Rect origin);
  Future<void> shareCsv(String contents, String fileName, Rect origin);
}

class NativeContentSharing implements ContentSharing {
  const NativeContentSharing();

  @override
  Future<void> shareText(String text, Rect origin) async {
    await SharePlus.instance.share(
      ShareParams(text: text, sharePositionOrigin: origin),
    );
  }

  @override
  Future<void> shareCsv(String contents, String fileName, Rect origin) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(utf8.encode(contents), mimeType: 'text/csv')],
        fileNameOverrides: [fileName],
        sharePositionOrigin: origin,
      ),
    );
  }
}

/// Override in tests or an embedding application without invoking native UI.
class SharingScope extends InheritedWidget {
  const SharingScope({super.key, required this.service, required super.child});
  final ContentSharing service;
  static ContentSharing of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SharingScope>()?.service ??
      const NativeContentSharing();
  @override
  bool updateShouldNotify(SharingScope oldWidget) =>
      service != oldWidget.service;
}

/// Anchors native popovers to the action that opened them.
Rect sharingOrigin(BuildContext context) {
  final box = context.findRenderObject()! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}

Future<void> shareProperty(BuildContext context, String text) async {
  try {
    await SharingScope.of(context).shareText(text, sharingOrigin(context));
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not share. You can still copy these details.'),
        ),
      );
    }
  }
}
