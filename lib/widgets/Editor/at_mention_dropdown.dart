import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/file_picker_service.dart';
import 'format_handler.dart';

typedef AtMentionApplyText = void Function(
  String newText, {
  TextSelection? selection,
});

class AtMentionOption {
  final String label;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const AtMentionOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
}

class AtMentionDropdownController {
  static final AtMentionDropdownController instance = AtMentionDropdownController._();
  AtMentionDropdownController._();

  static const double _itemExtent = 64.0;
  static const double _overlayWidth = 280.0;
  static const double _overlayMaxHeight = 220.0;
  static const double _overlayHorizontalMargin = 8.0;
  static const double _overlayVerticalGap = 22.0;
  static const Duration _scrollAnimationDuration = Duration(milliseconds: 140);

  OverlayEntry? _entry;
  int _selectedIndex = 0;
  List<AtMentionOption> _options = [];
  StateSetter? _overlayStateSetter;
  ScrollController? _scrollController;

  bool get isOpen => _entry != null;
  int get selectedIndex => _selectedIndex;

  void showEditorDropdown({
    required BuildContext context,
    required LayerLink layerLink,
    required ValueNotifier<Offset> offsetNotifier,
    required ValueNotifier<double> lineHeightNotifier,
    required String query,
    required int triggerIndex,
    required String Function() currentText,
    required TextSelection Function() currentSelection,
    required AtMentionApplyText applyText,
    required VoidCallback onContentChanged,
    required VoidCallback requestFocus,
  }) {
    final options = _buildEditorOptions(
      triggerIndex: triggerIndex,
      currentText: currentText,
      currentSelection: currentSelection,
      applyText: applyText,
      onContentChanged: onContentChanged,
      requestFocus: requestFocus,
    );

    final filteredOptions = options.where((opt) {
      final lowerQuery = query.toLowerCase();
      return opt.label.toLowerCase().contains(lowerQuery) ||
          opt.subtitle.toLowerCase().contains(lowerQuery);
    }).toList();

    if (filteredOptions.isEmpty) {
      if (isOpen) hide();
      return;
    }

    show(
      context: context,
      layerLink: layerLink,
      offsetNotifier: offsetNotifier,
      lineHeightNotifier: lineHeightNotifier,
      options: filteredOptions,
      onClosed: () {},
    );
  }

