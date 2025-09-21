import 'package:flutter/material.dart';

/// A widget that detects and formats markdown text formatting
class FormatHandler extends StatelessWidget {
  final String text;
  final TextStyle textStyle;
  final bool enableFormatDetection;

  const FormatHandler({
    super.key,
    required this.text,
    required this.textStyle,
    this.enableFormatDetection = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enableFormatDetection || text.isEmpty) {
      return Text(text, style: textStyle);
    }
    final spans = _buildTextSpansWithFormatting(context);
    return RichText(
      text: TextSpan(children: spans),
      textAlign: TextAlign.start,
    );
  }

  List<TextSpan> _buildTextSpansWithFormatting(BuildContext context) {
    return FormatDetector.buildFormattedSpans(text, textStyle, context);
  }
}

/// Enum for different format types
enum FormatType {
  bold,        // **text** or __text__
  italic,      // *text* or _text_
  strikethrough, // ~~text~~
  code,        // `text`
  heading1,    // # text
  heading2,    // ## text
  heading3,    // ### text
  heading4,    // #### text
  heading5,    // ##### text
  normal,      // regular text
}

/// Represents a detected format segment
class FormatSegment {
  final FormatType type;
  final String text;
  final String originalText;
  final int start;
  final int end;

  const FormatSegment({
    required this.type,
    required this.text,
    required this.originalText,
    required this.start,
    required this.end,
  });

  @override
  String toString() {
    return 'FormatSegment(type: $type, text: $text, start: $start, end: $end)';
  }
}

/// A utility class for detecting and formatting markdown text
class FormatDetector {
  // Regex patterns for different format types
  static final RegExp _boldRegex = RegExp(r'\*\*(.*?)\*\*|__(.*?)__');
  static final RegExp _italicRegex = RegExp(r'\*(.*?)\*|_(.*?)_');
  static final RegExp _strikethroughRegex = RegExp(r'~~(.*?)~~');
  static final RegExp _codeRegex = RegExp(r'`(.*?)`');
  static final RegExp _heading1Regex = RegExp(r'^#\s+(.+)$', multiLine: true);
  static final RegExp _heading2Regex = RegExp(r'^##\s+(.+)$', multiLine: true);
  static final RegExp _heading3Regex = RegExp(r'^###\s+(.+)$', multiLine: true);
  static final RegExp _heading4Regex = RegExp(r'^####\s+(.+)$', multiLine: true);
  static final RegExp _heading5Regex = RegExp(r'^#####\s+(.+)$', multiLine: true);
  
  /// Builds formatted text spans from markdown text
  static List<TextSpan> buildFormattedSpans(String text, TextStyle baseStyle, BuildContext context) {
    if (text.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }
    final segments = _parseFormatSegments(text);
    if (segments.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }
    final List<TextSpan> spans = [];
    int lastIndex = 0;
    for (final segment in segments) {
      if (segment.start > lastIndex) {
        final beforeText = text.substring(lastIndex, segment.start);
        if (beforeText.isNotEmpty) {
          spans.addAll(_buildNestedFormattedSpans(beforeText, baseStyle, context));
        }
      }
      spans.add(_buildFormattedSpan(segment, baseStyle, context));
      lastIndex = segment.end;
    }
    if (lastIndex < text.length) {
      final remainingText = text.substring(lastIndex);
      if (remainingText.isNotEmpty) {
        spans.addAll(_buildNestedFormattedSpans(remainingText, baseStyle, context));
      }
    }
    return spans.isNotEmpty ? spans : [TextSpan(text: text, style: baseStyle)];
  }

