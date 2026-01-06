import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'link_handler.dart';

/// A widget that detects and formats lists in text content
class ListHandler extends StatelessWidget {
  final String text;
  final TextStyle textStyle;
  final bool enableListDetection;
  final Function(String)? onTextChanged;
  final TextEditingController? controller;

  const ListHandler({
    super.key,
    required this.text,
    required this.textStyle,
    this.enableListDetection = true,
    this.onTextChanged,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (!enableListDetection || text.isEmpty) {
      return Text(text, style: textStyle);
    }

    final spans = _buildTextSpansWithLists(context);
    return RichText(
      text: TextSpan(children: spans),
      textAlign: TextAlign.start,
    );
  }

  List<TextSpan> _buildTextSpansWithLists(BuildContext context) {
    final lines = text.split('\n');
    final List<TextSpan> spans = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final listItem = ListDetector.detectListItem(line, lineNumber: i);

      if (listItem != null && listItem.type == ListType.checkbox) {
        // Handle checkbox with clickable functionality
        spans.add(_buildCheckboxSpan(context, listItem, i));
      } else if (listItem != null) {
        // Add other list items with subtle styling and link detection
        final listSpans = _buildSpansWithLinks(
          context,
          listItem.formattedText,
          textStyle.copyWith(
            fontWeight:
                FontWeight.normal, // Normal weight to match regular text
          ),
        );
        spans.addAll(listSpans);
      } else {
        // Regular text with link detection
        final lineSpans = _buildSpansWithLinks(context, line, textStyle);
        spans.addAll(lineSpans);
      }

      // Add newline except for the last line
      if (i < lines.length - 1) {
        spans.add(TextSpan(text: '\n', style: textStyle));
      }
    }

    return spans;
  }

  TextSpan _buildCheckboxSpan(
    BuildContext context,
    ListItem listItem,
    int lineIndex,
  ) {
    final List<InlineSpan> children = [];

    if (listItem.indentLevel > 0) {
      children.add(
        TextSpan(text: '  ' * listItem.indentLevel, style: textStyle),
      );
    }

    children.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: GestureDetector(
          onTap: () => _toggleCheckbox(lineIndex, listItem),
          child: Padding(
            padding: const EdgeInsets.only(right: 6.0),
            child: Icon(
              listItem.isChecked
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: (textStyle.fontSize ?? 16.0) + 4.0,
              color:
                  listItem.isChecked
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );

    // Add content with link detection and subtle styling
    final contentSpans = _buildSpansWithLinks(
      context,
      listItem.content,
      textStyle.copyWith(
        fontWeight: FontWeight.normal, // Normal weight like regular text
        color:
            listItem.isChecked
                ? Colors.grey
                : textStyle.color, // Subtle color for checkbox
      ),
    );
    children.addAll(contentSpans);

    return TextSpan(children: children);
  }

  void _toggleCheckbox(int lineIndex, ListItem listItem) {
    if (onTextChanged == null && controller == null) return;

    final lines = text.split('\n');
    if (lineIndex >= lines.length) return;

    final currentLine = lines[lineIndex];
    final newCheckedState = !listItem.isChecked;

    // Replace the checkbox state in the line
    final newLine = currentLine.replaceFirst(
      RegExp(r'-\s?\[[x\s]*\]'),
      newCheckedState ? '-[x]' : '-[ ]',
    );

    lines[lineIndex] = newLine;
    final newText = lines.join('\n');

    if (controller != null) {
      controller!.text = newText;
    }

    onTextChanged?.call(newText);
  }

  List<TextSpan> _buildSpansWithLinks(
    BuildContext context,
    String text,
    TextStyle style,
  ) {
    final List<TextSpan> spans = [];
    final links = LinkDetector.detectLinks(text);
    if (links.isEmpty) {
      spans.add(TextSpan(text: text, style: style));
      return spans;
    }
    int lastIndex = 0;
    for (final link in links) {
      if (link.start > lastIndex) {
        spans.add(
          TextSpan(text: text.substring(lastIndex, link.start), style: style),
        );
      }
      spans.add(
        TextSpan(
          text: link.originalText,
          style: style.copyWith(
            color: Theme.of(context).colorScheme.primary,
            decoration: TextDecoration.none,
            fontWeight: FontWeight.w600,
          ),
          recognizer:
              TapGestureRecognizer()
                ..onTap = () => LinkLauncher.launchURL(link.url),
        ),
      );
      lastIndex = link.end;
    }
    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex), style: style));
    }
    return spans;
  }
}

/// Enum for different list types
enum ListType {
  numbered, // 1), 2), 3)
  bullet, // -, •
  checkbox, // - [ ], - [x]
}

/// Represents a detected list item
class ListItem {
  final ListType type;
  final String marker;
  final String content;
  final String formattedText;
  final int indentLevel;
  final int lineNumber;
  final bool isChecked; // For checkbox items

  const ListItem({
    required this.type,
    required this.marker,
    required this.content,
    required this.formattedText,
    required this.indentLevel,
    required this.lineNumber,
    this.isChecked = false,
  });

