import 'package:flutter/material.dart';
import 'list_handler.dart';
import 'format_handler.dart';

class ListContinuationHandler {
  /// Handles Enter key press in the text editor
  /// Returns true if the event was handled (list continuation), false otherwise
  static bool handleEnterKey(
    TextEditingController controller,
    bool isShiftPressed,
  ) {
    // If Shift+Enter, just insert a regular newline
    if (isShiftPressed) {
      return false; // Let the default behavior handle it
    }

    final selection = controller.selection;
    if (!selection.isValid || !selection.isCollapsed) {
      return false; // Let default behavior handle multi-selection
    }

    final text = controller.text;
    final cursorPosition = selection.baseOffset;

    // Find the current line
    final textBeforeCursor = text.substring(0, cursorPosition);
    final textAfterCursor = text.substring(cursorPosition);
    final lines = textBeforeCursor.split('\n');

    if (lines.isEmpty) {
      return false;
    }

    final currentLine = lines.last;

    if (FormatDetector.horizontalRuleRegex.hasMatch(currentLine.trim())) {
      return false;
    }

    final listItem = ListDetector.detectListItem(currentLine);

    if (listItem == null) {
      return false; // Not a list item, let default behavior handle it
    }

    // Check if the current list item is empty (only contains the marker)
    if (listItem.content.trim().isEmpty) {
      // Remove the current list marker and don't insert a newline
      final lineStart = textBeforeCursor.lastIndexOf('\n') + 1;

      final newText = '${text.substring(0, lineStart)}$textAfterCursor';

      controller.text = newText;
      controller.selection = TextSelection.collapsed(offset: lineStart);

      return true;
    }

    // Generate the continuation marker
    final continuationMarker = ListDetector.getContinuationMarker(currentLine);

    if (continuationMarker.isEmpty) {
      return false;
    }

    // Insert newline and continuation marker
    final newText = '$textBeforeCursor\n$continuationMarker$textAfterCursor';
    controller.text = newText;

    // Position cursor after the marker
    final newCursorPosition = cursorPosition + 1 + continuationMarker.length;
    controller.selection = TextSelection.collapsed(offset: newCursorPosition);

    return true;
  }

  /// Handles Enter key event from virtual keyboard (where \n is already inserted)
  static bool handleVirtualKeyboardEnter(TextEditingController controller) {
    final selection = controller.selection;
    if (!selection.isValid ||
        !selection.isCollapsed ||
        selection.baseOffset < 1) {
      return false;
    }

    final text = controller.text;
    if (text[selection.baseOffset - 1] != '\n') {
      return false;
    }

    // Identify previous line (excluding the newly inserted \n)
    final cursor = selection.baseOffset;
    final searchStart = cursor - 2;
    final lineStart =
        searchStart < 0 ? 0 : (text.lastIndexOf('\n', searchStart) + 1);
    final precedingLine = text.substring(lineStart, cursor - 1);

    if (FormatDetector.horizontalRuleRegex.hasMatch(precedingLine.trim())) {
      return false;
    }

    final listItem = ListDetector.detectListItem(precedingLine);
    if (listItem == null) {
      return false;
    }

    // Case 1: Empty list item -> Terminate list (remove the item)
    // The user pressed Enter on an empty list item like "- |"
    // The text now looks like "- \n|"
    // We want to remove the "- \n" part effectively, or rather, the "- " part
    // and just leave an empty line?
    // Desktop logic removes the whole line content from the PREVIOUS state.
    // So "- |" becomes "|".
    // Here "- \n|" should become "|".
    // So we replace range [lineStart, cursor] with empty string.
    if (listItem.content.trim().isEmpty) {
      final newText = text.replaceRange(lineStart, cursor, '');
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: lineStart),
      );
      return true;
    }

    // Case 2: Continuation
    final marker = ListDetector.getContinuationMarker(precedingLine);
    if (marker.isEmpty) {
      return false;
    }

    // Insert marker at cursor
    final newText = text.replaceRange(cursor, cursor, marker);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursor + marker.length),
    );
    return true;
  }

  /// Checks if the current cursor position is in a list item
  static bool isInListItem(TextEditingController controller) {
    final selection = controller.selection;
    if (!selection.isValid || !selection.isCollapsed) {
      return false;
    }

    final text = controller.text;
    final cursorPosition = selection.baseOffset;

    // Find the current line
    final textBeforeCursor = text.substring(0, cursorPosition);
    final lines = textBeforeCursor.split('\n');

    if (lines.isEmpty) {
      return false;
    }

    final currentLine = lines.last;

    if (FormatDetector.horizontalRuleRegex.hasMatch(currentLine.trim())) {
      return false;
    }

    return ListDetector.detectListItem(currentLine) != null;
  }

  /// Gets the current list item if cursor is in one
  static ListItem? getCurrentListItem(TextEditingController controller) {
    final selection = controller.selection;
    if (!selection.isValid || !selection.isCollapsed) {
      return null;
    }

    final text = controller.text;
    final cursorPosition = selection.baseOffset;

    // Find the current line
    final textBeforeCursor = text.substring(0, cursorPosition);
    final lines = textBeforeCursor.split('\n');

    if (lines.isEmpty) {
      return null;
    }

    final currentLine = lines.last;

    if (FormatDetector.horizontalRuleRegex.hasMatch(currentLine.trim())) {
      return null;
    }

    return ListDetector.detectListItem(currentLine);
  }
}