  List<AtMentionOption> _buildEditorOptions({
    required int triggerIndex,
    required String Function() currentText,
    required TextSelection Function() currentSelection,
    required AtMentionApplyText applyText,
    required VoidCallback onContentChanged,
    required VoidCallback requestFocus,
  }) {
    return [
      AtMentionOption(
        label: 'Bold',
        subtitle: 'Make selected text bold',
        icon: Icons.format_bold_rounded,
        onTap: () => _removeTriggerAndInvoke(
          triggerIndex,
          currentText,
          currentSelection,
          applyText,
          onContentChanged,
          requestFocus,
          () => _applyFormat(
            currentText,
            currentSelection,
            applyText,
            onContentChanged,
            requestFocus,
            FormatType.bold,
          ),
        ),
      ),
      AtMentionOption(
        label: 'Italic',
        subtitle: 'Make selected text italic',
        icon: Icons.format_italic_rounded,
        onTap: () => _removeTriggerAndInvoke(
          triggerIndex,
          currentText,
          currentSelection,
          applyText,
          onContentChanged,
          requestFocus,
          () => _applyFormat(
            currentText,
            currentSelection,
            applyText,
            onContentChanged,
            requestFocus,
            FormatType.italic,
          ),
        ),
      ),
      AtMentionOption(
        label: 'Strikethrough',
        subtitle: 'Strike through text',
        icon: Icons.format_strikethrough_rounded,
        onTap: () => _removeTriggerAndInvoke(
          triggerIndex,
          currentText,
          currentSelection,
          applyText,
          onContentChanged,
          requestFocus,
          () => _applyFormat(
            currentText,
            currentSelection,
            applyText,
            onContentChanged,
            requestFocus,
            FormatType.strikethrough,
          ),
        ),
      ),
      AtMentionOption(
        label: 'Inline Code',
        subtitle: 'Wrap selection with backticks',
        icon: Icons.code_rounded,
        onTap: () => _removeTriggerAndInvoke(
          triggerIndex,
          currentText,
          currentSelection,
          applyText,
          onContentChanged,
          requestFocus,
          () => _applyFormat(
            currentText,
            currentSelection,
            applyText,
            onContentChanged,
            requestFocus,
            FormatType.code,
          ),
        ),
      ),
      AtMentionOption(
        label: 'Copy Block',
        subtitle: 'Wrap selection as copy block',
        icon: Icons.copy_all_rounded,
        onTap: () => _removeTriggerAndInvoke(
          triggerIndex,
          currentText,
          currentSelection,
          applyText,
          onContentChanged,
          requestFocus,
          () => _applyFormat(
            currentText,
            currentSelection,
            applyText,
            onContentChanged,
            requestFocus,
            FormatType.taggedCode,
          ),
        ),
      ),
      AtMentionOption(
        label: 'Link File',
        subtitle: 'Link a local file',
        icon: Icons.insert_drive_file_outlined,
        onTap: () => _handleLinkFile(
          triggerIndex,
          currentText,
          currentSelection,
          applyText,
          onContentChanged,
          requestFocus,
        ),
      ),
      AtMentionOption(
        label: 'Link Folder',
        subtitle: 'Link a local folder',
        icon: Icons.folder_open_outlined,
        onTap: () => _handleLinkFolder(
          triggerIndex,
          currentText,
          currentSelection,
          applyText,
          onContentChanged,
          requestFocus,
        ),
      ),
      AtMentionOption(
        label: 'Note Link',
        subtitle: 'Insert link to another note',
        icon: Icons.file_present_rounded,
        onTap: () => _removeTriggerAndInvoke(
          triggerIndex,
          currentText,
          currentSelection,
          applyText,
          onContentChanged,
          requestFocus,
          () => _applyFormat(
            currentText,
            currentSelection,
            applyText,
            onContentChanged,
            requestFocus,
            FormatType.noteLink,
          ),
        ),
      ),
      AtMentionOption(
        label: 'Notebook Link',
        subtitle: 'Insert link to a notebook',
        icon: Icons.book_rounded,
        onTap: () => _removeTriggerAndInvoke(
          triggerIndex,
          currentText,
          currentSelection,
          applyText,
          onContentChanged,
          requestFocus,
          () => _applyFormat(
            currentText,
            currentSelection,
            applyText,
            onContentChanged,
            requestFocus,
            FormatType.notebookLink,
          ),
        ),
      ),
      AtMentionOption(
        label: 'Hyperlink',
        subtitle: 'Insert a hyperlink',
        icon: Icons.link_rounded,
        onTap: () => _removeTriggerAndInvoke(
          triggerIndex,
          currentText,
          currentSelection,
          applyText,
          onContentChanged,
          requestFocus,
          () => _applyFormat(
            currentText,
            currentSelection,
            applyText,
            onContentChanged,
            requestFocus,
            FormatType.link,
          ),
        ),
      ),
      AtMentionOption(
        label: 'Horizontal Divider',
        subtitle: 'Insert a horizontal divider',
        icon: Icons.horizontal_rule_rounded,
        onTap: () => _removeTriggerAndInvoke(
          triggerIndex,
          currentText,
          currentSelection,
          applyText,
          onContentChanged,
          requestFocus,
          () => _applyFormat(
            currentText,
            currentSelection,
            applyText,
            onContentChanged,
            requestFocus,
            FormatType.horizontalRule,
          ),
        ),
      ),
      AtMentionOption(
        label: 'Heading 1',
        subtitle: 'Insert heading 1',
        icon: Icons.title_rounded,
        onTap: () => _removeTriggerAndInvoke(
          triggerIndex,
          currentText,
          currentSelection,
          applyText,
          onContentChanged,
          requestFocus,
          () => _applyFormat(
            currentText,
            currentSelection,
            applyText,
            onContentChanged,
            requestFocus,
            FormatType.heading1,
          ),
        ),
      ),
      AtMentionOption(
        label: 'Heading 2',
        subtitle: 'Insert heading 2',
        icon: Icons.title_rounded,
        onTap: () => _removeTriggerAndInvoke(
          triggerIndex,
          currentText,
          currentSelection,
          applyText,
          onContentChanged,
          requestFocus,
          () => _applyFormat(
            currentText,
            currentSelection,
            applyText,
            onContentChanged,
            requestFocus,
            FormatType.heading2,
          ),
        ),
      ),
      AtMentionOption(
        label: 'Heading 3',
        subtitle: 'Insert heading 3',
        icon: Icons.title_rounded,
        onTap: () => _removeTriggerAndInvoke(
          triggerIndex,
          currentText,
          currentSelection,
          applyText,
          onContentChanged,
          requestFocus,
          () => _applyFormat(
            currentText,
            currentSelection,
            applyText,
            onContentChanged,
            requestFocus,
            FormatType.heading3,
          ),
        ),
      ),
      AtMentionOption(
        label: 'Heading 4',
        subtitle: 'Insert heading 4',
        icon: Icons.title_rounded,
        onTap: () => _removeTriggerAndInvoke(
          triggerIndex,
          currentText,
          currentSelection,
          applyText,
          onContentChanged,
          requestFocus,
          () => _applyFormat(
            currentText,
            currentSelection,
            applyText,
            onContentChanged,
            requestFocus,
            FormatType.heading4,
          ),
        ),
      ),
      AtMentionOption(
        label: 'Heading 5',
        subtitle: 'Insert heading 5',
        icon: Icons.title_rounded,
        onTap: () => _removeTriggerAndInvoke(
          triggerIndex,
          currentText,
          currentSelection,
          applyText,
          onContentChanged,
          requestFocus,
          () => _applyFormat(
            currentText,
            currentSelection,
            applyText,
            onContentChanged,
            requestFocus,
            FormatType.heading5,
          ),
        ),
      ),
      AtMentionOption(
        label: 'Numbered List',
        subtitle: 'Start a numbered list',
        icon: Icons.format_list_numbered_rounded,
        onTap: () => _removeTriggerAndInvoke(
          triggerIndex,
          currentText,
          currentSelection,
          applyText,
          onContentChanged,
          requestFocus,
          () => _applyFormat(
            currentText,
            currentSelection,
            applyText,
            onContentChanged,
            requestFocus,
            FormatType.numbered,
          ),
        ),
      ),
      AtMentionOption(
        label: 'Bullet List',
        subtitle: 'Start a bullet list',
        icon: Icons.format_list_bulleted_rounded,
        onTap: () => _removeTriggerAndInvoke(
          triggerIndex,
          currentText,
          currentSelection,
          applyText,
          onContentChanged,
          requestFocus,
          () => _applyFormat(
            currentText,
            currentSelection,
            applyText,
            onContentChanged,
            requestFocus,
            FormatType.bullet,
          ),
        ),
      ),
      AtMentionOption(
        label: 'Checkbox List',
        subtitle: 'Insert checkbox list item',
        icon: Icons.checklist_rounded,
        onTap: () => _removeTriggerAndInvoke(
          triggerIndex,
          currentText,
          currentSelection,
          applyText,
          onContentChanged,
          requestFocus,
          () => _applyFormat(
            currentText,
            currentSelection,
            applyText,
            onContentChanged,
            requestFocus,
            FormatType.checkboxUnchecked,
          ),
        ),
      ),
      AtMentionOption(
        label: 'Insert #script',
        subtitle: 'Wrap selection with #script',
        icon: Icons.text_snippet_rounded,
        onTap: () => _removeTriggerAndInvoke(
          triggerIndex,
          currentText,
          currentSelection,
          applyText,
          onContentChanged,
          requestFocus,
          () => _applyFormat(
            currentText,
            currentSelection,
            applyText,
            onContentChanged,
            requestFocus,
            FormatType.insertScript,
          ),
        ),
      ),
      AtMentionOption(
        label: 'Convert to Script Block',
        subtitle: 'Convert selection to script block',
        icon: Icons.code_rounded,
        onTap: () => _removeTriggerAndInvoke(
          triggerIndex,
          currentText,
          currentSelection,
          applyText,
          onContentChanged,
          requestFocus,
          () => _applyFormat(
            currentText,
            currentSelection,
            applyText,
            onContentChanged,
            requestFocus,
            FormatType.convertToScript,
          ),
        ),
      ),
    ];
  }