  /// Parses text and returns format segments in order
  static List<FormatSegment> _parseFormatSegments(String text) {
    final List<FormatSegment> segments = [];
    
    // Find all format matches
    final boldMatches = _boldRegex.allMatches(text);
    final italicMatches = _italicRegex.allMatches(text);
    final strikethroughMatches = _strikethroughRegex.allMatches(text);
    final codeMatches = _codeRegex.allMatches(text);
    final heading1Matches = _heading1Regex.allMatches(text);
    final heading2Matches = _heading2Regex.allMatches(text);
    final heading3Matches = _heading3Regex.allMatches(text);
    final heading4Matches = _heading4Regex.allMatches(text);
    final heading5Matches = _heading5Regex.allMatches(text);

    // Process heading matches first (they take precedence over inline formatting)
    for (final match in heading1Matches) {
      final content = match.group(1) ?? '';
      if (content.isNotEmpty && !_isOverlapping(match, segments)) {
        segments.add(FormatSegment(
          type: FormatType.heading1,
          text: content,
          originalText: match.group(0)!,
          start: match.start,
          end: match.end,
        ));
      }
    }

    for (final match in heading2Matches) {
      final content = match.group(1) ?? '';
      if (content.isNotEmpty && !_isOverlapping(match, segments)) {
        segments.add(FormatSegment(
          type: FormatType.heading2,
          text: content,
          originalText: match.group(0)!,
          start: match.start,
          end: match.end,
        ));
      }
    }

    for (final match in heading3Matches) {
      final content = match.group(1) ?? '';
      if (content.isNotEmpty && !_isOverlapping(match, segments)) {
        segments.add(FormatSegment(
          type: FormatType.heading3,
          text: content,
          originalText: match.group(0)!,
          start: match.start,
          end: match.end,
        ));
      }
    }

    for (final match in heading4Matches) {
      final content = match.group(1) ?? '';
      if (content.isNotEmpty && !_isOverlapping(match, segments)) {
        segments.add(FormatSegment(
          type: FormatType.heading4,
          text: content,
          originalText: match.group(0)!,
          start: match.start,
          end: match.end,
        ));
      }
    }

    for (final match in heading5Matches) {
      final content = match.group(1) ?? '';
      if (content.isNotEmpty && !_isOverlapping(match, segments)) {
        segments.add(FormatSegment(
          type: FormatType.heading5,
          text: content,
          originalText: match.group(0)!,
          start: match.start,
          end: match.end,
        ));
      }
    }

    // Process bold matches
    for (final match in boldMatches) {
      final content = match.group(1) ?? match.group(2) ?? '';
      if (content.isNotEmpty && !_isOverlapping(match, segments)) {
        segments.add(FormatSegment(
          type: FormatType.bold,
          text: content,
          originalText: match.group(0)!,
          start: match.start,
          end: match.end,
        ));
      }
    }

    // Process italic matches (avoid overlap with bold)
    for (final match in italicMatches) {
      final content = match.group(1) ?? match.group(2) ?? '';
      if (content.isNotEmpty && !_isOverlapping(match, segments)) {
        segments.add(FormatSegment(
          type: FormatType.italic,
          text: content,
          originalText: match.group(0)!,
          start: match.start,
          end: match.end,
        ));
      }
    }

    // Process strikethrough matches
    for (final match in strikethroughMatches) {
      final content = match.group(1) ?? '';
      if (content.isNotEmpty && !_isOverlapping(match, segments)) {
        segments.add(FormatSegment(
          type: FormatType.strikethrough,
          text: content,
          originalText: match.group(0)!,
          start: match.start,
          end: match.end,
        ));
      }
    }

    // Process code matches
    for (final match in codeMatches) {
      final content = match.group(1) ?? '';
      if (content.isNotEmpty && !_isOverlapping(match, segments)) {
        segments.add(FormatSegment(
          type: FormatType.code,
          text: content,
          originalText: match.group(0)!,
          start: match.start,
          end: match.end,
        ));
      }
    }

    // Sort segments by start position
    segments.sort((a, b) => a.start.compareTo(b.start));
    
    return segments;
  }

  /// Checks if a match overlaps with existing segments
  static bool _isOverlapping(RegExpMatch match, List<FormatSegment> existingSegments) {
    for (final segment in existingSegments) {
      if (match.start < segment.end && match.end > segment.start) {
        return true;
      }
    }
    return false;
  }

