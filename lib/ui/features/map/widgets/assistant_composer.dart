import 'package:flutter/widgets.dart';

/// In-session draft and reading position, owned above the chat presentation.
///
/// On a phone the conversation is a route that is popped on the way back to
/// the map, so anything kept only in its state would be lost each trip.
class AssistantComposer {
  /// The unsent question.
  final TextEditingController input = TextEditingController();

  /// Scrolls the transcript that is currently on screen.
  final ScrollController transcript = ScrollController();

  /// Whether new messages should scroll the transcript to its end.
  ///
  /// False while the reader has scrolled back to something earlier.
  bool followLatest = true;

  /// Where the reader was when the transcript last left the screen.
  double? readingOffset;

  /// Releases the controllers.
  void dispose() {
    input.dispose();
    transcript.dispose();
  }
}
