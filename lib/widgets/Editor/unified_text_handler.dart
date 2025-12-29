import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../database/models/note.dart';
import '../../database/database_helper.dart';
import '../../database/repositories/note_repository.dart';
import '../../database/repositories/notebook_repository.dart';
import '../../database/models/notebook_icons.dart';
import 'note_link_handler.dart';
import 'link_handler.dart';
import 'format_handler.dart';
import '../context_menu.dart';

/// A unified text handler that processes ALL types of text formatting:
/// - Note links ([[Note Title]])
/// - URLs (http://example.com)
/// - Lists (-, 1., [x])
/// - Markdown formatting (**bold**, *italic*, etc.)
class UnifiedTextHandler extends StatelessWidget {
  final String text;
  final TextStyle textStyle;
  final Function(Note, bool)? onNoteLinkTap;
  final Function(String)? onTextChanged;
  final TextEditingController? controller;
  final bool enableNoteLinkDetection;
  final bool enableLinkDetection;
  final bool enableListDetection;
  final bool enableFormatDetection;

  const UnifiedTextHandler({
    super.key,
    required this.text,
    required this.textStyle,
    this.onNoteLinkTap,
    this.onTextChanged,
    this.controller,
    this.enableNoteLinkDetection = true,
    this.enableLinkDetection = true,
    this.enableListDetection = true,
    this.enableFormatDetection = true,
  });

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return Text(text, style: textStyle);
    }

    return FutureBuilder<List<InlineSpan>>(
      future: _buildUnifiedTextSpans(context),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return RichText(
            text: TextSpan(children: snapshot.data!),
            textAlign: TextAlign.start,
          );
        }
        // While loading, show basic text
        return Text(text, style: textStyle);
      },
    );
  }

  Future<List<InlineSpan>> _buildUnifiedTextSpans(BuildContext context) async {
    // 1. Fetch notes if needed (only once)
    List<Note> allNotes = [];
    if (enableNoteLinkDetection && NoteLinkDetector.hasNoteLinks(text)) {
       final dbHelper = DatabaseHelper();
       final noteRepository = NoteRepository(dbHelper);
       allNotes = await noteRepository.getAllNotes();
    }

    return _buildNestedSpans(context, text, allNotes, textStyle);
  }

  List<InlineSpan> _buildNestedSpans(BuildContext context, String text, List<Note> allNotes, TextStyle style) {
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
      spans.add(_buildSegmentSpan(context, segment, allNotes, style));
      lastIndex = segment.end;
    }
    
    // Remaining text
    if (lastIndex < text.length) {
       spans.add(TextSpan(text: text.substring(lastIndex), style: style));
    }

    return spans;
  }

  InlineSpan _buildSegmentSpan(BuildContext context, FormatSegment segment, List<Note> allNotes, TextStyle baseStyle) {
    switch (segment.type) {
      case FormatType.noteLink:
        if (!enableNoteLinkDetection) return TextSpan(text: segment.originalText, style: baseStyle);
        
        // Extract title from [[Title]]
        final title = segment.text.substring(2, segment.text.length - 2).trim();
        final matchingNotes = allNotes.where((note) => 
          note.title.toLowerCase().trim() == title.toLowerCase()
        ).toList();

        if (matchingNotes.isNotEmpty) {
          return WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: _NoteLinkWidget(
              text: segment.originalText,
              textStyle: baseStyle.copyWith(
                color: Theme.of(context).colorScheme.primary,
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.w500,
              ),
              onTap: (position) => _handleNoteLinkSelection(matchingNotes, title, context, false, position),
              onMiddleClick: (position) => _handleNoteLinkSelection(matchingNotes, title, context, true, position),
            ),
          );
        } else {
          return TextSpan(
            text: segment.originalText,
            style: baseStyle.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              decoration: TextDecoration.underline,
              decorationStyle: TextDecorationStyle.dashed,
              fontStyle: FontStyle.italic,
            ),
          );
        }

      case FormatType.checkboxUnchecked:
      case FormatType.checkboxChecked:
        if (!enableListDetection) return TextSpan(text: segment.originalText, style: baseStyle);
        
        final isChecked = segment.type == FormatType.checkboxChecked;
        // Extract content: "- [ ] Content" -> "Content"
        // Regex to split: ^\s*-\s?\[\s*[xX\s]?\s*\]\s*(.+)$
        final match = RegExp(r'^\s*-\s?\[\s*[xX\s]?\s*\]\s*(.+)$', multiLine: true).firstMatch(segment.originalText);
        final content = match?.group(1) ?? '';
        segment.originalText.substring(0, segment.originalText.length - content.length);

        return TextSpan(
          children: [
            TextSpan(
              text: isChecked ? '▣ ' : '☐ ', // Custom checkbox symbol
              style: baseStyle.copyWith(
                color: isChecked ? Colors.grey : baseStyle.color,
                fontWeight: FontWeight.normal,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => _toggleCheckbox(segment, isChecked),
            ),
            ..._buildNestedSpans(
              context, 
              content, 
              allNotes, 
              baseStyle.copyWith(
                color: isChecked ? Colors.grey : baseStyle.color,
                decoration: isChecked ? TextDecoration.lineThrough : null,
              )
            ),
          ]
        );

      case FormatType.bullet:
      case FormatType.asterisk:
        if (!enableListDetection) return TextSpan(text: segment.originalText, style: baseStyle);
        // Extract content
        final match = RegExp(r'^\s*[-•*]\s+(.+)$', multiLine: true).firstMatch(segment.originalText);
        final content = match?.group(1) ?? '';
        
        return TextSpan(
          children: [
            TextSpan(text: '• ', style: baseStyle), // Standardize bullet
            ..._buildNestedSpans(context, content, allNotes, baseStyle),
          ]
        );

      case FormatType.numbered:
        if (!enableListDetection) return TextSpan(text: segment.originalText, style: baseStyle);
        // Extract content
        final match = RegExp(r'^\s*(\d+\.)\s+(.+)$', multiLine: true).firstMatch(segment.originalText);
        final marker = match?.group(1) ?? '1.';
        final content = match?.group(2) ?? '';

        return TextSpan(
          children: [
            TextSpan(text: '$marker ', style: baseStyle),
            ..._buildNestedSpans(context, content, allNotes, baseStyle),
          ]
        );

      case FormatType.heading1:
      case FormatType.heading2:
      case FormatType.heading3:
      case FormatType.heading4:
      case FormatType.heading5:
        if (!enableFormatDetection) return TextSpan(text: segment.originalText, style: baseStyle);
        
        double fontSize = baseStyle.fontSize ?? 16;
        switch (segment.type) {
          case FormatType.heading1: fontSize *= 2.0; break;
          case FormatType.heading2: fontSize *= 1.5; break;
          case FormatType.heading3: fontSize *= 1.3; break;
          case FormatType.heading4: fontSize *= 1.2; break;
          case FormatType.heading5: fontSize *= 1.1; break;
          default: break;
        }
        
        final headingStyle = baseStyle.copyWith(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        );
        
        return TextSpan(
          children: _buildNestedSpans(context, segment.text, allNotes, headingStyle),
        );

      case FormatType.bold:
        return TextSpan(
          children: _buildNestedSpans(
            context, 
            segment.text, 
            allNotes, 
            baseStyle.copyWith(fontWeight: FontWeight.bold)
          ),
        );

      case FormatType.italic:
        return TextSpan(
          children: _buildNestedSpans(
            context, 
            segment.text, 
            allNotes, 
            baseStyle.copyWith(fontStyle: FontStyle.italic)
          ),
        );

      case FormatType.strikethrough:
        return TextSpan(
          children: _buildNestedSpans(
            context, 
            segment.text, 
            allNotes, 
            baseStyle.copyWith(decoration: TextDecoration.lineThrough)
          ),
        );

      case FormatType.code:
        return TextSpan(
          text: segment.text,
          style: baseStyle.copyWith(
            backgroundColor: Theme.of(context).colorScheme.error.withAlpha(30),
            color: Theme.of(context).colorScheme.error,
            fontFamily: 'monospace',
          ),
        );

      case FormatType.link:
      case FormatType.url:
        if (!enableLinkDetection) return TextSpan(text: segment.originalText, style: baseStyle);
        
        final url = segment.data ?? segment.text;
        return TextSpan(
          text: segment.text,
          style: baseStyle.copyWith(
            color: Colors.blue,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => LinkLauncher.launchURL(url),
        );

      default:
        return TextSpan(text: segment.originalText, style: baseStyle);
    }
  }

  void _toggleCheckbox(FormatSegment segment, bool isChecked) {
    if (onTextChanged == null) return;
    
    // We have the exact range of the segment!
    // But we need to be careful: segment.start/end are relative to the text passed to parseSegments.
    // If text hasn't changed, they are valid.
    
    // Replace [ ] with [x] or vice versa in the segment text
    // The segment text is the whole line "  - [ ] Content"
    
    final newText = text.replaceRange(
      segment.start, 
      segment.end, 
      segment.originalText.replaceFirst(
        RegExp(r'\[\s*[xX\s]?\s*\]'), 
        isChecked ? '[ ]' : '[x]'
      )
    );
    
    onTextChanged!(newText);
  }

  void _handleNoteLinkSelection(List<Note> matchingNotes, String title, BuildContext context, bool isMiddleClick, Offset position) {
    if (matchingNotes.isEmpty) return;
    
    if (matchingNotes.length == 1) {
      _handleNoteLinkTap(matchingNotes.first, isMiddleClick);
    } else {
      _showNoteSelectionContextMenu(context, matchingNotes, title, isMiddleClick, position);
    }
  }

  void _handleNoteLinkTap(Note note, bool isMiddleClick) {
    if (onNoteLinkTap != null) {
      onNoteLinkTap!(note, isMiddleClick);
    }
  }

  void _showNoteSelectionContextMenu(BuildContext context, List<Note> notes, String title, bool isMiddleClick, Offset position) async {
    final List<ContextMenuItem> menuItems = [];
    
    for (final note in notes) {
      final notebook = await _getNotebook(note.notebookId);
      final notebookIcon = _getNotebookIcon(notebook?.iconId);
      
      menuItems.add(
        ContextMenuItem(
          icon: note.isTask ? Icons.task_alt_rounded : Icons.description_rounded,
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
                    note.isTask ? Icons.task_alt_rounded : Icons.description_rounded,
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
    
    final icon = NotebookIconsRepository.icons.where((icon) => icon.id == iconId).firstOrNull;
    return icon?.icon ?? Icons.folder_rounded;
  }
}

/// Widget for clickable note links with middle-click support
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
          child: Text(
            text,
            style: textStyle,
          ),
        ),
      ),
    );
  }
}