  /// Builds a formatted TextSpan for a segment
  static TextSpan _buildFormattedSpan(FormatSegment segment, TextStyle baseStyle, BuildContext context) {
    TextStyle style = baseStyle;
    
    switch (segment.type) {
      case FormatType.bold:
        style = baseStyle.copyWith(
          fontWeight: FontWeight.bold,
        );
        break;
      case FormatType.italic:
        style = baseStyle.copyWith(
          fontStyle: FontStyle.italic,
        );
        break;
      case FormatType.strikethrough:
        style = baseStyle.copyWith(
          decoration: TextDecoration.lineThrough,
          decorationColor: baseStyle.color,
        );
        break;
      case FormatType.code:
        style = baseStyle.copyWith(
          backgroundColor: Theme.of(context).colorScheme.error.withAlpha(100),
          color: Theme.of(context).colorScheme.onError,
        );
        break;
      case FormatType.heading1:
        style = baseStyle.copyWith(
          fontSize: (baseStyle.fontSize ?? 16) * 2.0,
          fontWeight: FontWeight.bold,
        );
        break;
      case FormatType.heading2:
        style = baseStyle.copyWith(
          fontSize: (baseStyle.fontSize ?? 16) * 1.5,
          fontWeight: FontWeight.bold,
        );
        break;
      case FormatType.heading3:
        style = baseStyle.copyWith(
          fontSize: (baseStyle.fontSize ?? 16) * 1.3,
          fontWeight: FontWeight.bold,
        );
        break;
      case FormatType.heading4:
        style = baseStyle.copyWith(
          fontSize: (baseStyle.fontSize ?? 16) * 1.2,
          fontWeight: FontWeight.bold,
        );
        break;
      case FormatType.heading5:
        style = baseStyle.copyWith(
          fontSize: (baseStyle.fontSize ?? 16) * 1.1,
          fontWeight: FontWeight.bold,
        );
        break;
      case FormatType.normal:
        style = baseStyle;
        break;
    }

    return TextSpan(
      text: segment.text,
      style: style,
    );
  }

  /// Builds nested formatted spans for text that may contain multiple formats
  static List<TextSpan> _buildNestedFormattedSpans(String text, TextStyle baseStyle, BuildContext context) {
    final segments = _parseFormatSegments(text);
    if (segments.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }
    final List<TextSpan> spans = [];
    int lastIndex = 0;
    for (final segment in segments) {
      if (segment.start > lastIndex) {
        final beforeText = text.substring(lastIndex, segment.start);
        if (beforeText.isNotEmpty) {
          spans.add(TextSpan(text: beforeText, style: baseStyle));
        }
      }
      spans.add(_buildFormattedSpan(segment, baseStyle, context));
      lastIndex = segment.end;
    }
    if (lastIndex < text.length) {
      final remainingText = text.substring(lastIndex);
      if (remainingText.isNotEmpty) {
        spans.add(TextSpan(text: remainingText, style: baseStyle));
      }
    }
    return spans;
  }

  /// Detects if text contains any markdown formatting
  static bool hasFormatting(String text) {
    return _boldRegex.hasMatch(text) ||
           _italicRegex.hasMatch(text) ||
           _strikethroughRegex.hasMatch(text) ||
           _codeRegex.hasMatch(text) ||
           _heading1Regex.hasMatch(text) ||
           _heading2Regex.hasMatch(text) ||
           _heading3Regex.hasMatch(text) ||
           _heading4Regex.hasMatch(text) ||
           _heading5Regex.hasMatch(text);
  }

  /// Strips all markdown formatting from text
  static String stripFormatting(String text) {
    return text
        .replaceAll(_boldRegex, r'$1$2')
        .replaceAll(_italicRegex, r'$1$2')
        .replaceAll(_strikethroughRegex, r'$1')
        .replaceAll(_codeRegex, r'$1')
        .replaceAll(_heading1Regex, r'$1')
        .replaceAll(_heading2Regex, r'$1')
        .replaceAll(_heading3Regex, r'$1')
        .replaceAll(_heading4Regex, r'$1')
        .replaceAll(_heading5Regex, r'$1');
  }

