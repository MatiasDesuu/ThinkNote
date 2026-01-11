import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import '../../database/models/note.dart';
import '../../database/models/notebook.dart';
import '../../database/database_helper.dart';
import '../../database/repositories/note_repository.dart';
import '../../database/repositories/notebook_repository.dart';
import '../../database/models/notebook_icons.dart';
import 'link_handler.dart';
import 'format_handler.dart';
import '../context_menu.dart';
import '../custom_snackbar.dart';

class UnifiedTextHandler extends StatelessWidget {
  final String text;
  final TextStyle textStyle;
  final Function(Note, bool)? onNoteLinkTap;
  final Function(Notebook, bool)? onNotebookLinkTap;
  final Function(String)? onTextChanged;
  final bool enableNoteLinkDetection;
  final bool enableNotebookLinkDetection;
  final bool enableLinkDetection;
  final bool enableListDetection;
  final bool enableFormatDetection;
  final bool showNoteLinkBrackets;

  const UnifiedTextHandler({
    super.key,
    required this.text,
    required this.textStyle,
    this.onNoteLinkTap,
    this.onNotebookLinkTap,
    this.onTextChanged,
    this.enableNoteLinkDetection = true,
    this.enableNotebookLinkDetection = true,
    this.enableLinkDetection = true,
    this.enableListDetection = true,
    this.enableFormatDetection = true,
    this.showNoteLinkBrackets = true,
  });

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return Text(text, style: textStyle);
    }

    final widgets = _buildParagraphWidgets(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  // _buildParagraphWidgets
  List<Widget> _buildParagraphWidgets(BuildContext context) {
    final lines = text.split('\n');
    final List<Widget> widgets = [];
    final colorScheme = Theme.of(context).colorScheme;
    final StringBuffer currentParagraph = StringBuffer();
    int consecutiveEmptyLines = 0;
    int currentOffset = 0;
    int paragraphStartOffset = 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (line.trim().isEmpty) {
        consecutiveEmptyLines++;
        currentOffset += line.length + 1;
      } else {
        if (currentParagraph.isNotEmpty) {
          _addParagraphWidget(context, currentParagraph.toString(), widgets, colorScheme, paragraphStartOffset);
          currentOffset += currentParagraph.length + 1;
          currentParagraph.clear();
        }

        if (consecutiveEmptyLines > 0) {
          widgets.add(SizedBox(height: 16.0 * consecutiveEmptyLines));
          currentOffset += consecutiveEmptyLines;
          consecutiveEmptyLines = 0;
        }

        paragraphStartOffset = currentOffset;
        if (currentParagraph.isNotEmpty) {
          currentParagraph.write('\n');
          currentOffset += 1;
        }
        currentParagraph.write(line);
        currentOffset += line.length;
      }
    }

    if (currentParagraph.isNotEmpty) {
      _addParagraphWidget(context, currentParagraph.toString(), widgets, colorScheme, paragraphStartOffset);
    }

    return widgets;
  }

  void _addParagraphWidget(BuildContext context, String paragraphText, List<Widget> widgets, ColorScheme colorScheme, int baseOffset) {
    if (FormatDetector.horizontalRuleRegex.hasMatch(paragraphText.trim())) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              color: colorScheme.outline.withAlpha(150),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );
    } else {
      final segments = FormatDetector.parseSegments(paragraphText);
      final listSegment = segments.isNotEmpty ? segments.first : null;

      if (enableListDetection &&
          listSegment != null &&
          listSegment.start == 0 &&
          (listSegment.type == FormatType.bullet ||
              listSegment.type == FormatType.numbered ||
              listSegment.type == FormatType.checkboxChecked ||
              listSegment.type == FormatType.checkboxUnchecked)) {
        widgets.add(_buildListItemWidget(context, listSegment, baseOffset));
      } else {
        final indentMatch = RegExp(r'^(\s+)(.*)$', dotAll: true).firstMatch(paragraphText);
        if (enableListDetection && indentMatch != null && indentMatch.group(1)!.isNotEmpty) {
          final indent = indentMatch.group(1)!;
          final content = indentMatch.group(2)!;
          
          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(indent, style: textStyle),
                  Text('  ', style: textStyle),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        children: _buildNestedSpans(
                          context,
                          content,
                          textStyle,
                          baseOffset: baseOffset + indent.length,
                        ),
                      ),
                      textAlign: TextAlign.start,
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          final spans = _buildNestedSpans(
            context,
            paragraphText,
            textStyle,
            baseOffset: baseOffset,
          );
          widgets.add(
            RichText(
              text: TextSpan(children: spans),
              textAlign: TextAlign.start,
            ),
          );
        }
      }
    }
  }

  Widget _buildListItemWidget(
    BuildContext context,
    FormatSegment segment,
    int baseOffset,
  ) {
    String marker = "";
    String content = "";
    String indent = "";
    bool isChecked = false;

    if (segment.type == FormatType.checkboxUnchecked ||
        segment.type == FormatType.checkboxChecked) {
      isChecked = segment.type == FormatType.checkboxChecked;
      final match = RegExp(
        r'^(\s*)([-•◦▪])\s?\[\s*[xX\s]?\s*\]\s(.*)$',
      ).firstMatch(segment.originalText);
      indent = match?.group(1) ?? '';
      content = match?.group(3) ?? '';
    } else if (segment.type == FormatType.bullet) {
      final match = RegExp(
        r'^(\s*)[-•*]\s(.*)$',
      ).firstMatch(segment.originalText);
      indent = match?.group(1) ?? '';
      int spaceCount = indent.length;
      if (spaceCount <= 0) {
        marker = "• ";
      } else if (spaceCount == 1) {
        marker = "◦ ";
      } else {
        marker = "▪ ";
      }
      content = match?.group(2) ?? '';
    } else if (segment.type == FormatType.numbered) {
      final match = RegExp(
        r'^(\s*)(\d+\.)\s(.*)$',
      ).firstMatch(segment.originalText);
      indent = match?.group(1) ?? '';
      marker = "${match?.group(2) ?? '1.'} ";
      content = match?.group(3) ?? '';
    }

    final contentOffset = segment.originalText.lastIndexOf(content);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          if (indent.isNotEmpty) Text(indent, style: textStyle),
          if (segment.type == FormatType.checkboxUnchecked ||
              segment.type == FormatType.checkboxChecked)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => _toggleCheckbox(segment, isChecked),
                    child: Icon(
                      isChecked
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      size: (textStyle.fontSize ?? 16.0) + 2.0,
                      color:
                          isChecked
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(' ', style: textStyle),
              ],
            )
          else
            Text(
              marker,
              style: textStyle.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: _buildNestedSpans(
                  context,
                  content,
                  textStyle.copyWith(
                    color: isChecked ? Colors.grey : textStyle.color,
                    decoration:
                        isChecked
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                  ),
                  baseOffset: baseOffset + segment.start + contentOffset,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<InlineSpan> _buildNestedSpans(
    BuildContext context,
    String text,
    TextStyle style, {
    int baseOffset = 0,
  }) {
    if (text.isEmpty) return [];

    final segments = FormatDetector.parseSegments(text);
    if (segments.isEmpty) {
      return [TextSpan(text: text, style: style)];
    }

    final List<InlineSpan> spans = [];
    int lastIndex = 0;

    for (final segment in segments) {
      if (segment.start > lastIndex) {
        final betweenText = text.substring(lastIndex, segment.start);
        spans.add(TextSpan(text: betweenText, style: style));
      }

      spans.add(_buildSegmentSpan(context, segment, style, baseOffset: baseOffset));
      lastIndex = segment.end;
    }

    // Remaining text
    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex), style: style));
    }

    return spans;
  }

  InlineSpan _buildSegmentSpan(
    BuildContext context,
    FormatSegment segment,
    TextStyle baseStyle, {
    int baseOffset = 0,
  }) {
    switch (segment.type) {
      case FormatType.noteLink:
        if (!enableNoteLinkDetection) {
          return TextSpan(text: segment.originalText, style: baseStyle);
        }

        final title = segment.text.substring(7, segment.text.length - 2).trim();

        return WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: _NoteLinkWidget(
            text: showNoteLinkBrackets ? segment.originalText : title,
            textStyle: baseStyle.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
            onTap:
                (position) =>
                    _handleNoteLinkTapAsync(title, context, false, position),
            onMiddleClick:
                (position) =>
                    _handleNoteLinkTapAsync(title, context, true, position),
          ),
        );

      case FormatType.notebookLink:
        if (!enableNotebookLinkDetection) {
          return TextSpan(text: segment.originalText, style: baseStyle);
        }

        final name = segment.text.substring(11, segment.text.length - 2).trim();

        return WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: _NoteLinkWidget(
            text: showNoteLinkBrackets ? segment.originalText : name,
            textStyle: baseStyle.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
            onTap:
                (position) =>
                    _handleNotebookLinkTapAsync(name, context, false, position),
            onMiddleClick:
                (position) =>
                    _handleNotebookLinkTapAsync(name, context, true, position),
          ),
        );

      case FormatType.checkboxUnchecked:
      case FormatType.checkboxChecked:
        if (!enableListDetection) {
          return TextSpan(text: segment.originalText, style: baseStyle);
        }

        final isChecked = segment.type == FormatType.checkboxChecked;
        final match = RegExp(
          r'^(\s*)-\s?\[\s*[xX\s]?\s*\]\s*(.*)$',
          multiLine: true,
        ).firstMatch(segment.originalText);
        final indent = match?.group(1) ?? '';
        final content = match?.group(2) ?? '';
        final contentOffset = segment.originalText.lastIndexOf(content);

        return TextSpan(
          children: [
            if (indent.isNotEmpty) TextSpan(text: indent, style: baseStyle),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => _toggleCheckbox(segment, isChecked),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: Icon(
                      isChecked
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      size: (baseStyle.fontSize ?? 16.0) + 4.0,
                      color:
                          isChecked
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
            ..._buildNestedSpans(
              context,
              content,
              baseStyle.copyWith(
                color: isChecked ? Colors.grey : baseStyle.color,
                decoration:
                    isChecked ? TextDecoration.lineThrough : TextDecoration.none,
              ),
              baseOffset: baseOffset + segment.start + contentOffset,
            ),
          ],
        );

      case FormatType.bullet:
        if (!enableListDetection) {
          return TextSpan(text: segment.originalText, style: baseStyle);
        }
        final match = RegExp(
          r'^\s*[-•*]\s+(.+)$',
          multiLine: true,
        ).firstMatch(segment.originalText);
        final content = match?.group(1) ?? '';
        final contentOffset = segment.originalText.lastIndexOf(content);

        return TextSpan(
          children: [
            TextSpan(text: '• ', style: baseStyle),
            ..._buildNestedSpans(
              context,
              content,
              baseStyle,
              baseOffset: baseOffset + segment.start + contentOffset,
            ),
          ],
        );

      case FormatType.numbered:
        if (!enableListDetection) {
          return TextSpan(text: segment.originalText, style: baseStyle);
        }
        final match = RegExp(
          r'^\s*(\d+\.)\s+(.+)$',
          multiLine: true,
        ).firstMatch(segment.originalText);
        final marker = match?.group(1) ?? '1.';
        final content = match?.group(2) ?? '';
        final contentOffset = segment.originalText.lastIndexOf(content);

        return TextSpan(
          children: [
            TextSpan(text: '$marker ', style: baseStyle),
            ..._buildNestedSpans(
              context,
              content,
              baseStyle,
              baseOffset: baseOffset + segment.start + contentOffset,
            ),
          ],
        );

      case FormatType.heading1:
      case FormatType.heading2:
      case FormatType.heading3:
      case FormatType.heading4:
      case FormatType.heading5:
        if (!enableFormatDetection) {
          return TextSpan(text: segment.originalText, style: baseStyle);
        }

        double fontSize = baseStyle.fontSize ?? 16;
        int markerLength = 0;
        switch (segment.type) {
          case FormatType.heading1:
            fontSize *= 2.0;
            markerLength = 2;
            break;
          case FormatType.heading2:
            fontSize *= 1.5;
            markerLength = 3;
            break;
          case FormatType.heading3:
            fontSize *= 1.3;
            markerLength = 4;
            break;
          case FormatType.heading4:
            fontSize *= 1.2;
            markerLength = 5;
            break;
          case FormatType.heading5:
            fontSize *= 1.1;
            markerLength = 6;
            break;
          default:
            break;
        }

        final headingStyle = baseStyle.copyWith(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        );

        return TextSpan(
          children: _buildNestedSpans(
            context,
            segment.text,
            headingStyle,
            baseOffset: baseOffset + segment.start + markerLength,
          ),
        );

      case FormatType.bold:
        return TextSpan(
          children: _buildNestedSpans(
            context,
            segment.text,
            baseStyle.copyWith(fontWeight: FontWeight.bold),
            baseOffset: baseOffset + segment.start + 2,
          ),
        );

      case FormatType.italic:
        return TextSpan(
          children: _buildNestedSpans(
            context,
            segment.text,
            baseStyle.copyWith(fontStyle: FontStyle.italic),
            baseOffset: baseOffset + segment.start + 1,
          ),
        );

      case FormatType.strikethrough:
        return TextSpan(
          children: _buildNestedSpans(
            context,
            segment.text,
            baseStyle.copyWith(decoration: TextDecoration.lineThrough),
            baseOffset: baseOffset + segment.start + 2,
          ),
        );

      case FormatType.code:
        return WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _InlineCodeWidget(text: segment.text, style: baseStyle),
        );

      case FormatType.taggedCode:
        return WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _TaggedCodeWidget(text: segment.text, style: baseStyle),
        );

      case FormatType.link:
      case FormatType.url:
        if (!enableLinkDetection) {
          return TextSpan(text: segment.originalText, style: baseStyle);
        }

        final url = segment.data ?? segment.text;
        return TextSpan(
          text: segment.text,
          style: baseStyle.copyWith(
            color: Colors.blue,
            decoration: TextDecoration.underline,
          ),
          recognizer:
              TapGestureRecognizer()..onTap = () => LinkLauncher.launchURL(url),
        );

      default:
        return TextSpan(text: segment.originalText, style: baseStyle);
    }
  }

  void _toggleCheckbox(FormatSegment segment, bool isChecked) {
    if (onTextChanged == null) return;

    final lineText = segment.originalText;
    final start = text.indexOf(lineText);
    if (start == -1 || start + lineText.length > text.length) return;

    final end = start + lineText.length;

    final newLineText = lineText.replaceFirst(
      RegExp(r'\[\s*[xX\s]?\s*\]'),
      isChecked ? '[ ]' : '[x]',
    );

    final newText = text.replaceRange(start, end, newLineText);
    onTextChanged!(newText);
  }

  void _handleNotebookLinkTapAsync(
    String name,
    BuildContext context,
    bool isMiddleClick,
    Offset position,
  ) async {
    final dbHelper = DatabaseHelper();
    final notebookRepository = NotebookRepository(dbHelper);
    final allNotebooks = await notebookRepository.getAllNotebooks();

    final matchingNotebooks =
        allNotebooks
            .where(
              (notebook) =>
                  notebook.name.toLowerCase().trim() == name.toLowerCase(),
            )
            .toList();

    if (matchingNotebooks.isEmpty) {
      if (context.mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Notebook "$name" not found',
          type: CustomSnackbarType.error,
        );
      }
      return;
    }

    if (matchingNotebooks.length == 1) {
      _handleNotebookLinkTap(matchingNotebooks.first, isMiddleClick);
    } else {
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

  void _handleNoteLinkTapAsync(
    String title,
    BuildContext context,
    bool isMiddleClick,
    Offset position,
  ) async {
    final dbHelper = DatabaseHelper();
    final noteRepository = NoteRepository(dbHelper);
    final allNotes = await noteRepository.getAllNotes();

    final matchingNotes =
        allNotes
            .where(
              (note) => note.title.toLowerCase().trim() == title.toLowerCase(),
            )
            .toList();

    if (matchingNotes.isEmpty) {
      if (context.mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Note "$title" not found',
          type: CustomSnackbarType.error,
        );
      }
      return;
    }

    if (matchingNotes.length == 1) {
      _handleNoteLinkTap(matchingNotes.first, isMiddleClick);
    } else {
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
          label: '',
          onTap: () => _handleNoteLinkTap(note, false),
          onMiddleClick: () => _handleNoteLinkTap(note, true),
          customWidget: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
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
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const SizedBox(width: 28),
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

class _InlineCodeWidget extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _InlineCodeWidget({required this.text, required this.style});

  @override
  State<_InlineCodeWidget> createState() => _InlineCodeWidgetState();
}

class _InlineCodeWidgetState extends State<_InlineCodeWidget> {
  bool _isHovered = false;
  bool _isCopied = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit:
            (_) => setState(() {
              _isHovered = false;
              _isCopied = false;
            }),
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                widget.text,
                style: widget.style.copyWith(
                  fontFamily: 'monospace',
                  fontSize: (widget.style.fontSize ?? 16) * 0.9,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Positioned(
              top: 2,
              right: 2,
              child: Opacity(
                opacity: _isHovered ? 1.0 : 0.0,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: widget.text));
                      setState(() => _isCopied = true);
                      Future.delayed(const Duration(seconds: 2), () {
                        if (mounted) setState(() => _isCopied = false);
                      });
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        _isCopied ? Icons.check_rounded : Icons.copy_rounded,
                        size: 16,
                        color:
                            _isCopied
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant.withAlpha(180),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaggedCodeWidget extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _TaggedCodeWidget({required this.text, required this.style});

  @override
  State<_TaggedCodeWidget> createState() => _TaggedCodeWidgetState();
}

class _TaggedCodeWidgetState extends State<_TaggedCodeWidget> {
  bool _isHovered = false;
  bool _isCopied = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit:
            (_) => setState(() {
              _isHovered = false;
              _isCopied = false;
            }),
        child: Material(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withAlpha(128),
          borderRadius: BorderRadius.circular(4),
          child: InkWell(
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: widget.text));
              setState(() => _isCopied = true);
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) setState(() => _isCopied = false);
              });
            },
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withAlpha(40),
                    ),
                  ),
                  child: Text(
                    widget.text,
                    style: widget.style.copyWith(
                      fontFamily: 'monospace',
                      fontSize: (widget.style.fontSize ?? 16) * 0.9,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: Opacity(
                    opacity: _isHovered ? 1.0 : 0.0,
                    child: IgnorePointer(
                      child: Icon(
                        _isCopied ? Icons.check_rounded : Icons.copy_rounded,
                        size: 14,
                        color:
                            _isCopied
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant.withAlpha(180),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
