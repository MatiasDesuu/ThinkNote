import 'package:flutter/material.dart';
import 'list_handler.dart';

/// A utility class for handling list continuation on Enter key press
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
      controller.selection = TextSelection.collapsed(
        offset: lineStart,
      );
      
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
    return ListDetector.detectListItem(currentLine);
  }
}
