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
    buffer.writeln(
      '    <meta name="viewport" content="width=device-width, initial-scale=1.0">',
    );
    buffer.writeln('    <title>ThinkNote Bookmarks</title>');
    buffer.writeln('    <style>');
    buffer.writeln('        :root {');
    buffer.writeln('            --bg-color: #f5f5f5;');
    buffer.writeln('            --container-bg: white;');
    buffer.writeln('            --text-color: #333;');
    buffer.writeln('            --title-color: #333;');
    buffer.writeln('            --link-color: #2c5aa0;');
    buffer.writeln('            --url-color: #666;');
    buffer.writeln('            --description-color: #333;');
    buffer.writeln('            --date-color: #999;');
    buffer.writeln('            --border-color: #ddd;');
    buffer.writeln('            --bookmark-bg: #fafafa;');
    buffer.writeln('            --bookmark-hover: #f0f0f0;');
    buffer.writeln('            --tag-bg: #e1f5fe;');
    buffer.writeln('            --tag-color: #0277bd;');
    buffer.writeln('            --stats-color: #666;');
    buffer.writeln('        }');
    buffer.writeln('        ');
    buffer.writeln('        [data-theme="dark"] {');
    buffer.writeln('            --bg-color: #1a1a1a;');
    buffer.writeln('            --container-bg: #2d2d2d;');
    buffer.writeln('            --text-color: #e0e0e0;');
    buffer.writeln('            --title-color: #ffffff;');
    buffer.writeln('            --link-color: #64b5f6;');
    buffer.writeln('            --url-color: #b0b0b0;');
    buffer.writeln('            --description-color: #e0e0e0;');
    buffer.writeln('            --date-color: #888;');
    buffer.writeln('            --border-color: #444;');
    buffer.writeln('            --bookmark-bg: #3a3a3a;');
    buffer.writeln('            --bookmark-hover: #444;');
    buffer.writeln('            --tag-bg: #1e3a5f;');
    buffer.writeln('            --tag-color: #81c784;');
    buffer.writeln('            --stats-color: #b0b0b0;');
    buffer.writeln('        }');
    buffer.writeln('        ');
    buffer.writeln(
      '        body { font-family: Arial, sans-serif; margin: 20px; background-color: var(--bg-color); color: var(--text-color); transition: all 0.3s ease; }',
    );
    buffer.writeln(
      '        .container { max-width: 1200px; margin: 0 auto; background-color: var(--container-bg); padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }',
    );
    buffer.writeln(
      '        h1 { color: var(--title-color); text-align: center; margin-bottom: 30px; }',
    );
    buffer.writeln(
      '        .bookmark { margin-bottom: 20px; padding: 15px; border: 1px solid var(--border-color); border-radius: 5px; background-color: var(--bookmark-bg); transition: all 0.3s ease; }',
    );
    buffer.writeln(
      '        .bookmark:hover { background-color: var(--bookmark-hover); }',
    );
    buffer.writeln(
      '        .bookmark-title { font-size: 18px; font-weight: bold; margin-bottom: 5px; }',
    );
    buffer.writeln(
      '        .bookmark-title a { color: var(--link-color); text-decoration: none; }',
    );
    buffer.writeln(
      '        .bookmark-title a:hover { text-decoration: underline; }',
    );
    buffer.writeln(
      '        .bookmark-url { color: var(--url-color); font-size: 14px; margin-bottom: 5px; word-break: break-all; }',
    );
    buffer.writeln(
      '        .bookmark-description { color: var(--description-color); margin-bottom: 5px; }',
    );
    buffer.writeln('        .bookmark-tags { margin-top: 10px; }');
    buffer.writeln(
      '        .tag { display: inline-block; background-color: var(--tag-bg); color: var(--tag-color); padding: 2px 8px; border-radius: 12px; font-size: 12px; margin-right: 5px; margin-bottom: 5px; }',
    );
    buffer.writeln(
      '        .bookmark-date { color: var(--date-color); font-size: 12px; margin-top: 5px; }',
    );
    buffer.writeln('        .hidden { opacity: 0.6; }');
    buffer.writeln(
      '        .hidden .bookmark-title::after { content: " (Hidden)"; color: var(--date-color); font-weight: normal; }',
    );
    buffer.writeln(
      '        .stats { text-align: center; margin-bottom: 20px; color: var(--stats-color); }',
    );
    buffer.writeln(
      '        .theme-switch { position: fixed; top: 20px; right: 20px; z-index: 1000; }',
    );
    buffer.writeln(
      '        .theme-switch label { display: flex; align-items: center; cursor: pointer; background-color: var(--container-bg); padding: 8px 12px; border-radius: 20px; border: 1px solid var(--border-color); box-shadow: 0 2px 5px rgba(0,0,0,0.1); }',
    );
    buffer.writeln('        .theme-switch input { display: none; }');
    buffer.writeln(
      '        .theme-switch .slider { width: 40px; height: 20px; background-color: #ccc; border-radius: 20px; position: relative; margin-left: 8px; transition: 0.3s; }',
    );
    buffer.writeln(
      '        .theme-switch .slider:before { content: ""; position: absolute; height: 16px; width: 16px; left: 2px; bottom: 2px; background-color: white; border-radius: 50%; transition: 0.3s; }',
    );
    buffer.writeln(
      '        .theme-switch input:checked + .slider { background-color: #2196F3; }',
    );
    buffer.writeln(
      '        .theme-switch input:checked + .slider:before { transform: translateX(20px); }',
    );
    buffer.writeln('        .theme-switch .icon { font-size: 16px;}');
    buffer.writeln(
      '        .theme-switch .icon-night { font-size: 16px; margin-left: 5px; }',
    );
    buffer.writeln('    </style>');
    buffer.writeln('</head>');
    buffer.writeln('<body>');
    buffer.writeln('    <div class="theme-switch">');
    buffer.writeln('        <label>');
    buffer.writeln('            <span class="icon">☀️</span>');
    buffer.writeln('            <input type="checkbox" id="theme-toggle">');
    buffer.writeln('            <span class="slider"></span>');
    buffer.writeln('            <span class="icon-night">🌙</span>');
    buffer.writeln('        </label>');
    buffer.writeln('    </div>');
    buffer.writeln('    <div class="container">');
    buffer.writeln('        <h1>ThinkNote Bookmarks</h1>');

    final totalBookmarks = bookmarks.length;
    final visibleBookmarks = bookmarks.where((b) => !b.hidden).length;
    final hiddenBookmarks = bookmarks.where((b) => b.hidden).length;

    buffer.writeln('        <div class="stats">');
    buffer.writeln(
      '            <p>Total: $totalBookmarks | Visible: $visibleBookmarks | Hidden: $hiddenBookmarks</p>',
    );
    buffer.writeln('        </div>');

    for (final bookmark in bookmarks) {
      final cssClass = bookmark.hidden ? 'bookmark hidden' : 'bookmark';
      buffer.writeln('        <div class="$cssClass">');
      buffer.writeln('            <div class="bookmark-title">');
      buffer.writeln(
        '                <a href="${_escapeHtml(bookmark.url)}" target="_blank">${_escapeHtml(bookmark.title)}</a>',
      );
      buffer.writeln('            </div>');
      buffer.writeln(
        '            <div class="bookmark-url">${_escapeHtml(bookmark.url)}</div>',
      );

      if (bookmark.description.isNotEmpty) {
        buffer.writeln(
          '            <div class="bookmark-description">${_escapeHtml(bookmark.description)}</div>',
        );
      }

      if (bookmark.id != null) {
        final tags = await bookmarkService.getTagsByBookmarkId(bookmark.id!);
        if (tags.isNotEmpty) {
          buffer.writeln('            <div class="bookmark-tags">');
          for (final tag in tags) {
            buffer.writeln(
              '                <span class="tag">${_escapeHtml(tag)}</span>',
            );
          }
          buffer.writeln('            </div>');
        }
      }

      // Fecha
      final date = DateTime.tryParse(bookmark.timestamp);
      if (date != null) {
        final formattedDate =
            '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
        buffer.writeln(
          '            <div class="bookmark-date">Added: $formattedDate</div>',
        );
      }

      buffer.writeln('        </div>');
    }

    buffer.writeln('    </div>');
    buffer.writeln('    <script>');
    buffer.writeln('        // Theme toggle functionality');
    buffer.writeln(
      '        const themeToggle = document.getElementById("theme-toggle");',
    );
    buffer.writeln('        const html = document.documentElement;');
    buffer.writeln('        ');
    buffer.writeln(
      '        // Check for saved theme preference or default to light theme',
    );
    buffer.writeln('        const savedTheme = localStorage.getItem("theme");');
    buffer.writeln('        if (savedTheme === "dark") {');
    buffer.writeln('            html.setAttribute("data-theme", "dark");');
    buffer.writeln('            themeToggle.checked = true;');
    buffer.writeln('        }');
    buffer.writeln('        ');
    buffer.writeln('        // Theme toggle event listener');
    buffer.writeln(
      '        themeToggle.addEventListener("change", function() {',
    );
    buffer.writeln('            if (this.checked) {');
    buffer.writeln('                html.setAttribute("data-theme", "dark");');
    buffer.writeln('                localStorage.setItem("theme", "dark");');
    buffer.writeln('            } else {');
    buffer.writeln('                html.setAttribute("data-theme", "light");');
    buffer.writeln('                localStorage.setItem("theme", "light");');
    buffer.writeln('            }');
    buffer.writeln('        });');
    buffer.writeln('    </script>');
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