  void _removeTriggerAndInvoke(
    int triggerIndex,
    String Function() currentText,
    TextSelection Function() currentSelection,
    AtMentionApplyText applyText,
    VoidCallback onContentChanged,
    VoidCallback requestFocus,
    VoidCallback action,
  ) {
    final activeSelection = currentSelection();
    if (!activeSelection.isValid) {
      action();
      requestFocus();
      return;
    }

    final cursorOffset = activeSelection.baseOffset;
    final currentTextValue = currentText();
    if (cursorOffset < triggerIndex || triggerIndex < 0 || triggerIndex > currentTextValue.length) {
      action();
      requestFocus();
      return;
    }

    final newText = currentTextValue.replaceRange(triggerIndex, cursorOffset, '');
    final newSelection = TextSelection.collapsed(offset: triggerIndex);
    applyText(newText, selection: newSelection);
    onContentChanged();
    action();
    requestFocus();
  }

  void _handleLinkFile(
    int triggerIndex,
    String Function() currentText,
    TextSelection Function() currentSelection,
    AtMentionApplyText applyText,
    VoidCallback onContentChanged,
    VoidCallback requestFocus,
  ) async {
    final result = await FilePickerService.pickLocalFile();
    if (result != null) {
      final name = result['name']!;
      final path = result['path']!;
      _insertLinkAtTriggerIndex(
        triggerIndex,
        '[$name](${Uri.file(path).toString()})',
        currentText,
        currentSelection,
        applyText,
        onContentChanged,
        requestFocus,
      );
    }
  }

