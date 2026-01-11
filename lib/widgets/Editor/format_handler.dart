enum FormatType {
  bold,
  italic,
  strikethrough,
  code,
  heading1,
  heading2,
  heading3,
  heading4,
  heading5,
  numbered,
  bullet,
  checkboxUnchecked,
  checkboxChecked,
  noteLink,
  notebookLink,
  link,
  url,
  horizontalRule,
  insertScript,
  convertToScript,
  taggedCode,
  normal,
}

class FormatSegment {
  final FormatType type;
  final String text;
  final String originalText;
  final int start;
  final int end;
  final String? data;

  const FormatSegment({
    required this.type,
    required this.text,
    required this.originalText,
    required this.start,
    required this.end,
    this.data,
  });

  @override
  String toString() {
    return 'FormatSegment(type: $type, text: $text, start: $start, end: $end, data: $data)';
  }
}

class _FormatPattern {
  final FormatType type;
  final RegExp regex;
  final String Function(RegExpMatch) contentExtractor;
  final String? Function(RegExpMatch)? dataExtractor;

  const _FormatPattern({
    required this.type,
    required this.regex,
    required this.contentExtractor,
    this.dataExtractor,
  });
}

class FormatDetector {
  static final RegExp horizontalRuleRegex = RegExp(r'^\* \* \*$');

  static final List<_FormatPattern> _patterns = [
    _FormatPattern(
      type: FormatType.heading1,
      regex: RegExp(r'^#\s+(.+)$', multiLine: true),
      contentExtractor: (m) => m.group(1) ?? '',
    ),
    _FormatPattern(
      type: FormatType.heading2,
      regex: RegExp(r'^##\s+(.+)$', multiLine: true),
      contentExtractor: (m) => m.group(1) ?? '',
    ),
    _FormatPattern(
      type: FormatType.heading3,
      regex: RegExp(r'^###\s+(.+)$', multiLine: true),
      contentExtractor: (m) => m.group(1) ?? '',
    ),
    _FormatPattern(
      type: FormatType.heading4,
      regex: RegExp(r'^####\s+(.+)$', multiLine: true),
      contentExtractor: (m) => m.group(1) ?? '',
    ),
    _FormatPattern(
      type: FormatType.heading5,
      regex: RegExp(r'^#####\s+(.+)$', multiLine: true),
      contentExtractor: (m) => m.group(1) ?? '',
    ),
    _FormatPattern(
      type: FormatType.horizontalRule,
      regex: RegExp(r'^\* \* \*$', multiLine: true),
      contentExtractor: (m) => m.group(0)!,
    ),
    _FormatPattern(
      type: FormatType.numbered,
      regex: RegExp(r'^\s*\d+\.\s(.*)$', multiLine: true),
      contentExtractor: (m) => m.group(0)!,
    ),
    _FormatPattern(
      type: FormatType.bullet,
      regex: RegExp(r'^\s*([-•◦▪])\s(.*)$', multiLine: true),
      contentExtractor: (m) => m.group(0)!,
    ),
    _FormatPattern(
      type: FormatType.checkboxUnchecked,
      regex: RegExp(r'^\s*([-•◦▪])\s?\[\s*(\s?)\s*\]\s(.+)$', multiLine: true),
      contentExtractor: (m) => m.group(0)!,
    ),
    _FormatPattern(
      type: FormatType.checkboxChecked,
      regex: RegExp(r'^\s*([-•◦▪])\s?\[\s*([xX])\s*\]\s(.+)$', multiLine: true),
      contentExtractor: (m) => m.group(0)!,
    ),
    _FormatPattern(
      type: FormatType.bold,
      regex: RegExp(r'\*\*(.*?)\*\*|__(.*?)__', dotAll: true),
      contentExtractor: (m) => m.group(1) ?? m.group(2) ?? '',
    ),
    _FormatPattern(
      type: FormatType.italic,
      regex: RegExp(r'\*(.*?)\*|_(.*?)_', dotAll: true),
      contentExtractor: (m) => m.group(1) ?? m.group(2) ?? '',
    ),
    _FormatPattern(
      type: FormatType.strikethrough,
      regex: RegExp(r'~~(.*?)~~', dotAll: true),
      contentExtractor: (m) => m.group(1) ?? '',
    ),
    _FormatPattern(
      type: FormatType.code,
      regex: RegExp(r'`(.*?)`', dotAll: true),
      contentExtractor: (m) => m.group(1) ?? '',
    ),
    _FormatPattern(
      type: FormatType.notebookLink,
      regex: RegExp(r'\[\[notebook:([^\[\]]+)\]\]'),
      contentExtractor: (m) => m.group(0)!,
    ),
    _FormatPattern(
      type: FormatType.noteLink,
      regex: RegExp(r'\[\[note:([^\[\]]+)\]\]'),
      contentExtractor: (m) => m.group(0)!,
    ),
    _FormatPattern(
      type: FormatType.link,
      regex: RegExp(r'\[([^\]]+)\]\(([^)]+)\)'),
      contentExtractor: (m) => m.group(1) ?? '',
      dataExtractor: (m) => m.group(2) ?? '',
    ),
    _FormatPattern(
      type: FormatType.url,
      regex: RegExp(
        r'(?:https?://|www\.)[^\s<>"{}|\\^`[\]]+',
        caseSensitive: false,
      ),
      contentExtractor: (m) => m.group(0)!,
      dataExtractor: (m) => m.group(0)!,
    ),
    _FormatPattern(
      type: FormatType.taggedCode,
      regex: RegExp(r'(?<!\[)\[([^\[\]]+)\]'),
      contentExtractor: (m) => m.group(1) ?? '',
    ),
  ];

