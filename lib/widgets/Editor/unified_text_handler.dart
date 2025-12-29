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
import 'list_handler.dart';
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

    // Check if we have note links first
    final hasNoteLinks = enableNoteLinkDetection && NoteLinkDetector.hasNoteLinks(text);
    
    if (hasNoteLinks) {
      // Process with note links + all other formatting
      return FutureBuilder<List<InlineSpan>>(
        future: _buildUnifiedTextSpans(context),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return RichText(
              text: TextSpan(children: snapshot.data!),
              textAlign: TextAlign.start,
            );
          }
          // While loading, show basic formatting
          return _buildBasicFormattedText(context);
        },
      );
    }

    // No note links, use basic formatting
    return _buildBasicFormattedText(context);
  }

  Widget _buildBasicFormattedText(BuildContext context) {
    final hasLists = enableListDetection && ListDetector.hasListItems(text);
    
    if (hasLists) {
      // Use enhanced list handler with all formatting
      return _EnhancedListHandlerWithLinks(
        text: text,
        textStyle: textStyle,
        enableListDetection: enableListDetection,
        enableFormatDetection: enableFormatDetection,
        enableLinkDetection: enableLinkDetection,
        controller: controller,
        onTextChanged: onTextChanged,
      );
    }

    // No lists, process line by line for better formatting
    return _buildLineByLineFormatting(context);
  }

  Widget _buildLineByLineFormatting(BuildContext context) {
    final lines = text.split('\n');
    final List<InlineSpan> spans = [];
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineSpans = _buildFormattedLineSpans(context, line, textStyle);
      spans.addAll(lineSpans);
      
      // Add newline except for the last line
      if (i < lines.length - 1) {
        spans.add(TextSpan(text: '\n', style: textStyle));
      }
    }
    
    return RichText(
      text: TextSpan(children: spans),
      textAlign: TextAlign.start,
    );
  }

  Future<List<InlineSpan>> _buildUnifiedTextSpans(BuildContext context) async {
    final List<InlineSpan> spans = [];
    final noteLinks = NoteLinkDetector.detectNoteLinks(text);
    
    if (noteLinks.isEmpty) {
      // No note links, use basic formatting
      final basicWidget = _buildBasicFormattedText(context);
      if (basicWidget is RichText) {
        return (basicWidget.text as TextSpan).children?.cast<InlineSpan>() ?? 
            [(basicWidget.text as TextSpan)];
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
      // Process text before the note link with all formatting
      if (noteLink.start > lastIndex) {
        final beforeText = text.substring(lastIndex, noteLink.start);
        final beforeSpans = _buildFormattedTextSpans(context, beforeText, textStyle);
        spans.addAll(beforeSpans);
      }
      
      // Find matching notes (can be multiple)
      final matchingNotes = allNotes.where((note) => 
        note.title.toLowerCase().trim() == noteLink.title.toLowerCase().trim()
      ).toList();
      
      if (matchingNotes.isNotEmpty) {
        // Add clickable note link
        spans.add(WidgetSpan(
          child: _NoteLinkWidget(
            text: noteLink.originalText,
            textStyle: textStyle.copyWith(
              color: Theme.of(context).colorScheme.primary,
              decorationColor: Theme.of(context).colorScheme.primary,
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.w500,
            ),
            onTap: (position) => _handleNoteLinkSelection(matchingNotes, noteLink.title, context, false, position),
            onMiddleClick: (position) => _handleNoteLinkSelection(matchingNotes, noteLink.title, context, true, position),
          ),
        ));
      } else {
        // Non-existent note
        spans.add(TextSpan(
          text: noteLink.originalText,
          style: textStyle.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            decoration: TextDecoration.underline,
            decorationStyle: TextDecorationStyle.dashed,
            fontStyle: FontStyle.italic,
          ),
        ));
      }
      
      lastIndex = noteLink.end;
    }
    
    // Process remaining text after the last note link
    if (lastIndex < text.length) {
      final remainingText = text.substring(lastIndex);
      final remainingSpans = _buildFormattedTextSpans(context, remainingText, textStyle);
      spans.addAll(remainingSpans);
    }
    
    return spans;
  }

  List<InlineSpan> _buildFormattedTextSpans(BuildContext context, String text, TextStyle style) {
    // Process text with all formatting: lists, links, and markdown
    final hasLists = enableListDetection && ListDetector.hasListItems(text);
    
    if (hasLists) {
      // Handle lists with full formatting
      return _buildFormattedListSpans(context, text, style);
    }
    
    // No lists, handle line by line
    final lines = text.split('\n');
    final List<InlineSpan> spans = [];
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineSpans = _buildFormattedLineSpans(context, line, style);
      spans.addAll(lineSpans);
      
      // Add newline except for the last line
      if (i < lines.length - 1) {
        spans.add(TextSpan(text: '\n', style: style));
      }
    }
    
    return spans;
  }

  List<InlineSpan> _buildFormattedListSpans(BuildContext context, String text, TextStyle style) {
    final lines = text.split('\n');
    final List<InlineSpan> spans = [];
    int currentCharPosition = 0; // Track absolute position in original text
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final listItem = ListDetector.detectListItem(line, lineNumber: i);
      
      if (listItem != null && listItem.type == ListType.checkbox) {
        // Handle checkbox with clickable functionality and full formatting
        // Pass the absolute character position to identify this specific checkbox
        spans.add(_buildEnhancedCheckboxSpan(context, listItem, currentCharPosition, style));
      } else if (listItem != null) {
        // Add other list items with full formatting
        final listSpans = _buildFormattedLineSpans(context, listItem.formattedText, style.copyWith(
          fontWeight: FontWeight.normal,
        ));
        spans.addAll(listSpans);
      } else {
        // Regular text with full formatting
        final lineSpans = _buildFormattedLineSpans(context, line, style);
        spans.addAll(lineSpans);
      }
      
      // Update character position (line + newline)
      currentCharPosition += line.length + 1;
      
      // Add newline except for the last line
      if (i < lines.length - 1) {
        spans.add(TextSpan(text: '\n', style: style));
      }
    }
    
    return spans;
  }

  List<InlineSpan> _buildFormattedLineSpans(BuildContext context, String line, TextStyle style) {
    // First detect URLs in the line
    final links = enableLinkDetection ? LinkDetector.detectLinks(line) : <LinkMatch>[];
    
    if (links.isEmpty) {
      // No links, just apply markdown formatting
      if (enableFormatDetection && FormatDetector.hasFormatting(line)) {
        return FormatDetector.buildFormattedSpans(line, style, context).cast<InlineSpan>();
      }
      return [TextSpan(text: line, style: style)];
    }

    // Process line with both links and formatting
    final List<InlineSpan> spans = [];
    int lastIndex = 0;
    
    for (final link in links) {
      // Process text before the link with formatting
      if (link.start > lastIndex) {
        final beforeText = line.substring(lastIndex, link.start);
        if (enableFormatDetection && FormatDetector.hasFormatting(beforeText)) {
          spans.addAll(FormatDetector.buildFormattedSpans(beforeText, style, context).cast<InlineSpan>());
        } else {
          spans.add(TextSpan(text: beforeText, style: style));
        }
      }
      
      // Add the clickable link
      spans.add(TextSpan(
        text: link.text,
        style: style.copyWith(
          color: Theme.of(context).colorScheme.primary,
          decorationColor: Theme.of(context).colorScheme.primary,
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.w600,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () => LinkLauncher.launchURL(link.url),
      ));
      
      lastIndex = link.end;
    }
    
    // Process remaining text after the last link
    if (lastIndex < line.length) {
      final remainingText = line.substring(lastIndex);
      if (enableFormatDetection && FormatDetector.hasFormatting(remainingText)) {
        spans.addAll(FormatDetector.buildFormattedSpans(remainingText, style, context).cast<InlineSpan>());
      } else {
        spans.add(TextSpan(text: remainingText, style: style));
      }
    }
    
    return spans;
  }

  InlineSpan _buildEnhancedCheckboxSpan(BuildContext context, ListItem listItem, int charPosition, TextStyle style) {
    final List<InlineSpan> children = [];
    
    // Add checkbox symbol
    children.add(TextSpan(
      text: listItem.isChecked ? '▣ ' : '☐ ',
      style: style.copyWith(
        fontSize: style.fontSize,
        fontWeight: FontWeight.normal,
        height: 1.0,
        color: listItem.isChecked ? Colors.grey : style.color,
      ),
      recognizer: TapGestureRecognizer()
        ..onTap = () => _toggleCheckboxByPosition(listItem, charPosition),
    ));
    
    // Add content with full formatting
    final contentSpans = _buildFormattedLineSpans(
      context,
      listItem.content,
      style.copyWith(
        fontWeight: FontWeight.normal,
        color: listItem.isChecked ? Colors.grey : style.color,
      ),
    );
    children.addAll(contentSpans);
    
    return TextSpan(children: children);
  }

  void _toggleCheckboxByPosition(ListItem listItem, int approximateCharPosition) {
    if (onTextChanged == null && controller == null) return;
    
    final newCheckedState = !listItem.isChecked;
    
    // Find all occurrences of this checkbox content (supports both - [] and -[])
    final escapedContent = RegExp.escape(listItem.content);
    final checkboxRegex = RegExp(r'^\s*-\s?\[\s*([x\s]?)\s*\]\s*' + escapedContent + r'\s*$', multiLine: true, caseSensitive: false);
    
    final matches = checkboxRegex.allMatches(text).toList();
    
    if (matches.isEmpty) {
      // Fallback to content-based replacement if regex fails
      _toggleCheckboxByContentFallback(listItem);
      return;
    }
    
    if (matches.length == 1) {
      // Only one match, safe to replace
      final newText = text.replaceFirstMapped(checkboxRegex, (match) {
        return match.group(0)!.replaceFirst(
          RegExp(r'-\s?\[\s*([x\s]?)\s*\]'),
          '- [${newCheckedState ? 'x' : ' '}]',
        );
      });
      
      if (controller != null) {
        controller!.text = newText;
      }
      onTextChanged?.call(newText);
      return;
    }
    
    // Multiple matches - find the closest one to our approximate position
    int bestMatchIndex = 0;
    int minDistance = (matches[0].start - approximateCharPosition).abs();
    
    for (int i = 1; i < matches.length; i++) {
      int distance = (matches[i].start - approximateCharPosition).abs();
      if (distance < minDistance) {
        minDistance = distance;
        bestMatchIndex = i;
      }
    }
    
    // Replace only the best match
    String newText = text;
    int matchCount = 0;
    
    newText = text.replaceAllMapped(checkboxRegex, (match) {
      bool shouldReplace = matchCount == bestMatchIndex;
      matchCount++; // Increment after checking
      
      if (shouldReplace) {
        return match.group(0)!.replaceFirst(
          RegExp(r'-\s?\[\s*([x\s]?)\s*\]'),
          '- [${newCheckedState ? 'x' : ' '}]',
        );
      } else {
        return match.group(0)!;
      }
    });
    
    if (controller != null) {
      controller!.text = newText;
    }
    
    onTextChanged?.call(newText);
  }

  void _toggleCheckboxByContentFallback(ListItem listItem) {
    if (onTextChanged == null && controller == null) return;
    
    final newCheckedState = !listItem.isChecked;
    
    // Use regex to find and replace the checkbox line more flexibly (supports both - [] and -[])
    final escapedContent = RegExp.escape(listItem.content);
    final checkboxRegex = RegExp(r'^\s*-\s?\[\s*([x\s]?)\s*\]\s*' + escapedContent, multiLine: true, caseSensitive: false);
    
    final newText = text.replaceFirstMapped(checkboxRegex, (match) {
      final leadingSpaces = match.group(0)!.split('-')[0]; // Preserve leading spaces
      final replacement = '$leadingSpaces- [${newCheckedState ? 'x' : ' '}] ${listItem.content}';
      return replacement;
    });
    
    if (controller != null) {
      controller!.text = newText;
    }
    
    if (onTextChanged != null) {
      onTextChanged!(newText);
    }
  }

  void _handleNoteLinkSelection(List<Note> matchingNotes, String title, BuildContext context, bool isMiddleClick, Offset position) {
    if (matchingNotes.isEmpty) return;
    
    if (matchingNotes.length == 1) {
      // Only one note, open it directly
      _handleNoteLinkTap(matchingNotes.first, isMiddleClick);
    } else {
      // Multiple notes with same title, show selection context menu
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
    
    final icon = NotebookIconsRepository.icons.where((icon) => icon.id == iconId).firstOrNull;
    return icon?.icon ?? Icons.folder_rounded;
  }
}

/// Enhanced ListHandler that includes link detection
class _EnhancedListHandlerWithLinks extends StatelessWidget {
  final String text;
  final TextStyle textStyle;
  final bool enableListDetection;
  final bool enableFormatDetection;
  final bool enableLinkDetection;
  final Function(String)? onTextChanged;
  final TextEditingController? controller;

  const _EnhancedListHandlerWithLinks({
    required this.text,
    required this.textStyle,
    this.enableListDetection = true,
    this.enableFormatDetection = true,
    this.enableLinkDetection = true,
    this.onTextChanged,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (!enableListDetection || text.isEmpty) {
      return Text(text, style: textStyle);
    }

    final spans = _buildEnhancedTextSpansWithLists(context);
    return RichText(
      text: TextSpan(children: spans),
      textAlign: TextAlign.start,
    );
  }

  List<InlineSpan> _buildEnhancedTextSpansWithLists(BuildContext context) {
    final lines = text.split('\n');
    final List<InlineSpan> spans = [];
    int currentCharPosition = 0; // Track absolute position in original text
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final listItem = ListDetector.detectListItem(line, lineNumber: i);
      
      if (listItem != null && listItem.type == ListType.checkbox) {
        // Handle checkbox with clickable functionality and full formatting
        spans.add(_buildEnhancedCheckboxSpan(context, listItem, currentCharPosition));
      } else if (listItem != null) {
        // Add other list items with full formatting
        final listSpans = _buildFormattedSpansWithLinks(context, listItem.formattedText, textStyle.copyWith(
          fontWeight: FontWeight.normal,
        ));
        spans.addAll(listSpans.cast<InlineSpan>());
      } else {
        // Regular text with full formatting
        final lineSpans = _buildFormattedSpansWithLinks(context, line, textStyle);
        spans.addAll(lineSpans.cast<InlineSpan>());
      }
      
      // Update character position (line + newline)
      currentCharPosition += line.length + 1;
      
      // Add newline except for the last line
      if (i < lines.length - 1) {
        spans.add(TextSpan(
          text: '\n',
          style: textStyle,
        ));
      }
    }
    
    return spans;
  }

  TextSpan _buildEnhancedCheckboxSpan(BuildContext context, ListItem listItem, int charPosition) {
    final List<TextSpan> children = [];
    
    // Add checkbox symbol
    children.add(TextSpan(
      text: listItem.isChecked ? '▣ ' : '☐ ',
      style: textStyle.copyWith(
        fontSize: textStyle.fontSize,
        fontWeight: FontWeight.normal,
        height: 1.0,
        color: listItem.isChecked ? Colors.grey : textStyle.color,
      ),
      recognizer: TapGestureRecognizer()
        ..onTap = () => _toggleCheckboxByPosition(listItem, charPosition),
    ));
    
    // Add content with full formatting
    final contentSpans = _buildFormattedSpansWithLinks(
      context,
      listItem.content,
      textStyle.copyWith(
        fontWeight: FontWeight.normal,
        color: listItem.isChecked ? Colors.grey : textStyle.color,
      ),
    );
    children.addAll(contentSpans);
    
    return TextSpan(children: children);
  }

  List<TextSpan> _buildFormattedSpansWithLinks(BuildContext context, String text, TextStyle style) {
    // First detect URLs in the text
    final links = enableLinkDetection ? LinkDetector.detectLinks(text) : <LinkMatch>[];
    
    if (links.isEmpty) {
      // No links, just apply markdown formatting
      if (enableFormatDetection && FormatDetector.hasFormatting(text)) {
        return FormatDetector.buildFormattedSpans(text, style, context);
      }
      return [TextSpan(text: text, style: style)];
    }

    // Process text with both links and formatting
    final List<TextSpan> spans = [];
    int lastIndex = 0;
    
    for (final link in links) {
      // Process text before the link with formatting
      if (link.start > lastIndex) {
        final beforeText = text.substring(lastIndex, link.start);
        if (enableFormatDetection && FormatDetector.hasFormatting(beforeText)) {
          spans.addAll(FormatDetector.buildFormattedSpans(beforeText, style, context));
        } else {
          spans.add(TextSpan(text: beforeText, style: style));
        }
      }
      
      // Add the clickable link
      spans.add(TextSpan(
        text: link.text,
        style: style.copyWith(
          color: Theme.of(context).colorScheme.primary,
          decorationColor: Theme.of(context).colorScheme.primary,
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.w600,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () => LinkLauncher.launchURL(link.url),
      ));
      
      lastIndex = link.end;
    }
    
    // Process remaining text after the last link
    if (lastIndex < text.length) {
      final remainingText = text.substring(lastIndex);
      if (enableFormatDetection && FormatDetector.hasFormatting(remainingText)) {
        spans.addAll(FormatDetector.buildFormattedSpans(remainingText, style, context));
      } else {
        spans.add(TextSpan(text: remainingText, style: style));
      }
    }
    
    return spans;
  }

  void _toggleCheckboxByPosition(ListItem listItem, int approximateCharPosition) {
    if (onTextChanged == null && controller == null) return;
    
    final newCheckedState = !listItem.isChecked;
    
    // Find all occurrences of this checkbox content (supports both - [] and -[])
    final escapedContent = RegExp.escape(listItem.content);
    final checkboxRegex = RegExp(r'^\s*-\s?\[\s*([x\s]?)\s*\]\s*' + escapedContent + r'\s*$', multiLine: true, caseSensitive: false);
    
    final matches = checkboxRegex.allMatches(text).toList();
    
    if (matches.isEmpty) {
      return; // No matches found
    }
    
    if (matches.length == 1) {
      // Only one match, safe to replace
      final newText = text.replaceFirstMapped(checkboxRegex, (match) {
        return match.group(0)!.replaceFirst(
          RegExp(r'-\s?\[\s*([x\s]?)\s*\]'),
          '- [${newCheckedState ? 'x' : ' '}]',
        );
      });
      
      if (controller != null) {
        controller!.text = newText;
      }
      onTextChanged?.call(newText);
      return;
    }
    
    // Multiple matches - find the closest one to our approximate position
    int bestMatchIndex = 0;
    int minDistance = (matches[0].start - approximateCharPosition).abs();
    
    for (int i = 1; i < matches.length; i++) {
      int distance = (matches[i].start - approximateCharPosition).abs();
      if (distance < minDistance) {
        minDistance = distance;
        bestMatchIndex = i;
      }
    }
    
    // Replace only the best match
    String newText = text;
    int matchCount = 0;
    
    newText = text.replaceAllMapped(checkboxRegex, (match) {
      bool shouldReplace = matchCount == bestMatchIndex;
      matchCount++; // Increment after checking
      
      if (shouldReplace) {
        return match.group(0)!.replaceFirst(
          RegExp(r'-\s?\[\s*([x\s]?)\s*\]'),
          '- [${newCheckedState ? 'x' : ' '}]',
        );
      } else {
        return match.group(0)!;
      }
    });
    
    if (controller != null) {
      controller!.text = newText;
    }
    
    onTextChanged?.call(newText);
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