  void _handleLinkFolder(
    int triggerIndex,
    String Function() currentText,
    TextSelection Function() currentSelection,
    AtMentionApplyText applyText,
    VoidCallback onContentChanged,
    VoidCallback requestFocus,
  ) async {
    final result = await FilePickerService.pickLocalFolder();
    if (result != null) {
      final name = result['name']!;
      final path = result['path']!;
      _insertLinkAtTriggerIndex(
        triggerIndex,
        '[$name](${Uri.file(path).toString()})',
        currentText,
        currentSelection,
        applyText,
        onContentChanged,
        requestFocus,
      );
    }
  }

  void _insertLinkAtTriggerIndex(
    int triggerIndex,
    String markdownLink,
    String Function() currentText,
    TextSelection Function() currentSelection,
    AtMentionApplyText applyText,
    VoidCallback onContentChanged,
    VoidCallback requestFocus,
  ) {
    final activeSelection = currentSelection();
    if (!activeSelection.isValid) return;

    final cursorOffset = activeSelection.baseOffset;
    final currentTextValue = currentText();
    final newText = currentTextValue.replaceRange(triggerIndex, cursorOffset, markdownLink);

    applyText(
      newText,
      selection: TextSelection.collapsed(
        offset: triggerIndex + markdownLink.length,
      ),
    );
    onContentChanged();
    requestFocus();
  }

  void _applyFormat(
    String Function() currentText,
    TextSelection Function() currentSelection,
    AtMentionApplyText applyText,
    VoidCallback onContentChanged,
    VoidCallback requestFocus,
    FormatType type,
  ) {
    final activeSelection = currentSelection();
    if (!activeSelection.isValid) return;

    final currentTextValue = currentText();
    final selection = activeSelection;

    if (type == FormatType.insertScript) {
      if (currentTextValue.startsWith('#script')) {
        final newText = currentTextValue.replaceFirst(RegExp(r'^#script\n?'), '');
        applyText(newText, selection: const TextSelection.collapsed(offset: 0));
      } else {
        applyText('#script\n$currentTextValue', selection: TextSelection.collapsed(offset: '#script\n'.length));
      }
      onContentChanged();
      requestFocus();
      return;
    }

    if (type == FormatType.convertToScript) {
      applyText(currentTextValue, selection: selection);
      onContentChanged();
      requestFocus();
      return;
    }

    String newText = currentTextValue;
    TextSelection newSelection = selection;

    if (selection.isCollapsed) {
      final cursor = selection.start;
      String insertion = '';
      int cursorOffset = 0;

      if (_isLineFormat(type)) {
        final lineStart = _lineStart(currentTextValue, cursor);
        final prefix = _getLinePrefix(type);
        newText = currentTextValue.substring(0, lineStart) + prefix + currentTextValue.substring(lineStart);
        newSelection = TextSelection.collapsed(offset: cursor + prefix.length);
      } else {
        switch (type) {
          case FormatType.bold:
            insertion = '****';
            cursorOffset = 2;
            break;
          case FormatType.italic:
            insertion = '**';
            cursorOffset = 1;
            break;
          case FormatType.strikethrough:
            insertion = '~~~~';
            cursorOffset = 2;
            break;
          case FormatType.code:
            insertion = '``';
            cursorOffset = 1;
            break;
          case FormatType.link:
            insertion = '[]()';
            cursorOffset = 1;
            break;
          case FormatType.noteLink:
            insertion = '[[note:]]';
            cursorOffset = 7;
            break;
          case FormatType.notebookLink:
            insertion = '[[notebook:]]';
            cursorOffset = 11;
            break;
          case FormatType.taggedCode:
            insertion = '[]';
            cursorOffset = 1;
            break;
          default:
            break;
        }

        if (insertion.isNotEmpty) {
          newText = currentTextValue.substring(0, cursor) + insertion + currentTextValue.substring(cursor);
          newSelection = TextSelection.collapsed(offset: cursor + cursorOffset);
        }
      }
    } else {
      final start = selection.start;
      final end = selection.end;
      newText = FormatUtils.toggleFormat(currentTextValue, start, end, type);
      final diff = newText.length - currentTextValue.length;
      newSelection = TextSelection.collapsed(offset: end + diff);
    }

    if (newText != currentTextValue) {
      applyText(newText, selection: newSelection);
      onContentChanged();
    }

    requestFocus();
  }

