import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../database/models/note.dart';
import '../../database/repositories/note_repository.dart';
import '../../database/repositories/notebook_repository.dart';
import '../../database/database_helper.dart';
import '../../database/models/notebook_icons.dart';
import '../context_menu.dart';

/// A widget that detects and makes note links clickable in text content
/// Detects patterns like [[Note Title]] and makes them clickable
class NoteLinkHandler extends StatelessWidget {
  final String text;
  final TextStyle textStyle;
  final Function(Note, bool)? onNoteLinkTap; // (note, isMiddleClick)
  final bool enableNoteLinkDetection;

  const NoteLinkHandler({
    super.key,
    required this.text,
    required this.textStyle,
    this.onNoteLinkTap,
    this.enableNoteLinkDetection = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enableNoteLinkDetection || text.isEmpty) {
      return Text(text, style: textStyle);
    }

    return FutureBuilder<List<InlineSpan>>(
      future: _buildTextSpansWithNoteLinks(context),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return RichText(
            text: TextSpan(children: snapshot.data!),
            textAlign: TextAlign.start,
          );
        }
        // While loading, show plain text
        return Text(text, style: textStyle);
      },
    );
  }

  Future<List<InlineSpan>> _buildTextSpansWithNoteLinks(
    BuildContext context,
  ) async {
    final List<InlineSpan> spans = [];
    final noteLinks = NoteLinkDetector.detectNoteLinks(text);

    if (noteLinks.isEmpty) {
      spans.add(TextSpan(text: text, style: textStyle));
      return spans;
    }

    // Get all note titles for matching
    final dbHelper = DatabaseHelper();
    final noteRepository = NoteRepository(dbHelper);
    final allNotes = await noteRepository.getAllNotes();

    int lastIndex = 0;

    for (final noteLink in noteLinks) {
      // Add text before the link
      if (noteLink.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, noteLink.start),
            style: textStyle,
          ),
        );
      }

      // Find matching notes by title (can be multiple)
      final matchingNotes =
          allNotes
              .where(
                (note) =>
                    note.title.toLowerCase().trim() ==
                    noteLink.title.toLowerCase().trim(),
              )
              .toList();

      if (matchingNotes.isNotEmpty) {
        // Add the clickable note link with middle click support
        spans.add(
          WidgetSpan(
            child: _NoteLinkWidget(
              text: noteLink.originalText,
              textStyle: textStyle.copyWith(
                color: Theme.of(context).colorScheme.primary,
                decorationColor: Theme.of(context).colorScheme.primary,
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.w500,
              ),
              onTap:
                  (position) => _handleNoteLinkSelection(
                    matchingNotes,
                    noteLink.title,
                    context,
                    false,
                    position,
                  ),
              onMiddleClick:
                  (position) => _handleNoteLinkSelection(
                    matchingNotes,
                    noteLink.title,
                    context,
                    true,
                    position,
                  ),
            ),
          ),
        );
      } else {
        // Note doesn't exist, but make it clickable to allow creation
        spans.add(
          WidgetSpan(
            child: _NoteLinkWidget(
              text: noteLink.originalText,
              textStyle: textStyle.copyWith(
                color: Theme.of(context).colorScheme.primary,
                decorationColor: Theme.of(context).colorScheme.primary,
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.w500,
              ),
              onTap:
                  (position) => _handleNoteLinkSelection(
                    matchingNotes,
                    noteLink.title,
                    context,
                    false,
                    position,
                  ),
              onMiddleClick:
                  (position) => _handleNoteLinkSelection(
                    matchingNotes,
                    noteLink.title,
                    context,
                    true,
                    position,
                  ),
            ),
          ),
        );
      }

      lastIndex = noteLink.end;
    }

    // Add remaining text after the last link
    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex), style: textStyle));
    }

    return spans;
  }

  void _handleNoteLinkSelection(
    List<Note> matchingNotes,
    String title,
    BuildContext context,
    bool isMiddleClick,
    Offset position,
  ) {
    // If no matching notes exist, simply do nothing
    if (matchingNotes.isEmpty) {
      return;
    }

    if (matchingNotes.length == 1) {
      // Only one note, open it directly
      _handleNoteLinkTap(matchingNotes.first, isMiddleClick);
    } else {
      // Multiple notes with same title, show selection context menu
      _showNoteSelectionContextMenu(
        context,
        matchingNotes,
        title,
        isMiddleClick,
        position,
      );
    }
  }

  void _handleNoteLinkTap(Note note, bool isMiddleClick) {
    if (onNoteLinkTap != null) {
      onNoteLinkTap!(note, isMiddleClick);
    }
  }

  void _showNoteSelectionContextMenu(
    BuildContext context,
    List<Note> notes,
    String title,
    bool isMiddleClick,
    Offset position,
  ) async {
    final List<ContextMenuItem> menuItems = [];

    for (final note in notes) {
      final notebook = await _getNotebook(note.notebookId);
      final notebookIcon = _getNotebookIcon(notebook?.iconId);

      menuItems.add(
        ContextMenuItem(
          icon:
              note.isTask ? Icons.task_alt_rounded : Icons.description_rounded,
          label: '', // No usado cuando hay customWidget
          onTap: () => _handleNoteLinkTap(note, false),
          onMiddleClick: () => _handleNoteLinkTap(note, true),
          customWidget: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Primera línea: Icono de la nota + Título
              Row(
                children: [
                  Icon(
                    note.isTask
                        ? Icons.task_alt_rounded
                        : Icons.description_rounded,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      note.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Segunda línea: Espacio + Icono del notebook + Nombre del notebook
              Row(
                children: [
                  const SizedBox(width: 28), // Espacio a la izquierda
                  Icon(
                    notebookIcon,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      notebook?.name ?? 'Unknown Notebook',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    ContextMenuOverlay.show(
      context: context,
      tapPosition: position,
      items: menuItems,
    );
  }

  Future<dynamic> _getNotebook(int notebookId) async {
    final dbHelper = DatabaseHelper();
    final notebookRepository = NotebookRepository(dbHelper);
    return await notebookRepository.getNotebook(notebookId);
  }

  IconData _getNotebookIcon(int? iconId) {
    if (iconId == null) return Icons.folder_rounded;

    final icon =
        NotebookIconsRepository.icons
            .where((icon) => icon.id == iconId)
            .firstOrNull;
    return icon?.icon ?? Icons.folder_rounded;
  }
}

/// A utility class for detecting note links in text
class NoteLinkDetector {
  // Regex to match [[Note Title]] patterns
  static final RegExp _noteLinkRegex = RegExp(
    r'\[\[([^\[\]]+)\]\]',
    caseSensitive: false,
  );

  /// Detects all note links in the given text and returns their positions
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

  /// Checks if a string contains any note links
  static bool hasNoteLinks(String text) {
    return _noteLinkRegex.hasMatch(text);
  }

  /// Suggests note titles based on partial input
  static List<String> suggestNoteTitle(
    String partialTitle,
    List<Note> availableNotes,
  ) {
    if (partialTitle.isEmpty) return [];

    final lowercaseInput = partialTitle.toLowerCase();
    return availableNotes
        .where((note) => note.title.toLowerCase().contains(lowercaseInput))
        .map((note) => note.title)
        .take(10) // Limit to 10 suggestions
        .toList();
  }

  /// Creates a note link text from a title
  static String createNoteLinkText(String title) {
    return '[[${title.trim()}]]';
  }
}

/// Represents a detected note link in text
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

/// A combined handler that processes both note links and other formatting
class CombinedTextHandler extends StatelessWidget {
  final String text;
  final TextStyle textStyle;
  final Function(Note, bool)? onNoteLinkTap;
  final bool enableNoteLinkDetection;
  final bool enableFormatDetection;
  final Widget Function(String, TextStyle)? fallbackHandler;

  const CombinedTextHandler({
    super.key,
    required this.text,
    required this.textStyle,
    this.onNoteLinkTap,
    this.enableNoteLinkDetection = true,
    this.enableFormatDetection = true,
    this.fallbackHandler,
  });

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return Text(text, style: textStyle);
    }

    // Check if we have note links
    final hasNoteLinks =
        enableNoteLinkDetection && NoteLinkDetector.hasNoteLinks(text);

    if (hasNoteLinks) {
      return FutureBuilder<List<InlineSpan>>(
        future: _buildCombinedTextSpans(context),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return RichText(
              text: TextSpan(children: snapshot.data!),
              textAlign: TextAlign.start,
            );
          }
          // While loading, use fallback handler or plain text
          return fallbackHandler?.call(text, textStyle) ??
              Text(text, style: textStyle);
        },
      );
    }

    // No note links, use fallback handler
    return fallbackHandler?.call(text, textStyle) ??
        Text(text, style: textStyle);
  }

  Future<List<InlineSpan>> _buildCombinedTextSpans(BuildContext context) async {
    final List<InlineSpan> spans = [];
    final noteLinks = NoteLinkDetector.detectNoteLinks(text);

    if (noteLinks.isEmpty) {
      // No note links, delegate to fallback handler if available
      if (fallbackHandler != null) {
        final fallbackWidget = fallbackHandler!(text, textStyle);
        if (fallbackWidget is RichText) {
          return (fallbackWidget.text as TextSpan).children
                  ?.cast<InlineSpan>() ??
              [(fallbackWidget.text as TextSpan)];
        }
      }
      spans.add(TextSpan(text: text, style: textStyle));
      return spans;
    }

    // Get all notes for matching
    final dbHelper = DatabaseHelper();
    final noteRepository = NoteRepository(dbHelper);
    final allNotes = await noteRepository.getAllNotes();

    int lastIndex = 0;

    for (final noteLink in noteLinks) {
      // Process text before the note link with fallback handler
      if (noteLink.start > lastIndex) {
        final beforeText = text.substring(lastIndex, noteLink.start);
        if (fallbackHandler != null) {
          final beforeWidget = fallbackHandler!(beforeText, textStyle);
          if (beforeWidget is RichText) {
            final beforeSpans =
                (beforeWidget.text as TextSpan).children?.cast<InlineSpan>() ??
                [(beforeWidget.text as TextSpan)];
            spans.addAll(beforeSpans);
          } else {
            spans.add(TextSpan(text: beforeText, style: textStyle));
          }
        } else {
          spans.add(TextSpan(text: beforeText, style: textStyle));
        }
      }

      // Find matching notes (can be multiple)
      final matchingNotes =
          allNotes
              .where(
                (note) =>
                    note.title.toLowerCase().trim() ==
                    noteLink.title.toLowerCase().trim(),
              )
              .toList();

      if (matchingNotes.isNotEmpty) {
        // Add clickable note link with proper middle click support
        spans.add(
          WidgetSpan(
            child: _NoteLinkWidget(
              text: noteLink.originalText,
              textStyle: textStyle.copyWith(
                color: Theme.of(context).colorScheme.primary,
                decorationColor: Theme.of(context).colorScheme.primary,
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.w500,
              ),
              onTap:
                  (position) => _handleCombinedNoteLinkSelection(
                    matchingNotes,
                    noteLink.title,
                    context,
                    false,
                    position,
                  ),
              onMiddleClick:
                  (position) => _handleCombinedNoteLinkSelection(
                    matchingNotes,
                    noteLink.title,
                    context,
                    true,
                    position,
                  ),
            ),
          ),
        );
      } else {
        // Non-existent note, but make it clickable
        spans.add(
          WidgetSpan(
            child: _NoteLinkWidget(
              text: noteLink.originalText,
              textStyle: textStyle.copyWith(
                color: Theme.of(context).colorScheme.primary,
                decorationColor: Theme.of(context).colorScheme.primary,
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.w500,
              ),
              onTap:
                  (position) => _handleCombinedNoteLinkSelection(
                    matchingNotes,
                    noteLink.title,
                    context,
                    false,
                    position,
                  ),
              onMiddleClick:
                  (position) => _handleCombinedNoteLinkSelection(
                    matchingNotes,
                    noteLink.title,
                    context,
                    true,
                    position,
                  ),
            ),
          ),
        );
      }

      lastIndex = noteLink.end;
    }

    // Process remaining text after the last note link
    if (lastIndex < text.length) {
      final remainingText = text.substring(lastIndex);
      if (fallbackHandler != null) {
        final remainingWidget = fallbackHandler!(remainingText, textStyle);
        if (remainingWidget is RichText) {
          final remainingSpans =
              (remainingWidget.text as TextSpan).children?.cast<InlineSpan>() ??
              [(remainingWidget.text as TextSpan)];
          spans.addAll(remainingSpans);
        } else {
          spans.add(TextSpan(text: remainingText, style: textStyle));
        }
      } else {
        spans.add(TextSpan(text: remainingText, style: textStyle));
      }
    }

    return spans;
  }

  void _handleCombinedNoteLinkSelection(
    List<Note> matchingNotes,
    String title,
    BuildContext context,
    bool isMiddleClick,
    Offset position,
  ) {
    // If no matching notes exist, simply do nothing
    if (matchingNotes.isEmpty) {
      return;
    }

    if (matchingNotes.length == 1) {
      // Only one note, open it directly
      _handleNoteLinkTap(matchingNotes.first, isMiddleClick);
    } else {
      // Multiple notes with same title, show selection context menu
      _showCombinedNoteSelectionContextMenu(
        context,
        matchingNotes,
        title,
        isMiddleClick,
        position,
      );
    }
  }

  void _handleNoteLinkTap(Note note, bool isMiddleClick) {
    if (onNoteLinkTap != null) {
      onNoteLinkTap!(note, isMiddleClick);
    }
  }

  void _showCombinedNoteSelectionContextMenu(
    BuildContext context,
    List<Note> notes,
    String title,
    bool isMiddleClick,
    Offset position,
  ) async {
    final List<ContextMenuItem> menuItems = [];

    for (final note in notes) {
      final notebook = await _getCombinedNotebook(note.notebookId);
      final notebookIcon = _getCombinedNotebookIcon(notebook?.iconId);

      menuItems.add(
        ContextMenuItem(
          icon:
              note.isTask ? Icons.task_alt_rounded : Icons.description_rounded,
          label: '', // No usado cuando hay customWidget
          onTap: () => _handleNoteLinkTap(note, false),
          onMiddleClick: () => _handleNoteLinkTap(note, true),
          customWidget: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Primera línea: Icono de la nota + Título
              Row(
                children: [
                  Icon(
                    note.isTask
                        ? Icons.task_alt_rounded
                        : Icons.description_rounded,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      note.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Segunda línea: Espacio + Icono del notebook + Nombre del notebook
              Row(
                children: [
                  const SizedBox(width: 28), // Espacio a la izquierda
                  Icon(
                    notebookIcon,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      notebook?.name ?? 'Unknown Notebook',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    ContextMenuOverlay.show(
      context: context,
      tapPosition: position,
      items: menuItems,
    );
  }

  Future<dynamic> _getCombinedNotebook(int notebookId) async {
    final dbHelper = DatabaseHelper();
    final notebookRepository = NotebookRepository(dbHelper);
    return await notebookRepository.getNotebook(notebookId);
  }

  IconData _getCombinedNotebookIcon(int? iconId) {
    if (iconId == null) return Icons.folder_rounded;

    final icon =
        NotebookIconsRepository.icons
            .where((icon) => icon.id == iconId)
            .firstOrNull;
    return icon?.icon ?? Icons.folder_rounded;
  }
}

/// Custom widget for handling note links with middle click support
class _NoteLinkWidget extends StatelessWidget {
  final String text;
  final TextStyle textStyle;
  final Function(Offset) onTap;
  final Function(Offset) onMiddleClick;

  const _NoteLinkWidget({
    required this.text,
    required this.textStyle,
    required this.onTap,
    required this.onMiddleClick,
  });

  @override
  Widget build(BuildContext context) {
    Offset? tapPosition;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Listener(
        onPointerDown: (event) {
          tapPosition = event.position;
          if (event.buttons == kMiddleMouseButton) {
            onMiddleClick(event.position);
          }
        },
        child: GestureDetector(
          onTap: () {
            if (tapPosition != null) {
              onTap(tapPosition!);
            }
          },
          child: Text(text, style: textStyle),
        ),
      ),
    );
  }
}
