import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:thinknote/widgets/custom_snackbar.dart';
import '../../database/models/notebook.dart';
import '../../database/repositories/notebook_repository.dart';
import '../../database/database_helper.dart';
import '../../database/models/notebook_icons.dart';
import '../context_menu.dart';

/// A widget that detects and makes notebook links clickable in text content
/// Detects patterns like [[notebook:Notebook Name]] and makes them clickable
class NotebookLinkHandler extends StatelessWidget {
  final String text;
  final TextStyle textStyle;
  final Function(Notebook, bool)?
  onNotebookLinkTap; // (notebook, isMiddleClick)
  final bool enableNotebookLinkDetection;

  const NotebookLinkHandler({
    super.key,
    required this.text,
    required this.textStyle,
    this.onNotebookLinkTap,
    this.enableNotebookLinkDetection = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enableNotebookLinkDetection || text.isEmpty) {
      return Text(text, style: textStyle);
    }

    return FutureBuilder<List<InlineSpan>>(
      future: _buildTextSpansWithNotebookLinks(context),
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

  Future<List<InlineSpan>> _buildTextSpansWithNotebookLinks(
    BuildContext context,
  ) async {
    final List<InlineSpan> spans = [];
    final notebookLinks = NotebookLinkDetector.detectNotebookLinks(text);

    if (notebookLinks.isEmpty) {
      spans.add(TextSpan(text: text, style: textStyle));
      return spans;
    }

    // Get all notebooks for matching
    final dbHelper = DatabaseHelper();
    final notebookRepository = NotebookRepository(dbHelper);
    final allNotebooks = await notebookRepository.getAllNotebooks();

    int lastIndex = 0;

    for (final notebookLink in notebookLinks) {
      // Add text before the link
      if (notebookLink.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, notebookLink.start),
            style: textStyle,
          ),
        );
      }

      // Find matching notebooks by name (can be multiple)
      final matchingNotebooks =
          allNotebooks
              .where(
                (notebook) =>
                    notebook.name.toLowerCase().trim() ==
                    notebookLink.name.toLowerCase().trim(),
              )
              .toList();

      if (matchingNotebooks.isNotEmpty) {
        // Add the clickable notebook link with middle click support
        spans.add(
          WidgetSpan(
            child: _NotebookLinkWidget(
              text: notebookLink.originalText,
              textStyle: textStyle.copyWith(
                color: Theme.of(context).colorScheme.primary,
                decorationColor: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
              onTap:
                  (position) => _handleNotebookLinkSelection(
                    matchingNotebooks,
                    notebookLink.name,
                    context,
                    false,
                    position,
                  ),
              onMiddleClick:
                  (position) => _handleNotebookLinkSelection(
                    matchingNotebooks,
                    notebookLink.name,
                    context,
                    true,
                    position,
                  ),
            ),
          ),
        );
      } else {
        spans.add(
          WidgetSpan(
            child: _NotebookLinkWidget(
              text: notebookLink.originalText,
              textStyle: textStyle.copyWith(
                color: Theme.of(context).colorScheme.primary,
                decorationColor: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
              onTap: (position) {
                // No matching notebook found
                CustomSnackbar.show(
                  context: context,
                  message: 'Notebook "${notebookLink.name}" not found',
                  type: CustomSnackbarType.error,
                );
              },
              onMiddleClick: (position) {
                CustomSnackbar.show(
                  context: context,
                  message: 'Notebook "${notebookLink.name}" not found',
                  type: CustomSnackbarType.error,
                );
              },
            ),
          ),
        );
      }

      lastIndex = notebookLink.end;
    }

    // Add remaining text after the last link
    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex), style: textStyle));
    }

    return spans;
  }

  void _handleNotebookLinkSelection(
    List<Notebook> matchingNotebooks,
    String name,
    BuildContext context,
    bool isMiddleClick,
    Offset position,
  ) {
    // If no matching notebooks exist, simply do nothing
    if (matchingNotebooks.isEmpty) {
      return;
    }

    if (matchingNotebooks.length == 1) {
      // Only one notebook, open it directly
      _handleNotebookLinkTap(matchingNotebooks.first, isMiddleClick);
    } else {
      // Multiple notebooks with same name, show selection context menu
      _showNotebookSelectionContextMenu(
        context,
        matchingNotebooks,
        name,
        isMiddleClick,
        position,
      );
    }
  }

  void _handleNotebookLinkTap(Notebook notebook, bool isMiddleClick) {
    if (onNotebookLinkTap != null) {
      onNotebookLinkTap!(notebook, isMiddleClick);
    }
  }

  void _showNotebookSelectionContextMenu(
    BuildContext context,
    List<Notebook> notebooks,
    String name,
    bool isMiddleClick,
    Offset position,
  ) async {
    final List<ContextMenuItem> menuItems = [];

    for (final notebook in notebooks) {
      final notebookIcon = _getNotebookIcon(notebook.iconId);

      menuItems.add(
        ContextMenuItem(
          icon: notebookIcon,
          label: notebook.name,
          onTap: () => _handleNotebookLinkTap(notebook, false),
          onMiddleClick: () => _handleNotebookLinkTap(notebook, true),
        ),
      );
    }

    ContextMenuOverlay.show(
      context: context,
      tapPosition: position,
      items: menuItems,
    );
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

/// Custom widget for handling notebook links with middle click support
class _NotebookLinkWidget extends StatelessWidget {
  final String text;
  final TextStyle textStyle;
  final Function(Offset) onTap;
  final Function(Offset) onMiddleClick;

  const _NotebookLinkWidget({
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

/// A utility class for detecting notebook links in text
class NotebookLinkDetector {
  // Regex to match [[notebook:Notebook Name]] patterns
  static final RegExp _notebookLinkRegex = RegExp(
    r'\[\[notebook:([^\[\]]+)\]\]',
    caseSensitive: false,
  );

  /// Detects all notebook links in the given text and returns their positions
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

  /// Checks if a string contains any notebook links
  static bool hasNotebookLinks(String text) {
    return _notebookLinkRegex.hasMatch(text);
  }

  /// Creates a notebook link text from a name
  static String createNotebookLinkText(String name) {
    return '[[notebook:${name.trim()}]]';
  }
}

/// Represents a detected notebook link in text
class NotebookLinkMatch {
  final String name;
  final String originalText;
  final int start;
  final int end;

  NotebookLinkMatch({
    required this.name,
    required this.originalText,
    required this.start,
    required this.end,
  });
}
