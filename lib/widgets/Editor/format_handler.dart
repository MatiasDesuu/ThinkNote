import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';

/// A widget that detects and formats markdown text formatting
class FormatHandler extends StatefulWidget {
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
  State<FormatHandler> createState() => _FormatHandlerState();
}

class _FormatHandlerState extends State<FormatHandler> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enableFormatDetection || widget.text.isEmpty) {
      return Text(widget.text, style: widget.textStyle);
    }

    // Dispose old recognizers before building new ones
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    final spans = _buildTextSpansWithFormatting(context);
    return RichText(
      text: TextSpan(children: spans),
      textAlign: TextAlign.start,
    );
  }

  List<TextSpan> _buildTextSpansWithFormatting(BuildContext context) {
    return FormatDetector.buildFormattedSpans(
      widget.text,
      widget.textStyle,
      context,
      recognizers: _recognizers,
    );
  }
}

/// Enum for different format types
enum FormatType {
  bold, // **text** or __text__
  italic, // *text* or _text_
  strikethrough, // ~~text~~
  code, // `text`
  heading1, // # text
  heading2, // ## text
  heading3, // ### text
  heading4, // #### text
  heading5, // ##### text
  numbered, // 1. text
  bullet, // - text
  asterisk, // * text
  checkboxUnchecked, // [ ] text
  checkboxChecked, // [x] text
  noteLink, // [[text]]
  link, // [text](url)
  url, // http://...
  horizontalRule, // * * * (horizontal divider line)
  insertScript, // #script at the top
  convertToScript, // #1 block
  taggedCode, // [text]
  normal, // regular text
}

/// Represents a detected format segment
class FormatSegment {
  final FormatType type;
  final String text;
  final String originalText;
  final int start;
  final int end;
  final String? data; // Extra data like URL for links

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

/// A utility class for detecting and formatting markdown text
class FormatDetector {
  static final List<_FormatPattern> _patterns = [
    // Headings (Precedence over inline)
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
    // Horizontal Rule (must be before asterisk list)
    _FormatPattern(
      type: FormatType.horizontalRule,
      regex: RegExp(r'^\* \* \*$', multiLine: true),
      contentExtractor: (m) => m.group(0)!,
    ),
    // Lists
    _FormatPattern(
      type: FormatType.numbered,
      regex: RegExp(r'^\s*\d+\.\s+(.+)$', multiLine: true),
      contentExtractor: (m) => m.group(0)!,
    ),
    _FormatPattern(
      type: FormatType.bullet,
      regex: RegExp(r'^\s*[-•]\s+(.+)$', multiLine: true),
      contentExtractor: (m) => m.group(0)!,
    ),
    _FormatPattern(
      type: FormatType.asterisk,
      regex: RegExp(r'^\s*\*\s+(.+)$', multiLine: true),
      contentExtractor: (m) => m.group(0)!,
    ),
    _FormatPattern(
      type: FormatType.checkboxUnchecked,
      regex: RegExp(r'^\s*-\s?\[\s*(\s?)\s*\]\s*(.+)$', multiLine: true),
      contentExtractor: (m) => m.group(0)!,
    ),
    _FormatPattern(
      type: FormatType.checkboxChecked,
      regex: RegExp(r'^\s*-\s?\[\s*([xX])\s*\]\s*(.+)$', multiLine: true),
      contentExtractor: (m) => m.group(0)!,
    ),
    // Inline Formatting
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
      type: FormatType.noteLink,
      regex: RegExp(r'\[\[([^\[\]]+)\]\]'),
      contentExtractor: (m) => m.group(0)!, // Keep brackets
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
      regex: RegExp(r'(?<!\[)\[([^\[\]]+)\](?![(\[])'),
      contentExtractor: (m) => m.group(1) ?? '',
    ),
  ];

