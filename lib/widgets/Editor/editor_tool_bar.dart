import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import '../../shortcuts_handler.dart';
import '../custom_tooltip.dart';
import '../context_menu.dart';
import 'format_handler.dart';

class EditorBottomBar extends StatefulWidget {
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onNextNote;
  final VoidCallback onPreviousNote;
  final Function(FormatType) onFormatTap;
  final VoidCallback onInsertLinkTap;
  final bool isReadMode;

  const EditorBottomBar({
    super.key,
    required this.onUndo,
    required this.onRedo,
    required this.onNextNote,
    required this.onPreviousNote,
    required this.onFormatTap,
    required this.onInsertLinkTap,
    this.isReadMode = false,
  });

  @override
  State<EditorBottomBar> createState() => _EditorBottomBarState();
}

class _EditorBottomBarState extends State<EditorBottomBar> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildTooltipIconButton(
    BuildContext context, {
    required IconData iconData,
    required VoidCallback onPressed,
    required String tooltipMessage,
    String? shortcutMessage,
    double iconSize = 20,
  }) {
    final message =
        shortcutMessage == null
            ? tooltipMessage
            : '$tooltipMessage ($shortcutMessage)';

    return CustomTooltip(
      message: message,
      builder:
          (context, isHovering) => IconButton(
            icon: Icon(iconData, size: iconSize),
            onPressed: onPressed,
            visualDensity: VisualDensity.compact,
          ),
    );
  }

  void _showHeadingsMenu(BuildContext context, Offset position) {
    ContextMenuOverlay.show(
      context: context,
      tapPosition: position,
      items: [
        ContextMenuItem(
          icon: Symbols.format_h2_rounded,
          label: 'Heading 2',
          onTap: () => widget.onFormatTap(FormatType.heading2),
        ),
        ContextMenuItem(
          icon: Symbols.format_h3_rounded,
          label: 'Heading 3',
          onTap: () => widget.onFormatTap(FormatType.heading3),
        ),
        ContextMenuItem(
          icon: Symbols.format_h4_rounded,
          label: 'Heading 4',
          onTap: () => widget.onFormatTap(FormatType.heading4),
        ),
        ContextMenuItem(
          icon: Symbols.format_h5_rounded,
          label: 'Heading 5',
          onTap: () => widget.onFormatTap(FormatType.heading5),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isReadMode) return const SizedBox.shrink();

    bool isMobile = MediaQuery.of(context).size.width < 600;
    double toolbarHeight = isMobile ? 40 : 40;
    double iconSize = isMobile ? 24 : 20;

    return SizedBox(
      width: double.infinity,
      height: toolbarHeight,
      child: Listener(
        onPointerSignal: (pointerSignal) {
          if (pointerSignal is PointerScrollEvent) {
            _scrollController.position.moveTo(
              _scrollController.position.pixels + pointerSignal.scrollDelta.dy,
              curve: Curves.linear,
              duration: const Duration(milliseconds: 20),
            );
          }
        },
        child: Align(
          alignment: Alignment.centerLeft,
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _buildTooltipIconButton(
                  context,
                  iconData: Icons.undo_rounded,
                  onPressed: widget.onUndo,
                  tooltipMessage: 'Undo (Ctrl+Z)',
                  iconSize: iconSize,
                ),
                _buildTooltipIconButton(
                  context,
                  iconData: Icons.redo_rounded,
                  onPressed: widget.onRedo,
                  tooltipMessage: 'Redo (Ctrl+Shift+Z)',
                  iconSize: iconSize,
                ),
                _buildTooltipIconButton(
                  context,
                  iconData: Icons.keyboard_arrow_up_rounded,
                  onPressed: widget.onPreviousNote,
                  tooltipMessage: 'Previous Note',
                  iconSize: iconSize,
                ),
                _buildTooltipIconButton(
                  context,
                  iconData: Icons.keyboard_arrow_down_rounded,
                  onPressed: widget.onNextNote,
                  tooltipMessage: 'Next Note',
                  iconSize: iconSize,
                ),
                const VerticalDivider(width: 16, indent: 8, endIndent: 8),
                _buildTooltipIconButton(
                  context,
                  iconData: Icons.format_bold_rounded,
                  onPressed: () => widget.onFormatTap(FormatType.bold),
                  tooltipMessage: 'Bold',
                  shortcutMessage:
                      ShortcutsHandler.editorFormatShortcutLabel(
                        FormatType.bold,
                      ),
                  iconSize: iconSize,
                ),
                _buildTooltipIconButton(
                  context,
                  iconData: Icons.format_italic_rounded,
                  onPressed: () => widget.onFormatTap(FormatType.italic),
                  tooltipMessage: 'Italic',
                  shortcutMessage:
                      ShortcutsHandler.editorFormatShortcutLabel(
                        FormatType.italic,
                      ),
                  iconSize: iconSize,
                ),
                _buildTooltipIconButton(
                  context,
                  iconData: Icons.format_strikethrough_rounded,
                  onPressed: () => widget.onFormatTap(FormatType.strikethrough),
                  tooltipMessage: 'Strikethrough',
                  shortcutMessage:
                      ShortcutsHandler.editorFormatShortcutLabel(
                        FormatType.strikethrough,
                      ),
                  iconSize: iconSize,
                ),
                _buildTooltipIconButton(
                  context,
                  iconData: Icons.code_rounded,
                  onPressed: () => widget.onFormatTap(FormatType.code),
                  tooltipMessage: 'Inline Code',
                  shortcutMessage:
                      ShortcutsHandler.editorFormatShortcutLabel(
                        FormatType.code,
                      ),
                  iconSize: iconSize,
                ),
                _buildTooltipIconButton(
                  context,
                  iconData: Icons.copy_all_rounded,
                  onPressed: () => widget.onFormatTap(FormatType.taggedCode),
                  tooltipMessage: 'Copy Block',
                  shortcutMessage:
                      ShortcutsHandler.editorFormatShortcutLabel(
                        FormatType.taggedCode,
                      ),
                  iconSize: iconSize,
                ),
                const VerticalDivider(width: 16, indent: 8, endIndent: 8),
                _buildTooltipIconButton(
                  context,
                  iconData: Icons.file_present_rounded,
                  onPressed: () => widget.onFormatTap(FormatType.noteLink),
                  tooltipMessage: 'Note Link',
                  shortcutMessage:
                      ShortcutsHandler.editorFormatShortcutLabel(
                        FormatType.noteLink,
                      ),
                  iconSize: iconSize,
                ),
                _buildTooltipIconButton(
                  context,
                  iconData: Icons.book_rounded,
                  onPressed: () => widget.onFormatTap(FormatType.notebookLink),
                  tooltipMessage: 'Notebook Link',
                  shortcutMessage:
                      ShortcutsHandler.editorFormatShortcutLabel(
                        FormatType.notebookLink,
                      ),
                  iconSize: iconSize,
                ),
                _buildTooltipIconButton(
                  context,
                  iconData: Icons.link_rounded,
                  onPressed: widget.onInsertLinkTap,
                  tooltipMessage: 'Insert URL',
                  shortcutMessage:
                      ShortcutsHandler.editorFormatShortcutLabel(
                        FormatType.link,
                      ),
                  iconSize: iconSize,
                ),
                _buildTooltipIconButton(
                  context,
                  iconData: Icons.horizontal_rule_rounded,
                  onPressed:
                      () => widget.onFormatTap(FormatType.horizontalRule),
                  tooltipMessage: 'Horizontal Divider',
                  shortcutMessage:
                      ShortcutsHandler.editorFormatShortcutLabel(
                        FormatType.horizontalRule,
                      ),
                  iconSize: iconSize,
                ),
                const VerticalDivider(width: 16, indent: 8, endIndent: 8),
                GestureDetector(
                  onSecondaryTapDown:
                      (details) =>
                          _showHeadingsMenu(context, details.globalPosition),
                  onLongPressStart:
                      (details) =>
                          _showHeadingsMenu(context, details.globalPosition),
                  child: _buildTooltipIconButton(
                    context,
                    iconData: Symbols.format_h1_rounded,
                    onPressed: () => widget.onFormatTap(FormatType.heading1),
                    tooltipMessage: 'Heading 1 (Right click for more)',
                    shortcutMessage:
                        ShortcutsHandler.editorFormatShortcutLabel(
                          FormatType.heading1,
                        ),
                    iconSize: iconSize,
                  ),
                ),
                const VerticalDivider(width: 16, indent: 8, endIndent: 8),
                _buildTooltipIconButton(
                  context,
                  iconData: Icons.format_list_numbered_rounded,
                  onPressed: () => widget.onFormatTap(FormatType.numbered),
                  tooltipMessage: 'Numbered List',
                  shortcutMessage:
                      ShortcutsHandler.editorFormatShortcutLabel(
                        FormatType.numbered,
                      ),
                  iconSize: iconSize,
                ),
                _buildTooltipIconButton(
                  context,
                  iconData: Icons.format_list_bulleted_rounded,
                  onPressed: () => widget.onFormatTap(FormatType.bullet),
                  tooltipMessage: 'Bullet List',
                  shortcutMessage:
                      ShortcutsHandler.editorFormatShortcutLabel(
                        FormatType.bullet,
                      ),
                  iconSize: iconSize,
                ),
                _buildTooltipIconButton(
                  context,
                  iconData: Icons.checklist_rounded,
                  onPressed:
                      () => widget.onFormatTap(FormatType.checkboxUnchecked),
                  tooltipMessage: 'Checkbox List',
                  shortcutMessage:
                      ShortcutsHandler.editorFormatShortcutLabel(
                        FormatType.checkboxUnchecked,
                      ),
                  iconSize: iconSize,
                ),
                const VerticalDivider(width: 16, indent: 8, endIndent: 8),
                _buildTooltipIconButton(
                  context,
                  iconData: Icons.text_snippet_rounded,
                  onPressed: () => widget.onFormatTap(FormatType.insertScript),
                  tooltipMessage: 'Insert #script',
                  shortcutMessage:
                      ShortcutsHandler.editorFormatShortcutLabel(
                        FormatType.insertScript,
                      ),
                  iconSize: iconSize,
                ),
                _buildTooltipIconButton(
                  context,
                  iconData: Symbols.code_blocks_rounded,
                  onPressed:
                      () => widget.onFormatTap(FormatType.convertToScript),
                  tooltipMessage: 'Convert to Script Block',
                  shortcutMessage:
                      ShortcutsHandler.editorFormatShortcutLabel(
                        FormatType.convertToScript,
                      ),
                  iconSize: iconSize,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
