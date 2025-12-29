import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'format_handler.dart';

class EditorBottomBar extends StatefulWidget {
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final Function(FormatType) onFormatTap;
  final bool isReadMode;

  const EditorBottomBar({
    super.key,
    required this.onUndo,
    required this.onRedo,
    required this.onFormatTap,
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
    required Icon icon,
    required VoidCallback onPressed,
    required String tooltipMessage,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return MouseRegionHoverItem(
      builder: (context, isHovering) {
        final button = IconButton(
          icon: icon,
          onPressed: onPressed,
          visualDensity: VisualDensity.compact,
        );
        if (isHovering) {
          return Tooltip(
            message: tooltipMessage,
            waitDuration: const Duration(milliseconds: 500),
            textStyle: TextStyle(color: colorScheme.onSurface),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withAlpha(255),
              borderRadius: BorderRadius.circular(8),
            ),
            child: button,
          );
        }
        return button;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isReadMode) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      height: 40,
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
                icon: const Icon(Icons.undo_rounded, size: 20),
                onPressed: widget.onUndo,
                tooltipMessage: 'Undo (Ctrl+Z)',
              ),
              _buildTooltipIconButton(
                context,
                icon: const Icon(Icons.redo_rounded, size: 20),
                onPressed: widget.onRedo,
                tooltipMessage: 'Redo (Ctrl+Shift+Z)',
              ),
              const VerticalDivider(width: 16, indent: 8, endIndent: 8),
              _buildTooltipIconButton(
                context,
                icon: const Icon(Icons.format_bold_rounded, size: 20),
                onPressed: () => widget.onFormatTap(FormatType.bold),
                tooltipMessage: 'Bold',
              ),
              _buildTooltipIconButton(
                context,
                icon: const Icon(Icons.format_italic_rounded, size: 20),
                onPressed: () => widget.onFormatTap(FormatType.italic),
                tooltipMessage: 'Italic',
              ),
              _buildTooltipIconButton(
                context,
                icon: const Icon(Icons.format_strikethrough_rounded, size: 20),
                onPressed: () => widget.onFormatTap(FormatType.strikethrough),
                tooltipMessage: 'Strikethrough',
              ),
              _buildTooltipIconButton(
                context,
                icon: const Icon(Icons.code_rounded, size: 20),
                onPressed: () => widget.onFormatTap(FormatType.code),
                tooltipMessage: 'Inline Code',
              ),
              const VerticalDivider(width: 16, indent: 8, endIndent: 8),
              _buildTooltipIconButton(
                context,
                icon: const Icon(Icons.file_present_rounded, size: 20),
                onPressed: () => widget.onFormatTap(FormatType.noteLink),
                tooltipMessage: 'Note Link',
              ),
              _buildTooltipIconButton(
                context,
                icon: const Icon(Icons.link_rounded, size: 20),
                onPressed: () => widget.onFormatTap(FormatType.link),
                tooltipMessage: 'Hyperlink',
              ),
              _buildTooltipIconButton(
                context,
                icon: const Icon(Icons.horizontal_rule_rounded, size: 20),
                onPressed: () => widget.onFormatTap(FormatType.horizontalRule),
                tooltipMessage: 'Horizontal Divider',
              ),
              const VerticalDivider(width: 16, indent: 8, endIndent: 8),
              _buildTooltipIconButton(
                context,
                icon: const Icon(Symbols.format_h1_rounded, size: 20),
                onPressed: () => widget.onFormatTap(FormatType.heading1),
                tooltipMessage: 'Heading 1',
              ),
              _buildTooltipIconButton(
                context,
                icon: const Icon(Symbols.format_h2_rounded, size: 20),
                onPressed: () => widget.onFormatTap(FormatType.heading2),
                tooltipMessage: 'Heading 2',
              ),
              _buildTooltipIconButton(
                context,
                icon: const Icon(Symbols.format_h3_rounded, size: 20),
                onPressed: () => widget.onFormatTap(FormatType.heading3),
                tooltipMessage: 'Heading 3',
              ),
              _buildTooltipIconButton(
                context,
                icon: const Icon(Symbols.format_h4_rounded, size: 20),
                onPressed: () => widget.onFormatTap(FormatType.heading4),
                tooltipMessage: 'Heading 4',
              ),
              _buildTooltipIconButton(
                context,
                icon: const Icon(Symbols.format_h5_rounded, size: 20),
                onPressed: () => widget.onFormatTap(FormatType.heading5),
                tooltipMessage: 'Heading 5',
              ),
              const VerticalDivider(width: 16, indent: 8, endIndent: 8),
              _buildTooltipIconButton(
                context,
                icon: const Icon(Icons.format_list_numbered_rounded, size: 20),
                onPressed: () => widget.onFormatTap(FormatType.numbered),
                tooltipMessage: 'Numbered List',
              ),
              _buildTooltipIconButton(
                context,
                icon: const Icon(Icons.format_list_bulleted_rounded, size: 20),
                onPressed: () => widget.onFormatTap(FormatType.bullet),
                tooltipMessage: 'Bullet List',
              ),
              _buildTooltipIconButton(
                context,
                icon: const Icon(Symbols.asterisk_rounded, size: 20),
                onPressed: () => widget.onFormatTap(FormatType.asterisk),
                tooltipMessage: 'Asterisk List',
              ),
              _buildTooltipIconButton(
                context,
                icon: const Icon(Icons.check_box_outline_blank_rounded, size: 20),
                onPressed: () => widget.onFormatTap(FormatType.checkboxUnchecked),
                tooltipMessage: 'Checkbox Unchecked',
              ),
              _buildTooltipIconButton(
                context,
                icon: const Icon(Icons.check_box_rounded, size: 20),
                onPressed: () => widget.onFormatTap(FormatType.checkboxChecked),
                tooltipMessage: 'Checkbox Checked',
              ),
              const VerticalDivider(width: 16, indent: 8, endIndent: 8),
              _buildTooltipIconButton(
                context,
                icon: const Icon(Icons.text_snippet_rounded, size: 20),
                onPressed: () => widget.onFormatTap(FormatType.insertScript),
                tooltipMessage: 'Insert #script',
              ),
              _buildTooltipIconButton(
                context,
                icon: const Icon(Symbols.code_blocks_rounded, size: 20),
                onPressed: () => widget.onFormatTap(FormatType.convertToScript),
                tooltipMessage: 'Convert to Script Block',
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}

class MouseRegionHoverItem extends StatefulWidget {
  final Widget Function(BuildContext, bool) builder;

  const MouseRegionHoverItem({super.key, required this.builder});

  @override
  State<MouseRegionHoverItem> createState() => _MouseRegionHoverItemState();
}

class _MouseRegionHoverItemState extends State<MouseRegionHoverItem> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: widget.builder(context, _isHovering),
    );
  }
}