  @override
  String toString() {
    return 'ListItem(type: $type, marker: $marker, content: $content, indent: $indentLevel, checked: $isChecked)';
  }
}

/// A utility class for detecting lists in text
class ListDetector {
  // Regex patterns for different list types
  static final RegExp _numberedListRegex = RegExp(r'^\s*(\d+)\.\s+(.*)$');
  static final RegExp _bulletListRegex = RegExp(r'^\s*([-•])\s+(.*)$');
  static final RegExp _checkboxListRegex = RegExp(
    r'^\s*-\s?\[\s*([x\s]?)\s*\]\s*(.*)$',
    caseSensitive: false,
  );

  /// Detects if a line is a list item and returns ListItem if found
  static ListItem? detectListItem(String line, {int lineNumber = 0}) {
    // Check for checkbox lists first (- [ ] or - [x])
    final checkboxMatch = _checkboxListRegex.firstMatch(line);
    if (checkboxMatch != null) {
      final checkState = checkboxMatch.group(1)?.trim() ?? '';
      final content = checkboxMatch.group(2)!;
      final indentLevel = _calculateIndentLevel(line);
      final isChecked = checkState.toLowerCase() == 'x';

      return ListItem(
        type: ListType.checkbox,
        marker: isChecked ? '-[x]' : '-[ ]',
        content: content,
        formattedText:
            '${_getIndentString(indentLevel)}${isChecked ? '[✓]' : '[ ]'} $content',
        indentLevel: indentLevel,
        lineNumber: lineNumber,
        isChecked: isChecked,
      );
    }

    // Check for numbered lists (1. 2. 3. etc.)
    final numberedMatch = _numberedListRegex.firstMatch(line);
    if (numberedMatch != null) {
      final marker = '${numberedMatch.group(1)}.';
      final content = numberedMatch.group(2)!;
      final indentLevel = _calculateIndentLevel(line);

      return ListItem(
        type: ListType.numbered,
        marker: marker,
        content: content,
        formattedText: '${_getIndentString(indentLevel)}$marker $content',
        indentLevel: indentLevel,
        lineNumber: lineNumber,
      );
    }

    // Check for bullet lists (-, •)
    final bulletMatch = _bulletListRegex.firstMatch(line);
    if (bulletMatch != null) {
      final marker = bulletMatch.group(1)!;
      final content = bulletMatch.group(2)!;
      final indentLevel = _calculateIndentLevel(line);

      return ListItem(
        type: ListType.bullet,
        marker: marker,
        content: content,
        formattedText: '${_getIndentString(indentLevel)}• $content',
        indentLevel: indentLevel,
        lineNumber: lineNumber,
      );
    }
    return null;
  }

  /// Detects all list items in a text block
  static List<ListItem> detectAllListItems(String text) {
    final lines = text.split('\n');
    final List<ListItem> listItems = [];

    for (int i = 0; i < lines.length; i++) {
      final listItem = detectListItem(lines[i], lineNumber: i);
      if (listItem != null) {
        listItems.add(listItem);
      }
    }

    return listItems;
  }

  /// Checks if a string contains any list items
  static bool hasListItems(String text) {
    final lines = text.split('\n');
    for (final line in lines) {
      if (detectListItem(line) != null) {
        return true;
      }
    }
    return false;
  }

  /// Groups consecutive list items together
  static List<List<ListItem>> groupConsecutiveLists(List<ListItem> items) {
    if (items.isEmpty) return [];

    final List<List<ListItem>> groups = [];
    List<ListItem> currentGroup = [items.first];

    for (int i = 1; i < items.length; i++) {
      final current = items[i];
      final previous = items[i - 1];

      // Check if this item is consecutive to the previous one
      if (current.lineNumber == previous.lineNumber + 1 ||
          (current.lineNumber == previous.lineNumber + 2 &&
              current.type == previous.type)) {
        currentGroup.add(current);
      } else {
        // Start a new group
        groups.add(currentGroup);
        currentGroup = [current];
      }
    }

    // Add the last group
    if (currentGroup.isNotEmpty) {
      groups.add(currentGroup);
    }

    return groups;
  }

  /// Calculates the indentation level of a line
  static int _calculateIndentLevel(String line) {
    int spaces = 0;
    for (int i = 0; i < line.length; i++) {
      if (line[i] == ' ') {
        spaces++;
      } else if (line[i] == '\t') {
        spaces += 4; // Treat tab as 4 spaces
      } else {
        break;
      }
    }
    return (spaces / 2).floor(); // Every 2 spaces = 1 indent level
  }

  /// Generates indent string for a given level
  static String _getIndentString(int level) {
    return '  ' * level; // 2 spaces per level
  }

  /// Converts a numbered list item to the next number
  static String getNextNumberedListItem(String currentLine) {
    final match = _numberedListRegex.firstMatch(currentLine);
    if (match != null) {
      final currentNumber = int.tryParse(match.group(1)!) ?? 1;
      final nextNumber = currentNumber + 1;
      final indent = _getIndentString(_calculateIndentLevel(currentLine));
      return '$indent$nextNumber. ';
    }
    return '1. ';
  }