  /// Builds formatted text spans from markdown text
  static List<TextSpan> buildFormattedSpans(
    String text,
    TextStyle baseStyle,
    BuildContext context, {
    List<TapGestureRecognizer>? recognizers,
  }) {
    if (text.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }
    final segments = parseSegments(text);
    if (segments.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }
    final List<TextSpan> spans = [];
    int lastIndex = 0;
    for (final segment in segments) {
      if (segment.start > lastIndex) {
        final beforeText = text.substring(lastIndex, segment.start);
        if (beforeText.isNotEmpty) {
          spans.addAll(
            _buildNestedFormattedSpans(
              beforeText,
              baseStyle,
              context,
              recognizers: recognizers,
            ),
          );
        }
      }
      spans.add(
        _buildFormattedSpan(
          segment,
          baseStyle,
          context,
          recognizers: recognizers,
        ),
      );
      lastIndex = segment.end;
    }
    if (lastIndex < text.length) {
      final remainingText = text.substring(lastIndex);
      if (remainingText.isNotEmpty) {
        spans.addAll(
          _buildNestedFormattedSpans(
            remainingText,
            baseStyle,
            context,
            recognizers: recognizers,
          ),
        );
      }
    }
    return spans.isNotEmpty ? spans : [TextSpan(text: text, style: baseStyle)];
  }

  /// Parses text and returns format segments in order
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

    // Sort segments by start position
    segments.sort((a, b) => a.start.compareTo(b.start));

