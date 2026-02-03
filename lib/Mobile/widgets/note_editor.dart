import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:dynamic_color/dynamic_color.dart';
import '../../database/models/note.dart';
import '../../database/models/notebook.dart';
import '../../database/models/think.dart';
import '../../database/database_helper.dart';
import '../animations/animations_handler.dart';
import '../scriptmode_handler.dart';
import '../theme_handler.dart';
import '../../widgets/custom_snackbar.dart';
import '../../Settings/editor_settings_panel.dart';
import '../../widgets/Editor/list_continuation_handler.dart';
import '../../widgets/Editor/editor_tool_bar.dart';
import '../../widgets/Editor/format_handler.dart';
import '../../widgets/Editor/unified_text_handler.dart';
import 'note_statistics_drawer.dart';

class NoteEditor extends StatefulWidget {
  final Note? selectedNote;
  final Think? selectedThink;
  final TextEditingController titleController;
  final TextEditingController contentController;
  final FocusNode contentFocusNode;
  final bool isEditing;
  final bool isImmersiveMode;
  final Future<void> Function() onSave;
  final VoidCallback onToggleEditing;
  final VoidCallback onTitleChanged;
  final VoidCallback onContentChanged;
  final Function(bool) onToggleImmersiveMode;
  final VoidCallback? onNextNote;
  final VoidCallback? onPreviousNote;
  final Function(Note)? onNoteLinkTap;
  final Function(Notebook)? onNotebookLinkTap;

  const NoteEditor({
    super.key,
    this.selectedNote,
    this.selectedThink,
    required this.titleController,
    required this.contentController,
    required this.contentFocusNode,
    required this.isEditing,
    required this.isImmersiveMode,
    required this.onSave,
    required this.onToggleEditing,
    required this.onTitleChanged,
    required this.onContentChanged,

    required this.onToggleImmersiveMode,
    this.onNextNote,
    this.onPreviousNote,
    this.onNoteLinkTap,
    this.onNotebookLinkTap,
  }) : assert(selectedNote != null || selectedThink != null);

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> with TickerProviderStateMixin {
  late final AnimationController _scaleController;
  bool _isScript = false;
  bool _isReadMode = false;
  Timer? _scriptDetectionDebouncer;
  Timer? _autoSaveDebounce;
  late SaveAnimationController _saveController;
  final ValueNotifier<int> _currentBlockIndex = ValueNotifier<int>(0);
  final UndoHistoryController _undoController = UndoHistoryController();
  bool _isImmersiveMode = false;
  late Future<bool> _brightnessFuture;
  late Future<bool> _colorModeFuture;
  late Future<bool> _monochromeFuture;
  late Future<bool> _einkFuture;
  String _lastTextContent = '';
  bool _isHandlingContentChange = false;
  bool _isNavigatingAway = false;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _saveController = SaveAnimationController(vsync: this);
    _lastTextContent = widget.contentController.text;
    _lastTextContent = widget.contentController.text;
    widget.titleController.addListener(_onTitleChanged);
    _detectScriptMode();
    _loadThemePreferences();
  }

  void _loadThemePreferences() {
    _brightnessFuture = ThemeManager.getThemeBrightness();
    _colorModeFuture = ThemeManager.getColorModeEnabled();
    _monochromeFuture = ThemeManager.getMonochromeEnabled();
    _einkFuture = ThemeManager.getEInkEnabled();
  }

  void _onTitleChanged() {
    widget.onTitleChanged();

    _autoSaveDebounce?.cancel();
    _autoSaveDebounce = Timer(const Duration(milliseconds: 500), () {
      _handleSave(isAutoSave: true);
    });
  }

