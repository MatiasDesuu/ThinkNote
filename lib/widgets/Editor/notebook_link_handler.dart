class NotebookLinkMatch {
  final String name;
  final String originalText;
  final int start;
  final int end;

  const NotebookLinkMatch({
    required this.name,
    required this.originalText,
    required this.start,
    required this.end,
  });

  @override
  String toString() {
    return 'NotebookLinkMatch(name: $name, start: $start, end: $end)';
  }
}

class NotebookLinkDetector {
  static final RegExp _notebookLinkRegex = RegExp(
    r'\[\[notebook:([^\[\]]+)\]\]',
    caseSensitive: false,
  );

  static List<NotebookLinkMatch> detectNotebookLinks(String text) {
    final List<NotebookLinkMatch> notebookLinks = [];
    final matches = _notebookLinkRegex.allMatches(text);

    for (final match in matches) {
      final fullMatch = match.group(0)!;
      final name = match.group(1)!.trim();

      notebookLinks.add(
        NotebookLinkMatch(
          name: name,
          originalText: fullMatch,
          start: match.start,
          end: match.end,
        ),
      );
    }

    return notebookLinks;
  }

  static bool hasNotebookLinks(String text) {
    return _notebookLinkRegex.hasMatch(text);
  }

  static String createNotebookLinkText(String name) {
    return '[[notebook:${name.trim()}]]';
  }
}