  static List<FormatSegment> parseSegments(String text) {
    final List<FormatSegment> segments = [];

    for (final pattern in _patterns) {
      final matches = pattern.regex.allMatches(text);
      for (final match in matches) {
        final content = pattern.contentExtractor(match);
        if (content.isNotEmpty && !_isOverlapping(match, segments)) {
          segments.add(
            FormatSegment(
              type: pattern.type,
              text: content,
              originalText: match.group(0)!,
              start: match.start,
              end: match.end,
              data: pattern.dataExtractor?.call(match),
            ),
          );
        }
      }
    }

    segments.sort((a, b) => a.start.compareTo(b.start));
    return segments;
  }

  static bool _isOverlapping(
    RegExpMatch match,
    List<FormatSegment> existingSegments,
  ) {
    for (final segment in existingSegments) {
      if (match.start < segment.end && match.end > segment.start) {
        return true;
      }
    }
    return false;
  }

  static bool hasFormatting(String text) {
    return _patterns.any((pattern) => pattern.regex.hasMatch(text));
  }

  static String stripFormatting(String text) {
    return text
        .replaceAll(RegExp(r'\*\*(.*?)\*\*|__(.*?)__'), r'$1$2')
        .replaceAll(RegExp(r'\*(.*?)\*|_(.*?)_'), r'$1$2')
        .replaceAll(RegExp(r'~~(.*?)~~'), r'$1')
        .replaceAll(RegExp(r'`(.*?)`'), r'$1')
        .replaceAll(RegExp(r'^#\s+(.+)$', multiLine: true), r'$1')
        .replaceAll(RegExp(r'^##\s+(.+)$', multiLine: true), r'$1')
        .replaceAll(RegExp(r'^###\s+(.+)$', multiLine: true), r'$1')
        .replaceAll(RegExp(r'^####\s+(.+)$', multiLine: true), r'$1')
        .replaceAll(RegExp(r'^#####\s+(.+)$', multiLine: true), r'$1')
        .replaceAll(RegExp(r'^\d+\.\s+(.+)$', multiLine: true), r'$1')
        .replaceAll(RegExp(r'^- \s+(.+)$|^-\s+(.+)$', multiLine: true), r'$1$2')
        .replaceAll(RegExp(r'^\*\s+(.+)$', multiLine: true), r'$1')
        .replaceAll(RegExp(r'^-? ?\[ \]\s+(.+)$', multiLine: true), r'$1')
        .replaceAll(RegExp(r'^-? ?\[x\]\s+(.+)$', multiLine: true), r'$1')
        .replaceAll(RegExp(r'\[\[note:([^\[\]]+)\]\]'), r'$1')
        .replaceAll(RegExp(r'\[\[notebook:([^\[\]]+)\]\]'), r'$1')
        .replaceAll(RegExp(r'\[([^\]]+)\]\(([^)]+)\)'), r'$1')
        .replaceAll(RegExp(r'(?<!\[)\[([^\[\]]+)\](?![(\[])'), r'$1');
  }

  static Map<String, int> getFormatStatistics(String text) {
    final stats = <String, int>{};
    int total = 0;

    for (final pattern in _patterns) {
      final count = pattern.regex.allMatches(text).length;
      stats[pattern.type.toString().split('.').last] = count;
      total += count;
    }

    stats['total'] = total;
    return stats;
  }
}

class FormatUtils {
  static String formatTextForDisplay(String text) {
    return text;
  }

  static List<String> extractFormattedSegments(String text) {
    final segments = FormatDetector.parseSegments(text);
    return segments.map((segment) => segment.text).toList();
  }

  static int countFormattedSegments(String text) {
    return FormatDetector.parseSegments(text).length;
  }