  bool _isLineFormat(FormatType type) {
    return type == FormatType.heading1 ||
        type == FormatType.heading2 ||
        type == FormatType.heading3 ||
        type == FormatType.heading4 ||
        type == FormatType.heading5 ||
        type == FormatType.numbered ||
        type == FormatType.bullet ||
        type == FormatType.checkboxUnchecked ||
        type == FormatType.checkboxChecked;
  }

  int _lineStart(String text, int cursor) {
    if (cursor <= 0) return 0;
    final lineStart = text.lastIndexOf('\n', cursor - 1) + 1;
    return lineStart < 0 ? 0 : lineStart;
  }

  String _getLinePrefix(FormatType type) {
    switch (type) {
      case FormatType.heading1:
        return '# ';
      case FormatType.heading2:
        return '## ';
      case FormatType.heading3:
        return '### ';
      case FormatType.heading4:
        return '#### ';
      case FormatType.heading5:
        return '##### ';
      case FormatType.numbered:
        return '1. ';
      case FormatType.bullet:
        return '- ';
      case FormatType.checkboxUnchecked:
        return '- [ ] ';
      case FormatType.checkboxChecked:
        return '- [x] ';
      default:
        return '';
    }
  }

  void show({
    required BuildContext context,
    required LayerLink layerLink,
    required ValueNotifier<Offset> offsetNotifier,
    required ValueNotifier<double> lineHeightNotifier,
    required List<AtMentionOption> options,
    required VoidCallback onClosed,
  }) {
    hide();
    _options = options;
    _selectedIndex = 0;
    _scrollController = ScrollController();

    _entry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: hide,
                child: const SizedBox.expand(),
              ),
            ),
            StatefulBuilder(
              builder: (context, setState) {
                _overlayStateSetter = setState;
                final colorScheme = Theme.of(context).colorScheme;

                return Positioned(
                  width: _overlayWidth,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([offsetNotifier, lineHeightNotifier]),
                    child: Material(
                      elevation: 8,
                      clipBehavior: Clip.antiAlias,
                      borderRadius: BorderRadius.circular(12),
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      shadowColor: Colors.black.withAlpha(40),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withAlpha(128),
                            width: 1,
                          ),
                        ),
                        constraints: const BoxConstraints(maxHeight: _overlayMaxHeight),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              child: ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                shrinkWrap: true,
                                itemExtent: _itemExtent,
                                itemCount: _options.length,
                                itemBuilder: (context, index) {
                                  final option = _options[index];
                                  final isSelected = index == _selectedIndex;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 3,
                                    ),
                                    child: InkWell(
                                      onTap: () {
                                        option.onTap();
                                        hide();
                                        onClosed();
                                      },
                                      borderRadius: BorderRadius.circular(10),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 120),
                                        curve: Curves.easeOutCubic,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? colorScheme.primary.withAlpha(18)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isSelected
                                                ? colorScheme.primary.withAlpha(42)
                                                : Colors.transparent,
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 28,
                                              height: 28,
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? colorScheme.primary.withAlpha(24)
                                                    : colorScheme.surfaceContainerHighest,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                option.icon,
                                                size: 16,
                                                color: isSelected
                                                    ? colorScheme.primary
                                                    : colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    option.label,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w600,
                                                      color: colorScheme.onSurface,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    option.subtitle,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: colorScheme.onSurfaceVariant,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    builder: (context, child) {
                      final screenSize = MediaQuery.of(context).size;
                      final cursorOffset = offsetNotifier.value;
                      final menuHeight = _getMenuHeight();
                      final openAbove = _shouldOpenAbove(
                        screenSize: screenSize,
                        cursorOffset: cursorOffset,
                        menuHeight: menuHeight,
                      );
                      final followerOffset = _getFollowerOffset(
                        screenSize: screenSize,
                        cursorOffset: cursorOffset,
                        menuHeight: menuHeight,
                        openAbove: openAbove,
                      );

                      return CompositedTransformFollower(
                        link: layerLink,
                        showWhenUnlinked: false,
                        offset: followerOffset,
                        child: child!,
                      );
                    },
                  ),
                );
              },
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_entry!);
  }

  void hide() {
    _entry?.remove();
    _entry = null;
    _overlayStateSetter = null;
    _scrollController?.dispose();
    _scrollController = null;
  }

  double _getMenuHeight() {
    final estimatedHeight = (_options.length * _itemExtent) + 12;
    return estimatedHeight.clamp(0.0, _overlayMaxHeight);
  }

  bool _shouldOpenAbove({
    required Size screenSize,
    required Offset cursorOffset,
    required double menuHeight,
  }) {
    final belowTop = cursorOffset.dy;
    final belowBottom = belowTop + menuHeight;
    final aboveBottom = cursorOffset.dy - _overlayVerticalGap;
    final aboveTop = aboveBottom - menuHeight;

    final fitsBelow = belowBottom <= screenSize.height - _overlayVerticalGap;
    final fitsAbove = aboveTop >= _overlayVerticalGap;

    if (fitsBelow && !fitsAbove) return false;
    if (!fitsBelow && fitsAbove) return true;
    if (!fitsBelow && !fitsAbove) {
      return (screenSize.height - belowTop) < aboveBottom;
    }

    final spaceBelow = screenSize.height - belowTop;
    final spaceAbove = aboveBottom;
    return spaceBelow < spaceAbove;
  }

  Offset _getFollowerOffset({
    required Size screenSize,
    required Offset cursorOffset,
    required double menuHeight,
    required bool openAbove,
  }) {
    final double x = cursorOffset.dx.clamp(
      _overlayHorizontalMargin,
      screenSize.width - _overlayWidth - _overlayHorizontalMargin,
    );

    final double y = openAbove
      ? cursorOffset.dy - menuHeight - _overlayVerticalGap
        : cursorOffset.dy;

    return Offset(x, y);
  }

  bool handleKeyEvent(KeyEvent event) {
    if (!isOpen || _overlayStateSetter == null || _options.isEmpty) return false;

    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _moveSelection(1);
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _moveSelection(-1);
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        _options[_selectedIndex].onTap();
        hide();
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        hide();
        return true;
      }
    }
    return false;
  }

  void _moveSelection(int delta) {
    if (_options.isEmpty) return;

    final nextIndex = (_selectedIndex + delta).clamp(0, _options.length - 1);
    if (nextIndex == _selectedIndex) {
      return;
    }

    _overlayStateSetter?.call(() {
      _selectedIndex = nextIndex;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelected();
    });
  }

  void _scrollToSelected() {
    if (_scrollController == null || !_scrollController!.hasClients) return;
    final position = _scrollController!.position;
    final viewport = position.viewportDimension;
    final targetOffset =
        (_selectedIndex * _itemExtent) - ((viewport - _itemExtent) / 2);

    _scrollController!.animateTo(
      targetOffset.clamp(0.0, position.maxScrollExtent),
      duration: _scrollAnimationDuration,
      curve: Curves.easeOutCubic,
    );
  }
}
