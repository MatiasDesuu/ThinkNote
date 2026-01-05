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

/// A unified text handler that processes ALL types of text formatting:
/// - Note links ([[Note Title]])
/// - URLs (http://example.com)
/// - Lists (-, 1., [x])
/// - Markdown formatting (**bold**, *italic*, etc.)
class UnifiedTextHandler extends StatelessWidget {
  final String text;
  final TextStyle textStyle;
  final Function(Note, bool)? onNoteLinkTap;
  final Function(Notebook, bool)? onNotebookLinkTap;
  final Function(String)? onTextChanged;
  final TextEditingController? controller;
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
    this.controller,
    this.enableNoteLinkDetection = true,
    this.enableNotebookLinkDetection = true,
    this.enableLinkDetection = true,
    this.enableListDetection = true,
    this.enableFormatDetection = true,
    this.showNoteLinkBrackets = true,
  });

  // Regex to match horizontal rule pattern
  static final RegExp _horizontalRuleRegex = RegExp(r'^\* \* \*$');

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return Text(text, style: textStyle);
    }

    final lines = text.split('\n');
    final hasHorizontalRule = lines.any(
      (line) => _horizontalRuleRegex.hasMatch(line.trim()),
    );

    if (hasHorizontalRule) {
      final widgets = _buildWidgetsWithHorizontalRules(context, lines);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widgets,
      );
    }

    final spans = _buildUnifiedTextSpans(context);
    return RichText(
      text: TextSpan(children: spans),
      textAlign: TextAlign.start,
    );
  }

  /// Builds widgets with horizontal rules as Dividers
  List<Widget> _buildWidgetsWithHorizontalRules(
    BuildContext context,
    List<String> lines,
  ) {
    final List<Widget> widgets = [];
    final StringBuffer currentTextBuffer = StringBuffer();
    final colorScheme = Theme.of(context).colorScheme;
    bool isAfterDivider = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (_horizontalRuleRegex.hasMatch(line.trim())) {
        // Flush any accumulated text before the horizontal rule
        if (currentTextBuffer.isNotEmpty) {
          final spans = _buildNestedSpans(
            context,
            currentTextBuffer.toString(),
            textStyle,
          );
          widgets.add(
            RichText(
              text: TextSpan(children: spans),
              textAlign: TextAlign.start,
            ),
          );
          currentTextBuffer.clear();
        }

        // Add the horizontal rule divider
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                color: colorScheme.outline.withAlpha(150),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        );
        isAfterDivider = true;
      } else {
        // Accumulate text lines
        final bool isNextLineDivider =
            i + 1 < lines.length &&
            _horizontalRuleRegex.hasMatch(lines[i + 1].trim());

        if ((isAfterDivider || isNextLineDivider) && line.isEmpty) {
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
      final spans = _buildNestedSpans(
        context,
        currentTextBuffer.toString(),
        textStyle,
      );
      widgets.add(
        RichText(text: TextSpan(children: spans), textAlign: TextAlign.start),
      );
    }

    return widgets;
  }

  List<InlineSpan> _buildUnifiedTextSpans(BuildContext context) {
    return _buildNestedSpans(context, text, textStyle);
  }

  List<InlineSpan> _buildNestedSpans(
    BuildContext context,
    String text,
    TextStyle style,
  ) {
    if (text.isEmpty) return [];

    final segments = FormatDetector.parseSegments(text);
    if (segments.isEmpty) {
      return [TextSpan(text: text, style: style)];
    }

    final List<InlineSpan> spans = [];
    int lastIndex = 0;

    for (final segment in segments) {
      // Text between segments
      if (segment.start > lastIndex) {
        final betweenText = text.substring(lastIndex, segment.start);
        spans.add(TextSpan(text: betweenText, style: style));
      }

      // Process segment
      spans.add(_buildSegmentSpan(context, segment, style));
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
    TextStyle baseStyle,
  ) {
    switch (segment.type) {
      case FormatType.noteLink:
        if (!enableNoteLinkDetection) {
          return TextSpan(text: segment.originalText, style: baseStyle);
        }

        // Extract title from [[Title]]
        final title = segment.text.substring(2, segment.text.length - 2).trim();

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

        // Extract name from [[notebook:Name]]
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
        // Extract content: "- [ ] Content" -> "Content"
        final match = RegExp(
          r'^\s*-\s?\[\s*[xX\s]?\s*\]\s*(.+)$',
          multiLine: true,
        ).firstMatch(segment.originalText);
        final content = match?.group(1) ?? '';

        return TextSpan(
          children: [
            TextSpan(
              text: isChecked ? '▣ ' : '☐ ', // Custom checkbox symbol
              style: baseStyle.copyWith(
                color: isChecked ? Colors.grey : baseStyle.color,
                fontWeight: FontWeight.normal,
              ),
              recognizer:
                  TapGestureRecognizer()
                    ..onTap = () => _toggleCheckbox(segment, isChecked),
            ),
            ..._buildNestedSpans(
              context,
              content,
              baseStyle.copyWith(
                color: isChecked ? Colors.grey : baseStyle.color,
                decoration: isChecked ? TextDecoration.lineThrough : null,
              ),
            ),
          ],
        );

      case FormatType.bullet:
        if (!enableListDetection) {
          return TextSpan(text: segment.originalText, style: baseStyle);
        }
        // Extract content
        final match = RegExp(
          r'^\s*[-•*]\s+(.+)$',
          multiLine: true,
        ).firstMatch(segment.originalText);
        final content = match?.group(1) ?? '';

        return TextSpan(
          children: [
            TextSpan(text: '• ', style: baseStyle), // Standardize bullet
            ..._buildNestedSpans(context, content, baseStyle),
          ],
        );

      case FormatType.numbered:
        if (!enableListDetection) {
          return TextSpan(text: segment.originalText, style: baseStyle);
        }
        // Extract content
        final match = RegExp(
          r'^\s*(\d+\.)\s+(.+)$',
          multiLine: true,
        ).firstMatch(segment.originalText);
        final marker = match?.group(1) ?? '1.';
        final content = match?.group(2) ?? '';

        return TextSpan(
          children: [
            TextSpan(text: '$marker ', style: baseStyle),
            ..._buildNestedSpans(context, content, baseStyle),
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
        switch (segment.type) {
          case FormatType.heading1:
            fontSize *= 2.0;
            break;
          case FormatType.heading2:
            fontSize *= 1.5;
            break;
          case FormatType.heading3:
            fontSize *= 1.3;
            break;
          case FormatType.heading4:
            fontSize *= 1.2;
            break;
          case FormatType.heading5:
            fontSize *= 1.1;
            break;
          default:
            break;
        }

        final headingStyle = baseStyle.copyWith(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        );

        return TextSpan(
          children: _buildNestedSpans(context, segment.text, headingStyle),
        );

      case FormatType.bold:
        return TextSpan(
          children: _buildNestedSpans(
            context,
            segment.text,
            baseStyle.copyWith(fontWeight: FontWeight.bold),
          ),
        );

      case FormatType.italic:
        return TextSpan(
          children: _buildNestedSpans(
            context,
            segment.text,
            baseStyle.copyWith(fontStyle: FontStyle.italic),
          ),
        );

      case FormatType.strikethrough:
        return TextSpan(
          children: _buildNestedSpans(
            context,
            segment.text,
            baseStyle.copyWith(decoration: TextDecoration.lineThrough),
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

    final newText = text.replaceRange(
      segment.start,
      segment.end,
      segment.originalText.replaceFirst(
        RegExp(r'\[\s*[xX\s]?\s*\]'),
        isChecked ? '[ ]' : '[x]',
      ),
    );

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
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
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
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
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