  /// Gets the appropriate list marker for continuing a list
  static String getContinuationMarker(String currentLine) {
    final listItem = detectListItem(currentLine);
    if (listItem == null) return '';

    final indent = _getIndentString(listItem.indentLevel);

    switch (listItem.type) {
      case ListType.numbered:
        final match = _numberedListRegex.firstMatch(currentLine);
        if (match != null) {
          final currentNumber = int.tryParse(match.group(1)!) ?? 1;
          final nextNumber = currentNumber + 1;
          return '$indent$nextNumber. ';
        }
        return '${indent}1. ';
      case ListType.bullet:
        return '$indent- ';
      case ListType.checkbox:
        return '$indent-[ ] ';
    }
  }
}

/// A text field that automatically detects and formats lists
class ListAwareTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final TextStyle? style;
  final String? hintText;
  final bool readOnly;
  final int? maxLines;
  final bool expands;
  final Function(String)? onChanged;
  final bool enableListDetection;
  final bool autoFormatLists;
  final ScrollController? scrollController;

  const ListAwareTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.style,
    this.hintText,
    this.readOnly = false,
    this.maxLines,
    this.expands = false,
    this.onChanged,
    this.enableListDetection = true,
    this.autoFormatLists = true,
    this.scrollController,
  });

  @override
  State<ListAwareTextField> createState() => _ListAwareTextFieldState();
}

class _ListAwareTextFieldState extends State<ListAwareTextField> {
  @override
  Widget build(BuildContext context) {
    if (widget.readOnly && widget.enableListDetection) {
      // In read-only mode, show formatted lists with clickable checkboxes
      return SingleChildScrollView(
        controller: widget.scrollController,
        child: ListHandler(
          text: widget.controller.text,
          textStyle: widget.style ?? Theme.of(context).textTheme.bodyMedium!,
          enableListDetection: widget.enableListDetection,
          controller: widget.controller,
          onTextChanged: widget.onChanged,
        ),
      );
    }

    // In edit mode, show regular TextField with auto-formatting
    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      style: widget.style,
      maxLines: widget.maxLines,
      expands: widget.expands,
      readOnly: widget.readOnly,
      scrollController: widget.scrollController,
      decoration: InputDecoration(
        border: InputBorder.none,
        hintText: widget.hintText,
      ),
      onChanged: widget.autoFormatLists ? _handleTextChange : widget.onChanged,
    );
  }

  void _handleTextChange(String value) {
    if (!widget.autoFormatLists) {
      widget.onChanged?.call(value);
      return;
    }

    // Check if user pressed Enter after a list item
    final selection = widget.controller.selection;
    if (selection.isValid && selection.isCollapsed) {
      final cursorPosition = selection.baseOffset;
      final textBeforeCursor = value.substring(0, cursorPosition);
      final lines = textBeforeCursor.split('\n');

      if (lines.isNotEmpty) {
        final currentLine = lines.last;
        final previousLine = lines.length > 1 ? lines[lines.length - 2] : '';

        // Check if user just pressed Enter after a list item
        if (currentLine.isEmpty &&
            ListDetector.detectListItem(previousLine) != null) {
          final continuationMarker = ListDetector.getContinuationMarker(
            previousLine,
          );

          if (continuationMarker.isNotEmpty) {
            // Insert the continuation marker
            final newText =
                value.substring(0, cursorPosition) +
                continuationMarker +
                value.substring(cursorPosition);

            widget.controller.value = TextEditingValue(
              text: newText,
              selection: TextSelection.collapsed(
                offset: cursorPosition + continuationMarker.length,
              ),
            );

            widget.onChanged?.call(newText);
            return;
          }
        }
      }
    }

    widget.onChanged?.call(value);
  }
}

/// Utility functions for list operations
class ListUtils {
  /// Converts plain text with list patterns to formatted text
  static String formatListsInText(String text) {
    final lines = text.split('\n');
    final formattedLines = <String>[];

    for (final line in lines) {
      final listItem = ListDetector.detectListItem(line);
      if (listItem != null) {
        formattedLines.add(listItem.formattedText);
      } else {
        formattedLines.add(line);
      }
    }

    return formattedLines.join('\n');
  }

  /// Extracts all list items from text as plain strings
  static List<String> extractListItems(String text) {
    final listItems = ListDetector.detectAllListItems(text);
    return listItems.map((item) => item.content).toList();
  }

  /// Counts the number of list items in text
  static int countListItems(String text) {
    return ListDetector.detectAllListItems(text).length;
  }

  /// Gets statistics about lists in the text
  static Map<String, int> getListStatistics(String text) {
    final listItems = ListDetector.detectAllListItems(text);
    final stats = <String, int>{
      'total': listItems.length,
      'numbered': 0,
      'bullet': 0,
      'checkbox': 0,
    };

    for (final item in listItems) {
      switch (item.type) {
        case ListType.numbered:
          stats['numbered'] = (stats['numbered'] ?? 0) + 1;
          break;
        case ListType.bullet:
          stats['bullet'] = (stats['bullet'] ?? 0) + 1;
          break;
        case ListType.checkbox:
          stats['checkbox'] = (stats['checkbox'] ?? 0) + 1;
          break;
      }
    }

    return stats;
  }
}