    return segments;
  }

  /// Checks if a match overlaps with existing segments
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

  /// Builds a formatted TextSpan for a segment
  static TextSpan _buildFormattedSpan(
    FormatSegment segment,
    TextStyle baseStyle,
    BuildContext context, {
    List<TapGestureRecognizer>? recognizers,
  }) {
    TextStyle style = baseStyle;
    TapGestureRecognizer? recognizer;

    switch (segment.type) {
      case FormatType.bold:
        style = baseStyle.copyWith(fontWeight: FontWeight.bold);
        break;
      case FormatType.italic:
        style = baseStyle.copyWith(fontStyle: FontStyle.italic);
        break;
      case FormatType.strikethrough:
        style = baseStyle.copyWith(
          decoration: TextDecoration.lineThrough,
          decorationColor: baseStyle.color,
        );
        break;
      case FormatType.code:
        return TextSpan(
          children: [
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withAlpha(128),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withAlpha(40),
                  ),
                ),
                child: Text(
                  segment.text,
                  style: baseStyle.copyWith(
                    fontFamily: 'monospace',
                    fontSize: (baseStyle.fontSize ?? 16) * 0.9,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        );
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
      case FormatType.noteLink:
        style = baseStyle.copyWith(
          color: Theme.of(context).colorScheme.primary,
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.w500,
        );
        break;
      case FormatType.link:
      case FormatType.url:
        style = baseStyle.copyWith(
          color: Colors.blue,
          decoration: TextDecoration.underline,
        );
        if (segment.data != null && recognizers != null) {
          recognizer =
              TapGestureRecognizer()
                ..onTap = () async {
                  final url = Uri.parse(segment.data!);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                };
          recognizers.add(recognizer);
        }
        break;
      case FormatType.horizontalRule:
        // Return empty span - the actual divider is rendered separately
        return TextSpan(text: '', style: baseStyle);
      case FormatType.insertScript:
      case FormatType.convertToScript:
      case FormatType.numbered:
      case FormatType.bullet:
      case FormatType.asterisk:
      case FormatType.checkboxUnchecked:
      case FormatType.checkboxChecked:
      case FormatType.taggedCode:
        return TextSpan(
          children: [
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withAlpha(128),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withAlpha(40),
                  ),
                ),
                child: Text(
                  segment.text,
                  style: baseStyle.copyWith(
                    fontFamily: 'monospace',
                    fontSize: (baseStyle.fontSize ?? 16) * 0.9,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        );
      case FormatType.normal:
        style = baseStyle;
        break;
    }

    return TextSpan(text: segment.text, style: style, recognizer: recognizer);
  }

  /// Builds nested formatted spans for text that may contain multiple formats
  static List<TextSpan> _buildNestedFormattedSpans(
    String text,
    TextStyle baseStyle,
    BuildContext context, {
    List<TapGestureRecognizer>? recognizers,
  }) {
    final segments = parseSegments(text);
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
      spans.add(
        _buildFormattedSpan(
          segment,
          baseStyle,
          context,
          recognizers: recognizers,
        ),
      );
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
    return _patterns.any((pattern) => pattern.regex.hasMatch(text));
  }

  /// Strips all markdown formatting from text
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
        .replaceAll(RegExp(r'\[\[([^\[\]]+)\]\]'), r'$1')
        .replaceAll(RegExp(r'\[([^\]]+)\]\(([^)]+)\)'), r'$1')
        .replaceAll(RegExp(r'(?<!\[)\[([^\[\]]+)\](?![(\[])'), r'$1');
  }

  /// Gets statistics about formatting in the text
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
  // Regex to match horizontal rule pattern
  static final RegExp _horizontalRuleRegex = RegExp(r'^\* \* \*$');

  @override
  Widget build(BuildContext context) {
    if (widget.readOnly && widget.enableFormatDetection) {
      // In read-only mode, show formatted text with horizontal rules as Dividers
      return SingleChildScrollView(
        controller: widget.scrollController,
        child: _buildFormattedContent(context),
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

  /// Builds content with horizontal rules rendered as actual Divider widgets
  Widget _buildFormattedContent(BuildContext context) {
    final text = widget.controller.text;
    final lines = text.split('\n');
    final textStyle = widget.style ?? Theme.of(context).textTheme.bodyMedium!;
    final colorScheme = Theme.of(context).colorScheme;

    final List<Widget> widgets = [];
    final StringBuffer currentTextBuffer = StringBuffer();
    bool isAfterDivider = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (_horizontalRuleRegex.hasMatch(line.trim())) {
        // Flush any accumulated text before the horizontal rule
        if (currentTextBuffer.isNotEmpty) {
          widgets.add(
            FormatHandler(
              text: currentTextBuffer.toString(),
              textStyle: textStyle,
              enableFormatDetection: widget.enableFormatDetection,
            ),
          );
          currentTextBuffer.clear();
        }

        // Add the horizontal rule divider
        widgets.add(
          Divider(
            height: 12,
            thickness: 2,
            color: colorScheme.outline.withAlpha(100),
          ),
        );
        isAfterDivider = true;
      } else {
        // Accumulate text lines
        if (isAfterDivider && line.isEmpty) {
          if (currentTextBuffer.isNotEmpty) {
            currentTextBuffer.write('\n');
          }
          currentTextBuffer.write(' ');
          isAfterDivider = false;
        } else {
          if (currentTextBuffer.isNotEmpty) {
            currentTextBuffer.write('\n');
          }
          currentTextBuffer.write(line);
          isAfterDivider = false;
        }
      }
    }

    // Flush remaining text
    if (currentTextBuffer.isNotEmpty) {
      widgets.add(
        FormatHandler(
          text: currentTextBuffer.toString(),
          textStyle: textStyle,
          enableFormatDetection: widget.enableFormatDetection,
        ),
      );
    }

    // If there's only one widget and it's a FormatHandler, return it directly
    if (widgets.length == 1 && widgets.first is FormatHandler) {
      return widgets.first;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
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
    final segments = FormatDetector.parseSegments(text);
    return segments.map((segment) => segment.text).toList();
  }

  /// Counts the number of formatted segments in text
  static int countFormattedSegments(String text) {
    return FormatDetector.parseSegments(text).length;
  }

  /// Wraps selected text with markdown formatting
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
      case FormatType.numbered:
        wrappedText = '1. $selectedText';
        break;
      case FormatType.bullet:
        wrappedText = '- $selectedText';
        break;
      case FormatType.asterisk:
        wrappedText = '* $selectedText';
        break;
      case FormatType.checkboxUnchecked:
        wrappedText = '-[ ] $selectedText';
        break;
      case FormatType.checkboxChecked:
        wrappedText = '-[x] $selectedText';
        break;
      case FormatType.noteLink:
        wrappedText = '[[$selectedText]]';
        break;
      case FormatType.link:
        wrappedText = '[$selectedText]()';
        break;
      case FormatType.url:
        wrappedText =
            selectedText; // URLs are usually auto-detected, no specific wrapping
        break;
      case FormatType.horizontalRule:
        wrappedText = '* * *';
        break;
      case FormatType.insertScript:
        wrappedText = '#script\n$selectedText';
        break;
      case FormatType.convertToScript:
        wrappedText = '#1\n$selectedText';
        break;
      case FormatType.taggedCode:
        wrappedText = '[$selectedText]';
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

  /// Checks if text has a specific format
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
      case FormatType.asterisk:
        return RegExp(r'^\*\s+.*$').hasMatch(text);
      case FormatType.checkboxUnchecked:
        return RegExp(r'^-?\[ \]\s+.*$').hasMatch(text);
      case FormatType.checkboxChecked:
        return RegExp(r'^-?\[x\]\s+.*$').hasMatch(text);
      case FormatType.noteLink:
        return RegExp(r'^\[\[.*\]\]$').hasMatch(text);
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
