import 'models/bookmark.dart';
import 'bookmark_service.dart';

class HtmlGenerator {
  static Future<String> generateBookmarksHtml(
    List<Bookmark> bookmarks,
    BookmarkService bookmarkService,
  ) async {
    final buffer = StringBuffer();

    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html lang="en">');
    buffer.writeln('<head>');
    buffer.writeln('    <meta charset="UTF-8">');
    buffer.writeln('    <meta name="viewport" content="width=device-width, initial-scale=1.0">');
    buffer.writeln('    <title>ThinkNote Bookmarks</title>');
    buffer.writeln('    <style>');
    buffer.writeln('        body {');
    buffer.writeln('            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;');
    buffer.writeln('            max-width: 800px;');
    buffer.writeln('            margin: 40px auto;');
    buffer.writeln('            padding: 0 20px;');
    buffer.writeln('            line-height: 1.6;');
    buffer.writeln('            color: #333;');
    buffer.writeln('            background-color: #fff;');
    buffer.writeln('        }');
    buffer.writeln('        h1 { text-align: center; margin-bottom: 60px; font-weight: 300; }');
    buffer.writeln('        .bookmark { margin-bottom: 40px; }');
    buffer.writeln('        .bookmark-title { font-size: 1.4rem; font-weight: 600; margin-bottom: 10px; }');
    buffer.writeln('        .bookmark-title a { color: #000; text-decoration: none; }');
    buffer.writeln('        .bookmark-title a:hover { text-decoration: underline; }');
    buffer.writeln('        hr { border: 0; border-top: 1px solid #eee; margin: 20px 0; }');
    buffer.writeln('        .bookmark-text { color: #666; white-space: pre-wrap; font-size: 1.1rem; }');
    buffer.writeln('    </style>');
    buffer.writeln('</head>');
    buffer.writeln('<body>');
    buffer.writeln('    <h1>ThinkNote Bookmarks</h1>');

    for (final bookmark in bookmarks) {
      if (bookmark.hidden) continue;

      buffer.writeln('    <div class="bookmark">');
      buffer.writeln('        <div class="bookmark-title">');
      buffer.writeln(
        '            <a href="${_escapeHtml(bookmark.url)}" target="_blank">${_escapeHtml(bookmark.title)}</a>',
      );
      buffer.writeln('        </div>');
      buffer.writeln('        <hr>');
      buffer.writeln('        <div class="bookmark-text">${_escapeHtml(bookmark.description)}</div>');
      buffer.writeln('    </div>');
    }

    buffer.writeln('</body>');
    buffer.writeln('</html>');

    return buffer.toString();
  }

  static String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
