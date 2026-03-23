import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../services/immersive_mode_service.dart';
import '../../Settings/editor_settings_panel.dart';
import '../custom_tooltip.dart';
import '../../scriptmode_handler.dart';
import '../../animations/animations_handler.dart';
import '../../database/models/note.dart';
import '../../services/export_service.dart';
import 'note_statistics_dialog.dart';
import '../context_menu.dart';

class EditorHeaderBar extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController noteController;
  final FocusNode editorFocusNode;
  final bool isReadMode;
  final bool isScript;
  final bool isSplitView;
  final bool isEditorCentered;
  final bool showBottomBar;
  final ImmersiveModeService immersiveModeService;
  final SaveAnimationController saveController;
  final Note selectedNote;
  final VoidCallback onTitleChanged;
  final VoidCallback onSave;
  final VoidCallback onToggleReadMode;
  final VoidCallback onToggleSplitView;
  final VoidCallback onToggleEditorCentered;

  EditorHeaderBar({
    super.key,
    required this.titleController,
    required this.noteController,
    required this.editorFocusNode,
    required this.isReadMode,
    required this.isScript,
    required this.isSplitView,
    required this.isEditorCentered,
    required this.showBottomBar,
    required this.immersiveModeService,
    required this.saveController,
    required this.selectedNote,
    required this.onTitleChanged,
    required this.onSave,
    required this.onToggleReadMode,
    required this.onToggleSplitView,
    required this.onToggleEditorCentered,
  });

  final GlobalKey _exportButtonKey = GlobalKey();

  void _showExportMenu(BuildContext context) {
    final title =
        titleController.text.trim().isEmpty
            ? 'Untitled Note'
            : titleController.text.trim();
    final content = noteController.text;

    final List<ContextMenuItem> menuItems = [
      ContextMenuItem(
        icon: Icons.description_outlined,
        label: 'Export to Markdown',
        onTap:
            () => ExportService.exportToMarkdown(
              context: context,
              title: title,
              content: content,
            ),
      ),
      ContextMenuItem(
        icon: Icons.html_rounded,
        label: 'Export to HTML',
        onTap:
            () => ExportService.exportToHtml(
              context: context,
              title: title,
              content: content,
            ),
      ),
      ContextMenuItem(
        icon: Icons.picture_as_pdf_outlined,
        label: 'Export to PDF',
        onTap:
            () => ExportService.exportToPdf(
              context: context,
              title: title,
              content: content,
            ),
      ),
      ContextMenuItem(
        icon: Icons.analytics_outlined,
        label: 'Note Statistics',
        onTap: () {
          showDialog(
            context: context,
            builder:
                (context) => NoteStatisticsDialog(
                  note: selectedNote.copyWith(
                    title: titleController.text,
                    content: noteController.text,
                  ),
                ),
          );
        },
      ),
    ];

    final RenderBox? button =
        _exportButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (button != null) {
      final Offset offset = button.localToGlobal(Offset.zero);
      final Size size = button.size;

      final double menuX = offset.dx;
      final double menuY = offset.dy + size.height;

      ContextMenuOverlay.show(
        context: context,
        tapPosition: Offset(menuX, menuY),
        items: menuItems,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44.0,
      alignment: Alignment.center,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent) {
                  if (event.logicalKey == LogicalKeyboardKey.keyT &&
                      HardwareKeyboard.instance.isControlPressed) {
                    return KeyEventResult.ignored;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.keyN &&
                      HardwareKeyboard.instance.isControlPressed) {
                    return KeyEventResult.ignored;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.keyW &&
                      HardwareKeyboard.instance.isControlPressed) {
                    return KeyEventResult.ignored;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.tab) {
                    if (!isReadMode) {
                      editorFocusNode.requestFocus();
                      noteController.selection = const TextSelection.collapsed(
                        offset: 0,
                      );
                      return KeyEventResult.handled;
                    }
                  }
                }
                return KeyEventResult.ignored;
              },
              child: TextField(
                autofocus: true,
                controller: titleController,
                decoration: const InputDecoration(
                  hintText: 'Title',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.only(top: 10, bottom: 10),
                  isDense: true,
                ),
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(height: 1.2),
                onChanged: (_) => onTitleChanged(),
                readOnly: isReadMode,
                maxLines: 1,
                textAlignVertical: TextAlignVertical.center,
                onSubmitted: (_) {
                  if (!isReadMode) {
                    editorFocusNode.requestFocus();
                    noteController.selection = const TextSelection.collapsed(
                      offset: 0,
                    );
                  }
                },
              ),
            ),
          ),
          if (isScript)
            Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: DurationEstimatorDesktop(content: noteController.text),
            ),
          CustomTooltip(
            message: 'Save note',
            builder:
                (context, isHovering) =>
                    SaveButton(controller: saveController, onPressed: onSave),
          ),
          CustomTooltip(
            message: isReadMode ? 'Edit mode (Ctrl+P)' : 'Read mode (Ctrl+P)',
            builder:
                (context, isHovering) => IconButton(
                  icon: Icon(
                    isReadMode ? Icons.edit_rounded : Icons.visibility_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: onToggleReadMode,
                ),
          ),
          CustomTooltip(
            message: 'Split view (Ctrl+Shift+P)',
            builder:
                (context, isHovering) => IconButton(
                  icon: Icon(
                    isSplitView
                        ? Symbols.split_scene_right_rounded
                        : Symbols.split_scene_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: onToggleSplitView,
                ),
          ),
          CustomTooltip(
            message:
                isEditorCentered
                    ? 'Disable centered layout (F1)'
                    : 'Enable centered layout (F1)',
            builder:
                (context, isHovering) => IconButton(
                  icon: Icon(
                    isEditorCentered
                        ? Icons.format_align_justify_rounded
                        : Icons.format_align_center_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: onToggleEditorCentered,
                ),
          ),
          CustomTooltip(
            message:
                showBottomBar ? 'Hide formatting bar' : 'Show formatting bar',
            builder:
                (context, isHovering) => IconButton(
                  icon: Icon(
                    showBottomBar
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: () {
                    EditorSettings.setShowBottomBar(!showBottomBar);
                  },
                ),
          ),
          if (immersiveModeService.isImmersiveMode)
            CustomTooltip(
              message: 'Exit immersive mode (F4)',
              builder:
                  (context, isHovering) => IconButton(
                    icon: Icon(
                      Icons.fullscreen_exit_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: () => immersiveModeService.exitImmersiveMode(),
                  ),
            ),
          IconButton(
            key: _exportButtonKey,
            icon: Icon(
              Icons.more_vert_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            onPressed: () => _showExportMenu(context),
          ),
        ],
      ),
    );
  }
}
