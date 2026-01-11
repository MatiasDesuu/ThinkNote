import '../../database/models/note.dart';

class NoteLinkMatch {
  final String title;
  final String originalText;
  final int start;
  final int end;

  const NoteLinkMatch({
    required this.title,
    required this.originalText,
    required this.start,
    required this.end,
  });

  @override
  String toString() {
    return 'NoteLinkMatch(title: $title, start: $start, end: $end)';
  }
}

class NoteLinkDetector {
  static final RegExp _noteLinkRegex = RegExp(
    r'\[\[note:([^\[\]]+)\]\]',
    caseSensitive: false,
  );

  static List<NoteLinkMatch> detectNoteLinks(String text) {
    final List<NoteLinkMatch> noteLinks = [];
    final matches = _noteLinkRegex.allMatches(text);

    for (final match in matches) {
      final fullMatch = match.group(0)!;
      final title = match.group(1)!.trim();

      noteLinks.add(
        NoteLinkMatch(
          title: title,
          originalText: fullMatch,
          start: match.start,
          end: match.end,
        ),
      );
    }

    return noteLinks;
  }

  static bool hasNoteLinks(String text) {
    return _noteLinkRegex.hasMatch(text);
  }

  static List<String> suggestNoteTitle(
    String partialTitle,
    List<Note> availableNotes,
  ) {
    if (partialTitle.isEmpty) return [];

    final lowercaseInput = partialTitle.toLowerCase();
    return availableNotes
        .where((note) => note.title.toLowerCase().contains(lowercaseInput))
        .map((note) => note.title)
        .take(10)
        .toList();
  }

  static String createNoteLinkText(String title) {
    return '[[note:${title.trim()}]]';
  }
}
