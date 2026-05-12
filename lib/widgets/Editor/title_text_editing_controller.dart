import 'package:flutter/material.dart';

class TitleTextEditingController extends TextEditingController {
  TitleTextEditingController({super.text});

  static bool _isEmojiLikeGrapheme(String grapheme) {
    if (grapheme.isEmpty) return false;
    final int firstRune = grapheme.runes.first;

    bool inRange(int start, int end) => firstRune >= start && firstRune <= end;

    return inRange(0x1F1E6, 0x1F1FF) ||
        inRange(0x1F300, 0x1F5FF) ||
        inRange(0x1F600, 0x1F64F) ||
        inRange(0x1F680, 0x1F6FF) ||
        inRange(0x1F700, 0x1F77F) ||
        inRange(0x1F780, 0x1F7FF) ||
        inRange(0x1F800, 0x1F8FF) ||
        inRange(0x1F900, 0x1F9FF) ||
        inRange(0x1FA00, 0x1FAFF) ||
        inRange(0x2600, 0x26FF) ||
        inRange(0x2700, 0x27BF);
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final composingIsValid =
        value.composing.isValid && withComposing && value.isComposingRangeValid;
    final children = <InlineSpan>[];
    var plainBuffer = StringBuffer();
    var offset = 0;

    void flushPlainText() {
      if (plainBuffer.isEmpty) return;
      children.add(TextSpan(text: plainBuffer.toString()));
      plainBuffer = StringBuffer();
    }

    for (final grapheme in text.characters) {
      final graphemeEnd = offset + grapheme.length;
      final inComposing =
          composingIsValid &&
          offset >= value.composing.start &&
          graphemeEnd <= value.composing.end;

      if (_isEmojiLikeGrapheme(grapheme) && !inComposing) {
        flushPlainText();
        final fontSize = style?.fontSize ?? 24.0;
        children.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Transform.translate(
              offset: Offset(0, -fontSize * 0.16),
              child: Text(
                grapheme,
                style: style?.copyWith(
                  height: 1.0,
                  fontFamilyFallback: const [
                    'Segoe UI Emoji',
                    'Apple Color Emoji',
                    'Noto Color Emoji',
                  ],
                ),
              ),
            ),
          ),
        );
      } else {
        plainBuffer.write(grapheme);
      }

      offset = graphemeEnd;
    }

    flushPlainText();

    if (composingIsValid) {
      final composingStyle =
          style?.merge(const TextStyle(decoration: TextDecoration.underline)) ??
          const TextStyle(decoration: TextDecoration.underline);
      return TextSpan(
        style: style,
        children: [
          TextSpan(text: value.composing.textBefore(value.text)),
          TextSpan(
            style: composingStyle,
            text: value.composing.textInside(value.text),
          ),
          TextSpan(text: value.composing.textAfter(value.text)),
        ],
      );
    }

    return TextSpan(style: style, children: children);
  }
}
