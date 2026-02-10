enum ListType { numbered, bullet, checkbox }

class ListItem {
  final ListType type;
  final String marker;
  final String content;
  final String formattedText;
  final int indentLevel;
  final int lineNumber;
  final bool isChecked;

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

class ListDetector {
  static final RegExp _numberedListRegex = RegExp(r'^\s*(\d+)\.\s(.*)$');
  static final RegExp _bulletListRegex = RegExp(r'^\s*([-•◦▪])\s(.*)$');
  static final RegExp _checkboxListRegex = RegExp(
    r'^\s*([-•◦▪])\s?\[\s*([x\s]?)\s*\]\s(.*)$',
    caseSensitive: false,
  );

  static ListItem? detectListItem(String line, {int lineNumber = 0}) {
    final checkboxMatch = _checkboxListRegex.firstMatch(line);
    if (checkboxMatch != null) {
      final marker = checkboxMatch.group(1)!;
      final checkState = checkboxMatch.group(2)?.trim() ?? '';
      final content = checkboxMatch.group(3)!;
      final indentLevel = calculateIndentLevel(line);
      final isChecked = checkState.toLowerCase() == 'x';

      return ListItem(
        type: ListType.checkbox,
        marker: marker,
        content: content,
        formattedText:
            '${_getIndentString(indentLevel)}${isChecked ? '[✓]' : '[ ]'} $content',
        indentLevel: indentLevel,
        lineNumber: lineNumber,
        isChecked: isChecked,
      );
    }

    final numberedMatch = _numberedListRegex.firstMatch(line);
    if (numberedMatch != null) {
      final marker = '${numberedMatch.group(1)}.';
      final content = numberedMatch.group(2)!;
      final indentLevel = calculateIndentLevel(line);

      return ListItem(
        type: ListType.numbered,
        marker: marker,
        content: content,
        formattedText: '${_getIndentString(indentLevel)}$marker $content',
        indentLevel: indentLevel,
        lineNumber: lineNumber,
      );
    }

    final bulletMatch = _bulletListRegex.firstMatch(line);
    if (bulletMatch != null) {
      final marker = bulletMatch.group(1)!;
      final content = bulletMatch.group(2)!;
      final indentLevel = calculateIndentLevel(line);

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

  static bool hasListItems(String text) {
    final lines = text.split('\n');
    for (final line in lines) {
      if (detectListItem(line) != null) {
        return true;
      }
    }
    return false;
  }

  static List<List<ListItem>> groupConsecutiveLists(List<ListItem> items) {
    if (items.isEmpty) return [];

    final List<List<ListItem>> groups = [];
    List<ListItem> currentGroup = [items.first];

    for (int i = 1; i < items.length; i++) {
      final current = items[i];
      final previous = items[i - 1];

      if (current.lineNumber == previous.lineNumber + 1 ||
          (current.lineNumber == previous.lineNumber + 2 &&
              current.type == previous.type)) {
        currentGroup.add(current);
      } else {
        groups.add(currentGroup);
        currentGroup = [current];
      }
    }

    if (currentGroup.isNotEmpty) {
      groups.add(currentGroup);
    }

    return groups;
  }

  static int calculateIndentLevel(String line) {
    int spaces = 0;
    for (int i = 0; i < line.length; i++) {
      if (line[i] == ' ') {
        spaces++;
      } else if (line[i] == '\t') {
        spaces += 4;
      } else {
        break;
      }
    }
    return spaces;
  }

  static String _getIndentString(int level) {
    return '\t' * (level ~/ 4) + ' ' * (level % 4);
  }

  static String getNextNumberedListItem(String currentLine) {
    final match = _numberedListRegex.firstMatch(currentLine);
    if (match != null) {
      final currentNumber = int.tryParse(match.group(1)!) ?? 1;
      final nextNumber = currentNumber + 1;
      final indent = _getIndentString(calculateIndentLevel(currentLine));
      return '$indent$nextNumber. ';
    }
    return '1. ';
  }

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

class ListUtils {
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

  static List<String> extractListItems(String text) {
    final listItems = ListDetector.detectAllListItems(text);
    return listItems.map((item) => item.content).toList();
  }

  static int countListItems(String text) {
    return ListDetector.detectAllListItems(text).length;
  }

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
        case ListType.bullet:
          stats['bullet'] = (stats['bullet'] ?? 0) + 1;
        case ListType.checkbox:
          stats['checkbox'] = (stats['checkbox'] ?? 0) + 1;
      }
    }

    return stats;
  }
}