  void _onContentChanged() {
    if (_isHandlingContentChange) return;
    _isHandlingContentChange = true;

    try {
      final currentText = widget.contentController.text;

      // Only trigger updates if the actual text changed, not just selection
      if (currentText == _lastTextContent) {
        return;
      }

      // Check for newline insertion from virtual keyboard
      if (currentText.length == _lastTextContent.length + 1) {
        final selection = widget.contentController.selection;
        if (selection.isValid &&
            selection.isCollapsed &&
            selection.baseOffset > 0) {
          final insertedChar = currentText[selection.baseOffset - 1];
          if (insertedChar == '\n') {
            // Attempt to handle list continuation based on the new state
            if (ListContinuationHandler.handleVirtualKeyboardEnter(
              widget.contentController,
            )) {
              // Update _lastTextContent to the handled text so we don't re-process
              _lastTextContent = widget.contentController.text;
              widget.onContentChanged();
              _resetDebouncers();
              return;
            }
          }
        }
      }

      _lastTextContent = currentText;

      widget.onContentChanged();

      _resetDebouncers();
    } finally {
      _isHandlingContentChange = false;
    }
  }

  void _resetDebouncers() {
    _scriptDetectionDebouncer?.cancel();
    _scriptDetectionDebouncer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _isScript = ScriptModeHandler.isScript(widget.contentController.text);
          if (_isScript) {
            _currentBlockIndex.value = 0;
          }
        });
      }
    });

    _autoSaveDebounce?.cancel();
    _autoSaveDebounce = Timer(const Duration(milliseconds: 500), () {
      _handleSave(isAutoSave: true);
    });
  }

  void _detectScriptMode() {
    setState(() {
      _isScript = ScriptModeHandler.isScript(widget.contentController.text);
      if (_isScript) {
        _currentBlockIndex.value = 0;
      }
    });
  }

  void _toggleReadMode() {
    setState(() {
      _isReadMode = !_isReadMode;
      if (!_isReadMode) {
        _isImmersiveMode = false;
      }
    });
  }

  void _toggleImmersiveMode() {
    if (_isReadMode && _isScript) {
      setState(() {
        _isImmersiveMode = !_isImmersiveMode;
      });
      widget.onToggleImmersiveMode(_isImmersiveMode);
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _handleSave({bool isAutoSave = false}) async {
    if (!mounted) return;

    if (isAutoSave && _saveController.isAnimating) {
      await widget.onSave();
      return;
    }

    try {
      _saveController.start();
      final startTime = DateTime.now();

      await widget.onSave();
      DatabaseHelper.notifyDatabaseChanged();

      final elapsedTime = DateTime.now().difference(startTime).inMilliseconds;
      final remainingTime = elapsedTime;

      if (remainingTime > 0 && mounted) {
        await Future.delayed(Duration(milliseconds: remainingTime));
      }

      if (mounted) {
        await _saveController.complete();
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        _saveController.reset();
        setState(() {});
        if (!isAutoSave) {
          CustomSnackbar.show(
            context: context,
            message: 'Error saving note',
            type: CustomSnackbarType.error,
          );
        }
      }
      rethrow;
    }
  }

  Future<void> _handleBackNavigation() async {
    if (!mounted) return;
    setState(() {
      _isNavigatingAway = true;
    });

    try {
      await widget.onSave();
      DatabaseHelper.notifyDatabaseChanged();
    } catch (e) {
      debugPrint('Error saving note: $e');
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleNextNote() async {
    setState(() {
      _isNavigatingAway = true;
    });
    await _handleSave();
    widget.onNextNote?.call();
  }

  Future<void> _handlePreviousNote() async {
    setState(() {
      _isNavigatingAway = true;
    });
    await _handleSave();
    widget.onPreviousNote?.call();
  }

  void _handleCreateScriptBlock() {
    final selection = widget.contentController.selection;
    if (selection.isValid && !selection.isCollapsed) {
      final text = widget.contentController.text;
      final selectedText = text.substring(selection.start, selection.end);

      final lines = text.split('\n');

      // Find the block number where the selection starts
      int currentPosition = 0;
      int selectionLineIndex = 0;
      List<int> blockNumbers = [];
      int? previousBlockNumber;
      int? nextBlockNumber;

      // First pass: collect block numbers and find the position
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];

        // Check for block numbers in the entire line
        final blockMatches = RegExp(r'#(\d+)').allMatches(line);
        for (final match in blockMatches) {
          final blockNumber = int.tryParse(match.group(1) ?? '1') ?? 1;
          blockNumbers.add(blockNumber);

          if (currentPosition + match.start <= selection.start) {
            previousBlockNumber = blockNumber;
          } else {
            nextBlockNumber ??= blockNumber;
          }
        }

        if (currentPosition <= selection.start) {
          selectionLineIndex = i;
        }
        currentPosition += line.length + 1; // +1 for the newline
      }

      // Determine the new block number
      int newBlockNumber;
      if (previousBlockNumber != null && nextBlockNumber != null) {
        // If we're between two blocks, use the next number after the previous block
        newBlockNumber = previousBlockNumber + 1;
      } else if (previousBlockNumber != null) {
        // If we're at the end, use the next number after the last block
        newBlockNumber = previousBlockNumber + 1;
      } else if (nextBlockNumber != null) {
        // If we're at the start, use 1
        newBlockNumber = 1;
      } else {
        // If there are no blocks, start with 1
        newBlockNumber = 1;
      }

      // Second pass: update block numbers after the insertion
      final updatedLines = List<String>.from(lines);
      int currentNumber = newBlockNumber + 1;

      for (int i = 0; i < updatedLines.length; i++) {
        final line = updatedLines[i];
        if (i > selectionLineIndex) {
          // Replace all block numbers in the line
          updatedLines[i] = line.replaceAllMapped(
            RegExp(r'#\d+'),
            (match) => '#$currentNumber',
          );
          if (line.contains(RegExp(r'#\d+'))) {
            currentNumber++;
          }
        }
      }

      // Check if we need to add newlines
      final textBeforeSelection = text.substring(0, selection.start);
      final textAfterSelection = text.substring(selection.end);
      final isAtStart = selection.start == 0;
      final isAtEnd = selection.end == text.length;
      final isInMiddleOfSentence =
          !textBeforeSelection.endsWith('.') &&
          !textBeforeSelection.endsWith('!') &&
          !textBeforeSelection.endsWith('?');
      final needsNewlineBefore =
          !isAtStart &&
          !textBeforeSelection.endsWith('\n') &&
          !isInMiddleOfSentence;
      final needsNewlineAfter =
          !isAtEnd &&
          !textAfterSelection.startsWith('\n') &&
          !isInMiddleOfSentence;

      // Create the new text with the block
      final newText = updatedLines
          .join('\n')
          .replaceRange(
            selection.start,
            selection.end,
            '${needsNewlineBefore ? '\n' : ''}#$newBlockNumber\n$selectedText${needsNewlineAfter ? '\n' : ''}',
          );

      // Update the text controller
      widget.contentController.text = newText;

      // Update the selection to include the new block header
      final selectionOffset = needsNewlineBefore ? 1 : 0;
      widget.contentController.selection = TextSelection(
        baseOffset: selection.start + selectionOffset,
        extentOffset:
            selection.start +
            selectionOffset +
            '#$newBlockNumber\n'.length +
            selectedText.length +
            (needsNewlineAfter ? 1 : 0),
      );

      // Trigger content changed
      widget.onContentChanged();
    }
  }

  void _handleFormat(FormatType type) {
    if (_isReadMode) return;

    final controller = widget.contentController;

    if (type == FormatType.insertScript) {
      final text = controller.text;
      if (text.startsWith('#script')) {
        // Remove #script and any following newline
        String newText = text.replaceFirst(RegExp(r'^#script\n?'), '');
        controller.text = newText;
        widget.onContentChanged();
      } else {
        controller.text = '#script\n$text';
        widget.onContentChanged();
      }
      widget.contentFocusNode.requestFocus();
      return;
    }

    if (type == FormatType.convertToScript) {
      _handleCreateScriptBlock();
      widget.contentFocusNode.requestFocus();
      return;
    }

    final text = controller.text;
    final selection = controller.selection;

    if (selection.start < 0) {
      widget.contentFocusNode.requestFocus();
      return;
    }

    String newText = text;
    TextSelection newSelection = selection;

    if (selection.isCollapsed) {
      // Insert mode
      final cursor = selection.start;
      String insertion = "";
      int cursorOffset = 0;

      // Check for line-based formats
      if (_isLineFormat(type)) {
        // Get current line start
        int lineStart = 0;
        if (cursor > 0) {
          lineStart = text.lastIndexOf('\n', cursor - 1) + 1;
          if (lineStart < 0) lineStart = 0;
        }

        String prefix = _getLinePrefix(type);
        // Insert at line start
        newText =
            text.substring(0, lineStart) + prefix + text.substring(lineStart);
        newSelection = TextSelection.collapsed(offset: cursor + prefix.length);
      } else {
        // Inline formats
        switch (type) {
          case FormatType.bold:
            insertion = "****";
            cursorOffset = 2;
            break;
          case FormatType.italic:
            insertion = "**";
            cursorOffset = 1;
            break;
          case FormatType.strikethrough:
            insertion = "~~~~";
            cursorOffset = 2;
            break;
          case FormatType.code:
            insertion = "``";
            cursorOffset = 1;
            break;
          case FormatType.link:
            insertion = "[]()";
            cursorOffset = 1;
            break;
          case FormatType.noteLink:
            insertion = "[[note:]]";
            cursorOffset = 7;
            break;
          case FormatType.notebookLink:
            insertion = "[[notebook:]]";
            cursorOffset = 11;
            break;
          case FormatType.taggedCode:
            insertion = "[]";
            cursorOffset = 1;
            break;
          default:
            break;
        }
        if (insertion.isNotEmpty) {
          newText =
              text.substring(0, cursor) + insertion + text.substring(cursor);
          newSelection = TextSelection.collapsed(offset: cursor + cursorOffset);
        }
      }
    } else {
      // Selection mode - use existing util
      final start = selection.start;
      final end = selection.end;
      newText = FormatUtils.toggleFormat(text, start, end, type);

      // Attempt to keep selection at the end of the modified block
      // To improve this we would need FormatUtils to return where the new selection should be.
      // For now, collapsing to end of modification is safe.
      int newLen = newText.length;
      int diff = newLen - text.length;
      newSelection = TextSelection.collapsed(offset: end + diff);
    }

    if (newText != text) {
      controller.value = TextEditingValue(
        text: newText,
        selection: newSelection,
        composing: TextRange.empty,
      );
      widget.onContentChanged();
    }

    // Ensure focus and prevent keyboard closing
    widget.contentFocusNode.requestFocus();
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

  String _getLinePrefix(FormatType type) {
    switch (type) {
      case FormatType.heading1:
        return "# ";
      case FormatType.heading2:
        return "## ";
      case FormatType.heading3:
        return "### ";
      case FormatType.heading4:
        return "#### ";
      case FormatType.heading5:
        return "##### ";
      case FormatType.numbered:
        return "1. ";
      case FormatType.bullet:
        return "- ";
      case FormatType.checkboxUnchecked:
        return "- [ ] ";
      case FormatType.checkboxChecked:
        return "- [x] ";
      default:
        return "";
    }
  }

  @override
  void dispose() {
    widget.contentController.removeListener(_onContentChanged);
    widget.titleController.removeListener(_onTitleChanged);
    _scriptDetectionDebouncer?.cancel();
    _autoSaveDebounce?.cancel();
    _saveController.dispose();
    _scaleController.dispose();
    _currentBlockIndex.dispose();
    widget.contentFocusNode.dispose();
    _undoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return FutureBuilder(
          future: Future.wait([
            _brightnessFuture,
            _colorModeFuture,
            _monochromeFuture,
            _einkFuture,
          ]),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();

            final isDarkMode = snapshot.data![0];
            final colorMode = snapshot.data![1];
            final monochromeMode = snapshot.data![2];
            final einkMode = snapshot.data![3];

            final theme = ThemeManager.buildTheme(
              lightDynamic: lightDynamic,
              darkDynamic: darkDynamic,
              isDarkMode: isDarkMode,
              colorModeEnabled: colorMode,
              monochromeEnabled: monochromeMode,
              einkEnabled: einkMode,
            );

            return Theme(
              data: theme,
              child: PopScope(
                canPop: !isKeyboardVisible,
                onPopInvokedWithResult: (bool didPop, bool? result) {
                  if (didPop) return;

                  if (isKeyboardVisible) {
                    FocusScope.of(context).unfocus();
                    return;
                  }

                  _handleBackNavigation();
                },
                child: Scaffold(
                  backgroundColor: theme.colorScheme.surface,
                  endDrawer: NoteStatisticsDrawer(
                    note: widget.selectedNote,
                    think: widget.selectedThink,
                    currentTitle: widget.titleController.text,
                    currentContent: widget.contentController.text,
                  ),
                  appBar:
                      _isImmersiveMode
                          ? null
                          : AppBar(
                            toolbarHeight: 40.0,
                            scrolledUnderElevation: 0,
                            surfaceTintColor: Colors.transparent,
                            backgroundColor: theme.colorScheme.surface,
                            title: TextField(
                              controller: widget.titleController,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText:
                                    widget.selectedThink != null
                                        ? 'Think title'
                                        : 'Note title',
                                contentPadding: EdgeInsets.zero,
                              ),
                              enabled: widget.isEditing && !_isReadMode,
                              onChanged: (_) => widget.onTitleChanged(),
                            ),
                            leading: IconButton(
                              icon: const Icon(Icons.arrow_back_rounded),
                              onPressed: () {
                                FocusScope.of(context).unfocus();
                                _handleBackNavigation();
                              },
                            ),
                            actions: [
                              if (_isScript)
                                DurationEstimator(
                                  content: widget.contentController.text,
                                  controller: widget.contentController,
                                ),
                              Builder(
                                builder:
                                    (context) => IconButton(
                                      icon: const Icon(
                                        Icons.analytics_outlined,
                                      ),
                                      onPressed: () {
                                        Scaffold.of(context).openEndDrawer();
                                      },
                                    ),
                              ),
                            ],
                          ),
                  body: SafeArea(
                    child: GestureDetector(
                      onLongPress: _toggleImmersiveMode,
                      behavior: HitTestBehavior.translucent,
                      child: Stack(
                        children: [
                          Column(
                            children: [
                              if (!_isImmersiveMode && !isKeyboardVisible)
                                Divider(
                                  height: 0,
                                  thickness: 1,
                                  color: theme.colorScheme.outlineVariant,
                                ),
                              Expanded(
                                child:
                                    _isReadMode && _isScript
                                        ? _isImmersiveMode
                                            ? ValueListenableBuilder<int>(
                                              valueListenable:
                                                  _currentBlockIndex,
                                              builder: (
                                                context,
                                                currentIndex,
                                                child,
                                              ) {
                                                return ScriptModeHandler.buildScriptPreview(
                                                  context: context,
                                                  content:
                                                      widget
                                                          .contentController
                                                          .text,
                                                  currentBlockIndex:
                                                      _currentBlockIndex,
                                                  onBlockChanged: () {
                                                    widget.onContentChanged();
                                                  },
                                                );
                                              },
                                            )
                                            : ScriptModeHandler.buildRegularPreview(
                                              context: context,
                                              content:
                                                  widget.contentController.text,
                                            )
                                        : widget.isEditing && !_isReadMode
                                        ? Padding(
                                          padding: const EdgeInsets.only(
                                            top: 8,
                                            left: 8,
                                            right: 8,
                                          ),
                                          child: Focus(
                                            onKeyEvent: (node, event) {
                                              // Handle Enter key for list continuation
                                              if (event is KeyDownEvent &&
                                                  event.logicalKey ==
                                                      LogicalKeyboardKey
                                                          .enter) {
                                                final isShiftPressed =
                                                    HardwareKeyboard
                                                        .instance
                                                        .isShiftPressed;

                                                // Try to handle list continuation
                                                if (ListContinuationHandler.handleEnterKey(
                                                  widget.contentController,
                                                  isShiftPressed,
                                                )) {
                                                  widget.onContentChanged();
                                                  return KeyEventResult.handled;
                                                }

                                                // If not handled by list continuation, let default behavior proceed
                                              }

                                              return KeyEventResult.ignored;
                                            },
                                            child: TextField(
                                              controller:
                                                  widget.contentController,
                                              undoController: _undoController,
                                              autofocus:
                                                  (widget.selectedNote?.id ??
                                                      widget
                                                          .selectedThink
                                                          ?.id) !=
                                                  null,
                                              focusNode:
                                                  widget.contentFocusNode,
                                              maxLines: null,
                                              expands: true,
                                              textCapitalization:
                                                  TextCapitalization.sentences,
                                              cursorOpacityAnimates: true,
                                              cursorWidth: 2,
                                              cursorRadius:
                                                  const Radius.circular(2),
                                              cursorColor:
                                                  theme.colorScheme.primary,
                                              style: TextStyle(
                                                fontSize: 18,
                                                height: 1.4,
                                                color:
                                                    theme.colorScheme.onSurface,
                                              ),
                                              keyboardType:
                                                  TextInputType.multiline,
                                              decoration: InputDecoration(
                                                border: InputBorder.none,
                                                hintText:
                                                    widget.selectedThink != null
                                                        ? 'Start thinking...'
                                                        : 'Start writing...',
                                                contentPadding: EdgeInsets.zero,
                                              ),
                                              onChanged:
                                                  (_) => _onContentChanged(),
                                              readOnly: _isReadMode,
                                              contextMenuBuilder: (
                                                context,
                                                editableTextState,
                                              ) {
                                                final buttonItems =
                                                    editableTextState
                                                        .contextMenuButtonItems;
                                                final anchors =
                                                    editableTextState
                                                        .contextMenuAnchors;
                                                final mediaQuery =
                                                    MediaQuery.of(context);

                                                // Define visible bounds
                                                final topBound =
                                                    mediaQuery.padding.top +
                                                    kToolbarHeight +
                                                    20;
                                                final bottomBound =
                                                    mediaQuery.size.height -
                                                    mediaQuery
                                                        .viewInsets
                                                        .bottom -
                                                    20;

                                                // Check if primary anchor is outside visible area
                                                final primaryY =
                                                    anchors.primaryAnchor.dy;

                                                if (primaryY < topBound ||
                                                    primaryY > bottomBound) {
                                                  // Clamp to visible area
                                                  final clampedY = primaryY
                                                      .clamp(
                                                        topBound,
                                                        bottomBound,
                                                      );
                                                  final centerX =
                                                      mediaQuery.size.width / 2;

                                                  return AdaptiveTextSelectionToolbar.buttonItems(
                                                    anchors:
                                                        TextSelectionToolbarAnchors(
                                                          primaryAnchor: Offset(
                                                            centerX,
                                                            clampedY,
                                                          ),
                                                        ),
                                                    buttonItems: buttonItems,
                                                  );
                                                }

                                                return AdaptiveTextSelectionToolbar.buttonItems(
                                                  anchors: anchors,
                                                  buttonItems: buttonItems,
                                                );
                                              },
                                            ),
                                          ),
                                        )
                                        : SingleChildScrollView(
                                          padding: const EdgeInsets.only(
                                            top: 8,
                                            left: 8,
                                            right: 8,
                                            bottom:
                                                80, // Add padding for bottom bar/FloatingActionButton
                                          ),
                                          child: Align(
                                            alignment: Alignment.topLeft,
                                            child: UnifiedTextHandler(
                                              text:
                                                  widget.contentController.text,
                                              textStyle: TextStyle(
                                                fontSize: 18,
                                                height: 1.4,
                                                color:
                                                    theme.colorScheme.onSurface,
                                              ),
                                              onNoteLinkTap: (note, _) {
                                                setState(() {
                                                  _isNavigatingAway = true;
                                                });
                                                widget.onNoteLinkTap?.call(
                                                  note,
                                                );
                                              },
                                              onNotebookLinkTap: (notebook, _) {
                                                setState(() {
                                                  _isNavigatingAway = true;
                                                });
                                                widget.onNotebookLinkTap?.call(
                                                  notebook,
                                                );
                                              },
                                              onTextChanged: (newText) {
                                                widget.contentController.text =
                                                    newText;
                                                widget.onContentChanged();
                                              },
                                              showNoteLinkBrackets: false,
                                            ),
                                          ),
                                        ),
                              ),
                              if (widget.isEditing && !_isReadMode)
                                EditorBottomBar(
                                  onUndo: _undoController.undo,
                                  onRedo: _undoController.redo,
                                  onNextNote: _handleNextNote,
                                  onPreviousNote: _handlePreviousNote,
                                  onFormatTap: _handleFormat,
                                  isReadMode: _isReadMode,
                                ),
                            ],
                          ),
                          if (!_isImmersiveMode && !_isNavigatingAway)
                            Positioned(
                              bottom:
                                  16 +
                                  (widget.isEditing && !_isReadMode ? 40 : 0),
                              right: 16,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (widget.isEditing && !_isReadMode) ...[
                                    FloatingActionButton(
                                      key: const ValueKey('save'),
                                      heroTag: null,
                                      onPressed: () => _handleSave(),
                                      elevation: 4,
                                      child: const Icon(Icons.save_rounded),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: Theme.of(
                                        context,
                                      ).colorScheme.copyWith(
                                        surfaceTint:
                                            _isReadMode && _isScript
                                                ? Colors.transparent
                                                : null,
                                      ),
                                    ),
                                    child: FloatingActionButton(
                                      key: ValueKey('editButton_$_isReadMode'),
                                      heroTag: null,
                                      onPressed: _toggleReadMode,
                                      elevation: 4,
                                      child: Icon(
                                        _isReadMode
                                            ? Icons.edit_rounded
                                            : Icons.visibility_rounded,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class DurationEstimator extends StatefulWidget {
  final String content;
  final TextEditingController controller;

  const DurationEstimator({
    super.key,
    required this.content,
    required this.controller,
  });

  @override
  State<DurationEstimator> createState() => _DurationEstimatorState();
}

class _DurationEstimatorState extends State<DurationEstimator> {
  Timer? _debounceTimer;
  String _duration = "00:00";
  StreamSubscription<double>? _wordsPerSecondSubscription;

  @override
  void initState() {
    super.initState();
    _calculateDuration();
    widget.controller.addListener(_onTextChanged);
    _wordsPerSecondSubscription = EditorSettingsEvents.wordsPerSecondStream
        .listen((wps) {
          if (mounted) {
            _calculateDuration();
          }
        });
  }

  void _onTextChanged() {
    _calculateDuration();

    if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();
    _debounceTimer = Timer(
      const Duration(milliseconds: 500),
      _calculateDuration,
    );
  }

  void _calculateDuration() {
    final newDuration = ScriptModeHandler.calculateEstimatedTime(
      widget.controller.text,
    );

    if (mounted && newDuration != _duration) {
      setState(() => _duration = newDuration);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    widget.controller.removeListener(_onTextChanged);
    _wordsPerSecondSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            _duration,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontFeatures: [const FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