  /// Gets statistics about formatting in the text
  static Map<String, int> getFormatStatistics(String text) {
    final stats = <String, int>{
      'bold': _boldRegex.allMatches(text).length,
      'italic': _italicRegex.allMatches(text).length,
      'strikethrough': _strikethroughRegex.allMatches(text).length,
      'code': _codeRegex.allMatches(text).length,
      'heading1': _heading1Regex.allMatches(text).length,
      'heading2': _heading2Regex.allMatches(text).length,
      'heading3': _heading3Regex.allMatches(text).length,
      'heading4': _heading4Regex.allMatches(text).length,
      'heading5': _heading5Regex.allMatches(text).length,
    };
    
    stats['total'] = stats.values.fold(0, (sum, count) => sum + count);
    return stats;
  }
}

/// A text field that automatically detects and displays markdown formatting in read mode
class FormatAwareTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final TextStyle? style;
  final String? hintText;
  final bool readOnly;
  final int? maxLines;
  final bool expands;
  final Function(String)? onChanged;
  final bool enableFormatDetection;
  final ScrollController? scrollController;

  const FormatAwareTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.style,
    this.hintText,
    this.readOnly = false,
    this.maxLines,
    this.expands = false,
    this.onChanged,
    this.enableFormatDetection = true,
    this.scrollController,
  });

  @override
  State<FormatAwareTextField> createState() => _FormatAwareTextFieldState();
}

class _FormatAwareTextFieldState extends State<FormatAwareTextField> {
  @override
  Widget build(BuildContext context) {
    if (widget.readOnly && widget.enableFormatDetection) {
      // In read-only mode, show formatted text
      return SingleChildScrollView(
        controller: widget.scrollController,
        child: FormatHandler(
          text: widget.controller.text,
          textStyle: widget.style ?? Theme.of(context).textTheme.bodyMedium!,
          enableFormatDetection: widget.enableFormatDetection,
        ),
      );
    }

    // In edit mode, show regular TextField
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
      onChanged: widget.onChanged,
    );
  }
}

/// Utility functions for format operations
class FormatUtils {
  /// Converts plain text with markdown to formatted display text
  static String formatTextForDisplay(String text) {
    // In display mode, we keep the original text since FormatHandler handles the formatting
    return text;
  }

  /// Extracts all formatted text segments
  static List<String> extractFormattedSegments(String text) {
    final segments = FormatDetector._parseFormatSegments(text);
    return segments.map((segment) => segment.text).toList();
  }

  /// Counts the number of formatted segments in text
  static int countFormattedSegments(String text) {
    return FormatDetector._parseFormatSegments(text).length;
  }

  /// Wraps selected text with markdown formatting
  static String wrapWithFormat(String text, int start, int end, FormatType formatType) {
    if (start < 0 || end > text.length || start >= end) {
      return text;
    }

    final selectedText = text.substring(start, end);
    String wrappedText;

    switch (formatType) {
      case FormatType.bold:
        wrappedText = '**$selectedText**';
        break;
      case FormatType.italic:
        wrappedText = '*$selectedText*';
        break;
      case FormatType.strikethrough:
        wrappedText = '~~$selectedText~~';
        break;
      case FormatType.code:
        wrappedText = '`$selectedText`';
        break;
      case FormatType.heading1:
        wrappedText = '# $selectedText';
        break;
      case FormatType.heading2:
        wrappedText = '## $selectedText';
        break;
      case FormatType.heading3:
        wrappedText = '### $selectedText';
        break;
      case FormatType.heading4:
        wrappedText = '#### $selectedText';
        break;
      case FormatType.heading5:
        wrappedText = '##### $selectedText';
        break;
      case FormatType.normal:
        wrappedText = selectedText;
        break;
    }

    return text.substring(0, start) + wrappedText + text.substring(end);
  }

  /// Removes formatting from selected text
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

  /// Toggles formatting for selected text
  static String toggleFormat(String text, int start, int end, FormatType formatType) {
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

  /// Checks if text has a specific format
  static bool _hasSpecificFormat(String text, FormatType formatType) {
    switch (formatType) {
      case FormatType.bold:
        return RegExp(r'^\*\*.*\*\*$|^__.*__$').hasMatch(text);
      case FormatType.italic:
        return RegExp(r'^\*.*\*$|^_.*_$').hasMatch(text) && !RegExp(r'^\*\*.*\*\*$').hasMatch(text);
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
      case FormatType.normal:
        return false;
    }
  }
}
