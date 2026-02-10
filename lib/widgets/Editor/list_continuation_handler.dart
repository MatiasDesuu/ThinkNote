import 'package:flutter/material.dart';
import 'list_handler.dart';
import 'format_handler.dart';

class ListContinuationHandler {
  static bool handleEnterKey(
    TextEditingController controller,
    bool isShiftPressed,
  ) {
    if (isShiftPressed) {
      return false;
    }

    final selection = controller.selection;
    if (!selection.isValid || !selection.isCollapsed) {
      return false;
    }

    final text = controller.text;
    final cursorPosition = selection.baseOffset;

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
      return false;
    }

    if (listItem.content.trim().isEmpty) {
      final lineStart = textBeforeCursor.lastIndexOf('\n') + 1;

      final newText = '${text.substring(0, lineStart)}$textAfterCursor';

      controller.value = controller.value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: lineStart),
      );

      return true;
    }

    final continuationMarker = ListDetector.getContinuationMarker(currentLine);

    if (continuationMarker.isEmpty) {
      return false;
    }

    final newText = '$textBeforeCursor\n$continuationMarker$textAfterCursor';

    final newCursorPosition = cursorPosition + 1 + continuationMarker.length;

    controller.value = controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPosition),
    );

    return true;
  }

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

    if (listItem.content.trim().isEmpty) {
      final newText = text.replaceRange(lineStart, cursor, '');
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: lineStart),
      );
      return true;
    }

    final marker = ListDetector.getContinuationMarker(precedingLine);
    if (marker.isEmpty) {
      return false;
    }

    final newText = text.replaceRange(cursor, cursor, marker);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursor + marker.length),
    );
    return true;
  }

  static bool isInListItem(TextEditingController controller) {
    final selection = controller.selection;
    if (!selection.isValid || !selection.isCollapsed) {
      return false;
    }

    final text = controller.text;
    final cursorPosition = selection.baseOffset;

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

  static ListItem? getCurrentListItem(TextEditingController controller) {
    final selection = controller.selection;
    if (!selection.isValid || !selection.isCollapsed) {
      return null;
    }

    final text = controller.text;
    final cursorPosition = selection.baseOffset;

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