  static String wrapWithFormat(
    String text,
    int start,
    int end,
    FormatType formatType,
  ) {
    if (start < 0 || end > text.length || start >= end) {
      return text;
    }

    final selectedText = text.substring(start, end);
    String wrappedText;

    switch (formatType) {
      case FormatType.bold:
        wrappedText = '**$selectedText**';
      case FormatType.italic:
        wrappedText = '*$selectedText*';
      case FormatType.strikethrough:
        wrappedText = '~~$selectedText~~';
      case FormatType.code:
        wrappedText = '`$selectedText`';
      case FormatType.heading1:
        wrappedText = '# $selectedText';
      case FormatType.heading2:
        wrappedText = '## $selectedText';
      case FormatType.heading3:
        wrappedText = '### $selectedText';
      case FormatType.heading4:
        wrappedText = '#### $selectedText';
      case FormatType.heading5:
        wrappedText = '##### $selectedText';
      case FormatType.numbered:
        wrappedText = '1. $selectedText';
      case FormatType.bullet:
        wrappedText = '- $selectedText';
      case FormatType.checkboxUnchecked:
        wrappedText = '-[ ] $selectedText';
      case FormatType.checkboxChecked:
        wrappedText = '-[x] $selectedText';
      case FormatType.noteLink:
        wrappedText = '[[note:$selectedText]]';
      case FormatType.notebookLink:
        wrappedText = '[[notebook:$selectedText]]';
      case FormatType.link:
        wrappedText = '[$selectedText]()';
      case FormatType.url:
        wrappedText = selectedText;
      case FormatType.horizontalRule:
        wrappedText = '* * *';
      case FormatType.insertScript:
        wrappedText = '#script\n$selectedText';
      case FormatType.convertToScript:
        wrappedText = '#1\n$selectedText';
      case FormatType.taggedCode:
        wrappedText = '[$selectedText]';
      case FormatType.normal:
        wrappedText = selectedText;
    }

    return text.substring(0, start) + wrappedText + text.substring(end);
  }

  static String removeFormatting(String text, int start, int end) {
    if (start < 0 || end > text.length || start >= end) {
      return text;
    }

    final beforeText = text.substring(0, start);
    final selectedText = text.substring(start, end);
    final afterText = text.substring(end);

    final cleanedText = FormatDetector.stripFormatting(selectedText);
    return beforeText + cleanedText + afterText;
  }

  static String toggleFormat(
    String text,
    int start,
    int end,
    FormatType formatType,
  ) {
    if (start < 0 || end > text.length || start >= end) {
      return text;
    }

    final selectedText = text.substring(start, end);
    final hasFormat = _hasSpecificFormat(selectedText, formatType);

    if (hasFormat) {
      return removeFormatting(text, start, end);
    } else {
      return wrapWithFormat(text, start, end, formatType);
    }
  }

  static bool _hasSpecificFormat(String text, FormatType formatType) {
    switch (formatType) {
      case FormatType.bold:
        return RegExp(r'^\*\*.*\*\*$|^__.*__$').hasMatch(text);
      case FormatType.italic:
        return RegExp(r'^\*.*\*$|^_.*_$').hasMatch(text) &&
            !RegExp(r'^\*\*.*\*\*$').hasMatch(text);
      case FormatType.strikethrough:
        return RegExp(r'^~~.*~~$').hasMatch(text);
      case FormatType.code:
        return RegExp(r'^`.*`$').hasMatch(text);
      case FormatType.heading1:
        return RegExp(r'^#\s+.*$').hasMatch(text);
      case FormatType.heading2:
        return RegExp(r'^##\s+.*$').hasMatch(text);
      case FormatType.heading3:
        return RegExp(r'^###\s+.*$').hasMatch(text);
      case FormatType.heading4:
        return RegExp(r'^####\s+.*$').hasMatch(text);
      case FormatType.heading5:
        return RegExp(r'^#####\s+.*$').hasMatch(text);
      case FormatType.numbered:
        return RegExp(r'^\d+\.\s+.*$').hasMatch(text);
      case FormatType.bullet:
        return RegExp(r'^- \s+.*$|^-\s+.*$').hasMatch(text);
      case FormatType.checkboxUnchecked:
        return RegExp(r'^-?\[ \]\s+.*$').hasMatch(text);
      case FormatType.checkboxChecked:
        return RegExp(r'^-?\[x\]\s+.*$').hasMatch(text);
      case FormatType.noteLink:
        return RegExp(r'^\[\[note:.*\]\]$').hasMatch(text);
      case FormatType.notebookLink:
        return RegExp(r'^\[\[notebook:.*\]\]$').hasMatch(text);
      case FormatType.link:
        return RegExp(r'^\[.*\]\(.*\)$').hasMatch(text);
      case FormatType.url:
        return RegExp(
          r'^(?:https?://|www\.)[^\s<>"{}|\\^`[\]]+$',
        ).hasMatch(text);
      case FormatType.horizontalRule:
        return RegExp(r'^\* \* \*$').hasMatch(text);
      case FormatType.insertScript:
        return text.startsWith('#script');
      case FormatType.convertToScript:
        return RegExp(r'^#\d+\n').hasMatch(text);
      case FormatType.taggedCode:
        return RegExp(r'^\[.*\]$').hasMatch(text) &&
            !RegExp(r'^\[\[.*\]\]$').hasMatch(text) &&
            !RegExp(r'^\[.*\]\(.*\)$').hasMatch(text);
      case FormatType.normal:
        return false;
    }
  }
}
