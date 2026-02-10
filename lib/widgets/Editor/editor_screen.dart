import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import '../../scriptmode_handler.dart';
import '../../Settings/editor_settings_panel.dart';
import '../../animations/animations_handler.dart';
import '../../database/models/note.dart';
import '../../database/models/notebook.dart';
import '../../database/database_helper.dart';
import '../../database/repositories/note_repository.dart';
import '../../shortcuts_handler.dart';
import '../../services/immersive_mode_service.dart';
import '../../services/export_service.dart';
import '../find_bar.dart';
import '../context_menu.dart';
import 'unified_text_handler.dart';
import 'list_continuation_handler.dart';
import 'list_handler.dart';
import 'search_handler.dart';
import 'editor_tool_bar.dart';
import 'format_handler.dart';
import '../../services/tab_manager.dart';
import 'note_statistics_dialog.dart';
import '../custom_tooltip.dart';
import '../draggable_header.dart';

VoidCallback? _currentActiveEditorToggleReadMode;

VoidCallback? _currentActiveEditorToggleSplitView;

void toggleActiveEditorReadMode() {
  _currentActiveEditorToggleReadMode?.call();
}

void toggleActiveEditorSplitView() {
  _currentActiveEditorToggleSplitView?.call();
}

class NotaEditor extends StatefulWidget {
  final Note selectedNote;
  final SearchTextEditingController noteController;
  final TextEditingController titleController;
  final VoidCallback onSave;
  final VoidCallback onTitleChanged;
  final VoidCallback onContentChanged;
  final String? searchQuery;
  final bool isAdvancedSearch;
  final VoidCallback? onAutoSaveCompleted;
  final TabManager? tabManager;
  final bool initialReadMode;
  final ValueChanged<bool>? onReadModeChanged;
  final bool initialEditorCentered;
  final ValueChanged<bool>? onEditorCenteredChanged;
  final bool initialSplitView;
  final ValueChanged<bool>? onSplitViewChanged;
  final VoidCallback? onNextNote;
  final VoidCallback? onPreviousNote;
  final Function(Notebook)? onNotebookLinkTap;
  final Function(Note, bool)? onNoteLinkTap;

  const NotaEditor({
    super.key,
    required this.selectedNote,
    required this.noteController,
    required this.titleController,
    required this.onSave,
    required this.onTitleChanged,
    required this.onContentChanged,
    this.searchQuery,
    this.isAdvancedSearch = false,
    this.onAutoSaveCompleted,
    this.tabManager,
    this.initialReadMode = false,
    this.onReadModeChanged,
    this.initialEditorCentered = false,
    this.onEditorCenteredChanged,
    this.initialSplitView = false,
    this.onSplitViewChanged,
    this.onNextNote,
    this.onPreviousNote,
    this.onNotebookLinkTap,
    this.onNoteLinkTap,
  });

  @override
  State<NotaEditor> createState() => _NotaEditorState();
}

class _NotaEditorState extends State<NotaEditor>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _isScript = false;
  bool _isReadMode = false;
  bool _isSplitView = false;
  String _splitViewPreviewText = '';
  bool _isEditorCentered = false;
  bool _showFindBar = false;
  bool _isRestoringSearch = false;
  bool _isEditorSettingsLoaded = false;
  Timer? _scriptDetectionDebouncer;
  Timer? _autoSaveDebounce;
  Timer? _splitViewUpdateTimer;
  late SaveAnimationController _saveController;
  final FocusNode _editorFocusNode = FocusNode();
  final FocusNode _findBarFocusNode = FocusNode();
  final TextEditingController _findController = TextEditingController();
  double _fontSize = 16.0;
  double _lineSpacing = 1.0;
  Color? _fontColor;
  bool _useThemeFontColor = true;
  String _fontFamily = 'Roboto';
  bool _isAutoSaveEnabled = true;
  bool _showBottomBar = true;
  double _splitViewUpdateDelay = 500.0;
  StreamSubscription? _fontSizeSubscription;
  StreamSubscription? _lineSpacingSubscription;
  StreamSubscription? _fontColorSubscription;
  StreamSubscription? _fontFamilySubscription;
  StreamSubscription? _autoSaveEnabledSubscription;
  StreamSubscription? _wordsPerSecondSubscription;
  StreamSubscription? _showBottomBarSubscription;
  StreamSubscription? _splitViewUpdateDelaySubscription;
  late ImmersiveModeService _immersiveModeService;
  late SearchManager _searchManager;
  final UndoHistoryController _undoController = UndoHistoryController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _previewScrollController = ScrollController();
  bool _isSyncingScroll = false;
  final GlobalKey _exportButtonKey = GlobalKey();

  TextStyle get _textStyle => GoogleFonts.getFont(
    _fontFamily,
    fontSize: _fontSize,
    height: _lineSpacing,
    color:
        _useThemeFontColor
            ? Theme.of(context).colorScheme.onSurface
            : _fontColor ?? Theme.of(context).colorScheme.onSurface,
  ).copyWith(letterSpacing: 0.0);

  void _highlightSearchText() {
    if (widget.searchQuery == null ||
        widget.searchQuery!.isEmpty ||
        !widget.isAdvancedSearch) {
      return;
    }

    final text = widget.noteController.text;
    final lowerText = text.toLowerCase();
    final lowerQuery = widget.searchQuery!.toLowerCase();
    final queryIndex = lowerText.indexOf(lowerQuery);

    if (queryIndex != -1) {
      widget.noteController.selection = TextSelection(
        baseOffset: queryIndex,
        extentOffset: queryIndex + widget.searchQuery!.length,
      );

      Timer(const Duration(milliseconds: 100), () {
        if (mounted) {
          widget.noteController.selection = TextSelection(
            baseOffset: queryIndex,
            extentOffset: queryIndex + widget.searchQuery!.length,
          );

          _editorFocusNode.requestFocus();
        }
      });

      Timer(const Duration(milliseconds: 500), () {
        if (mounted) {
          widget.noteController.selection = TextSelection(
            baseOffset: queryIndex,
            extentOffset: queryIndex + widget.searchQuery!.length,
          );
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _saveController = SaveAnimationController(vsync: this);
    widget.noteController.addListener(_onContentChanged);
    widget.titleController.addListener(_onTitleChanged);
    _scrollController.addListener(
      () => _syncScroll(_scrollController, _previewScrollController),
    );
    _previewScrollController.addListener(
      () => _syncScroll(_previewScrollController, _scrollController),
    );
    _findController.addListener(() {
      if (_isRestoringSearch) return;
      final query = _findController.text;
      _searchManager.performFind(query, () {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {});

              final activeTab = widget.tabManager?.activeTab;
              if (activeTab != null) {
                widget.tabManager!.setTabSearchQuery(
                  activeTab,
                  query,
                  isAdvanced: widget.isAdvancedSearch,
                );
              }
            }
          });
        }
      });
    });
    _detectScriptMode();
    _setupSettingsListeners();
    _initializeImmersiveMode();

    _isReadMode = widget.initialReadMode;

    _isSplitView = widget.initialSplitView;
    _splitViewPreviewText = widget.noteController.text;

    _isEditorCentered = widget.initialEditorCentered;

    _currentActiveEditorToggleReadMode = _toggleReadMode;
    _currentActiveEditorToggleSplitView = _toggleSplitView;

    _searchManager = SearchManager(
      noteController: widget.noteController,
      scrollController: _scrollController,
      textStyle: GoogleFonts.getFont(
        _fontFamily,
        fontSize: _fontSize,
        height: _lineSpacing,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeEditorSettings();
      _highlightSearchText();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _refreshEditorSettings();
    }
  }

  @override
  void didUpdateWidget(NotaEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    final noteChanged = oldWidget.selectedNote.id != widget.selectedNote.id;
    final findBarHadFocus = _findBarFocusNode.hasFocus;

    if (noteChanged) {
      _reconfigureListeners(oldWidget);
      _detectScriptMode();
      _splitViewUpdateTimer?.cancel();

      _searchManager.updateControllers(
        newNoteController: widget.noteController,
        newScrollController: _scrollController,
      );

      if (widget.initialReadMode != oldWidget.initialReadMode || noteChanged) {
        setState(() {
          _isReadMode = widget.initialReadMode;
          if (_isReadMode) {
            _isSplitView = false;
            widget.onSplitViewChanged?.call(false);
          }
        });
      }

      if (widget.initialSplitView != oldWidget.initialSplitView ||
          noteChanged) {
        setState(() {
          _isSplitView = widget.initialSplitView;
          _splitViewPreviewText = widget.noteController.text;
        });
      }

      if (_isSplitView && noteChanged) {
        setState(() {
          _splitViewPreviewText = widget.noteController.text;
        });
      }

      if (_showFindBar) {
        final newQuery = widget.searchQuery ?? '';
        _isRestoringSearch = true;
        _findController.text = newQuery;
        _isRestoringSearch = false;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _showFindBar) {
            _searchManager.performFind(_findController.text, () {
              if (mounted) setState(() {});
            });

            if (findBarHadFocus) {
              _findBarFocusNode.requestFocus();
            }
          }
        });
      }
    }

    if (widget.initialEditorCentered != oldWidget.initialEditorCentered) {
      setState(() {
        _isEditorCentered = widget.initialEditorCentered;
      });
    }

    if (widget.initialReadMode != oldWidget.initialReadMode) {
      setState(() {
        _isReadMode = widget.initialReadMode;
        if (_isReadMode && _isSplitView) {
          _isSplitView = false;
          widget.onSplitViewChanged?.call(false);
        }
      });
    }

    if (widget.initialSplitView != oldWidget.initialSplitView) {
      setState(() {
        _isSplitView = widget.initialSplitView;
        _splitViewPreviewText = widget.noteController.text;
      });
    }

    if (oldWidget.searchQuery != widget.searchQuery ||
        oldWidget.isAdvancedSearch != widget.isAdvancedSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _highlightSearchText();
      });
    }

    if (!_isEditorSettingsLoaded) {
      _loadEditorSettings();
    }

    _refreshEditorSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.noteController.removeListener(_onContentChanged);
    widget.titleController.removeListener(_onTitleChanged);
    _scriptDetectionDebouncer?.cancel();
    _autoSaveDebounce?.cancel();
    _saveController.dispose();
    _undoController.dispose();
    _editorFocusNode.dispose();
    _findBarFocusNode.dispose();
    _findController.dispose();
    _splitViewUpdateTimer?.cancel();
    _fontSizeSubscription?.cancel();
    _lineSpacingSubscription?.cancel();
    _fontColorSubscription?.cancel();
    _fontFamilySubscription?.cancel();
    _autoSaveEnabledSubscription?.cancel();
    _wordsPerSecondSubscription?.cancel();
    _showBottomBarSubscription?.cancel();
    _splitViewUpdateDelaySubscription?.cancel();
    _immersiveModeService.removeListener(_onImmersiveModeChanged);
    _scrollController.dispose();
    _previewScrollController.dispose();

    if (_currentActiveEditorToggleReadMode == _toggleReadMode) {
      _currentActiveEditorToggleReadMode = null;
    }
    if (_currentActiveEditorToggleSplitView == _toggleSplitView) {
      _currentActiveEditorToggleSplitView = null;
    }

    super.dispose();
  }

  void _syncScroll(ScrollController source, ScrollController destination) {
    if (!_isSplitView || _isSyncingScroll) return;
    if (!source.hasClients || !destination.hasClients) return;

    _isSyncingScroll = true;
    destination.jumpTo(
      source.offset.clamp(0.0, destination.position.maxScrollExtent),
    );
    _isSyncingScroll = false;
  }

  void _scrollToCursor() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      final controller = widget.noteController;
      final selection = controller.selection;
      if (!selection.isValid) return;

      final text = controller.text;
      final offset = selection.baseOffset;

      final textBeforeCursor = text.substring(0, offset);
      final lines = textBeforeCursor.split('\n');
      final lineNumber = lines.length - 1;

      final effectiveLineHeight =
          _fontSize * (_lineSpacing > 0 ? _lineSpacing : 1.2);
      final targetPosition = lineNumber * effectiveLineHeight;

      final currentScroll = _scrollController.offset;
      final viewportHeight = _scrollController.position.viewportDimension;
      final maxScroll = _scrollController.position.maxScrollExtent;

      if (offset >= text.length - 10) {
        if (currentScroll < maxScroll) {
          _scrollController.animateTo(
            maxScroll,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
          );
        }
        return;
      }

      if (targetPosition + (effectiveLineHeight * 2) >
          currentScroll + viewportHeight) {
        final newScrollPos = (targetPosition -
                viewportHeight +
                (effectiveLineHeight * 3))
            .clamp(0.0, maxScroll);
        _scrollController.animateTo(
          newScrollPos,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      } else if (targetPosition < currentScroll) {
        _scrollController.animateTo(
          targetPosition.clamp(0.0, maxScroll),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onTitleChanged() {
    widget.onTitleChanged();

    if (_isAutoSaveEnabled) {
      _autoSaveDebounce?.cancel();
      _autoSaveDebounce = Timer(const Duration(milliseconds: 1000), () {
        if (mounted && _isAutoSaveEnabled) {
          _performSilentAutoSave();
        }
      });
    }
  }

  void _updateControllerAndSplitView(
    String newText, {
    TextSelection? selection,
  }) {
    if (_isSplitView) {
      setState(() {
        _splitViewPreviewText = newText;
      });
    }

    if (selection != null) {
      widget.noteController.value = widget.noteController.value.copyWith(
        text: newText,
        selection: selection,
      );
    } else {
      widget.noteController.text = newText;
    }
  }

  void _onContentChanged() {
    widget.onContentChanged();

    _scriptDetectionDebouncer?.cancel();
    _scriptDetectionDebouncer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _isScript = ScriptModeHandlerDesktop.isScript(
            widget.noteController.text,
          );
        });
      }
    });

    if (_isSplitView) {
      if (_splitViewPreviewText == widget.noteController.text) {
        _splitViewUpdateTimer?.cancel();
      } else {
        _splitViewUpdateTimer?.cancel();
        _splitViewUpdateTimer = Timer(
          Duration(milliseconds: _splitViewUpdateDelay.round()),
          () {
            if (mounted) {
              setState(() {
                _splitViewPreviewText = widget.noteController.text;
              });
            }
          },
        );
      }
    }

    if (_isAutoSaveEnabled) {
      _autoSaveDebounce?.cancel();
      _autoSaveDebounce = Timer(const Duration(milliseconds: 1000), () {
        if (mounted && _isAutoSaveEnabled) {
          _performSilentAutoSave();
        }
      });
    }
  }

  void _detectScriptMode() {
    setState(() {
      _isScript = ScriptModeHandlerDesktop.isScript(widget.noteController.text);
    });
  }

  void _reconfigureListeners(NotaEditor oldWidget) {
    try {
      oldWidget.noteController.removeListener(_onContentChanged);
      oldWidget.titleController.removeListener(_onTitleChanged);
    } catch (e) {
      // Ignore errors when removing listeners
    }

    widget.noteController.addListener(_onContentChanged);
    widget.titleController.addListener(_onTitleChanged);
  }

  void _toggleReadMode() {
    bool splitViewChanged = false;
    setState(() {
      _isReadMode = !_isReadMode;
      if (_isReadMode && _isSplitView) {
        _isSplitView = false;
        splitViewChanged = true;
      }
    });

    widget.onReadModeChanged?.call(_isReadMode);
    if (splitViewChanged) {
      widget.onSplitViewChanged?.call(false);
    }

    if (_isReadMode && _showFindBar) {
      _hideFindBar();
    }
  }

  void _toggleSplitView() {
    bool readModeChanged = false;
    setState(() {
      _isSplitView = !_isSplitView;
      if (_isSplitView) {
        if (_isReadMode) {
          _isReadMode = false;
          readModeChanged = true;
        }
        _splitViewPreviewText = widget.noteController.text;
      }
    });

    if (readModeChanged) {
      widget.onReadModeChanged?.call(false);
    }

    widget.onSplitViewChanged?.call(_isSplitView);
  }

  void _toggleEditorCentered() {
    setState(() {
      _isEditorCentered = !_isEditorCentered;
    });

    widget.onEditorCenteredChanged?.call(_isEditorCentered);
  }

  Future<void> _handleSave({bool isAutoSave = false}) async {
    if (!mounted) return;

    final bool hadFocus = _editorFocusNode.hasFocus;
    final TextSelection currentSelection = widget.noteController.selection;
    final int? originalNoteId = widget.selectedNote.id;

    if (isAutoSave) {
      try {
        await _performAutoSave();
      } catch (e) {
        print('Error in auto-save: $e');
      }
      return;
    }

    try {
      if (!mounted) return;

      _saveController.start();

      await _performBackgroundSave();

      await _saveController.complete();

      if (hadFocus && !_editorFocusNode.hasFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              originalNoteId != null &&
              widget.selectedNote.id == originalNoteId) {
            _editorFocusNode.requestFocus();
            final textLength = widget.noteController.text.length;
            if (currentSelection.start <= textLength &&
                currentSelection.end <= textLength) {
              widget.noteController.selection = currentSelection;
            }
          }
        });
      }
    } catch (e) {
      print('Error in _handleSave: $e');
      if (mounted) {
        _saveController.reset();

        if (hadFocus &&
            originalNoteId != null &&
            widget.selectedNote.id == originalNoteId) {
          _editorFocusNode.requestFocus();
          final textLength = widget.noteController.text.length;
          if (currentSelection.start <= textLength &&
              currentSelection.end <= textLength) {
            widget.noteController.selection = currentSelection;
          }
        }
      }
      rethrow;
    }
  }

  Future<void> _performAutoSave() async {
    if (!mounted) return;

    try {
      final dbHelper = DatabaseHelper();
      final noteRepository = NoteRepository(dbHelper);

      await noteRepository.updateNoteTitleAndContent(
        widget.selectedNote.id!,
        widget.titleController.text.trim(),
        widget.noteController.text,
      );

      DatabaseHelper.notifyDatabaseChanged();

      final updatedNote = widget.selectedNote.copyWith(
        title: widget.titleController.text.trim(),
        content: widget.noteController.text,
        updatedAt: DateTime.now(),
      );
      _updateTabStateAfterAutoSave(updatedNote);
    } catch (e) {
      print('Error in auto-save: $e');
      rethrow;
    }
  }

  Future<void> _performBackgroundSave() async {
    if (!mounted) return;

    try {
      await _performAutoSave();
    } catch (e) {
      print('Error in background save: $e');
      rethrow;
    }
  }

  void _performSilentAutoSave() async {
    if (!mounted) return;

    try {
      await _performAutoSave();
    } catch (e) {
      print('Error in silent auto-save: $e');
    }
  }

  void _updateTabStateAfterAutoSave(Note updatedNote) {
    if (widget.onAutoSaveCompleted != null) {
      scheduleMicrotask(() {
        if (mounted) {
          widget.onAutoSaveCompleted!();
        }
      });
    }
  }

  void _setupSettingsListeners() {
    _fontSizeSubscription?.cancel();
    _lineSpacingSubscription?.cancel();
    _fontColorSubscription?.cancel();
    _fontFamilySubscription?.cancel();
    _autoSaveEnabledSubscription?.cancel();
    _showBottomBarSubscription?.cancel();
    _splitViewUpdateDelaySubscription?.cancel();

    _wordsPerSecondSubscription = EditorSettingsEvents.wordsPerSecondStream
        .listen((wps) {
          if (mounted) {
            setState(() {});
          }
        });

    _splitViewUpdateDelaySubscription = EditorSettingsEvents
        .splitViewUpdateDelayStream
        .listen((delay) {
          if (mounted) {
            setState(() {
              _splitViewUpdateDelay = delay;
            });
          }
        });

    _fontSizeSubscription = EditorSettingsEvents.fontSizeStream.listen((size) {
      if (mounted) {
        setState(() {
          _fontSize = size;
        });
      }
    });

    _lineSpacingSubscription = EditorSettingsEvents.lineSpacingStream.listen((
      spacing,
    ) {
      if (mounted) {
        setState(() {
          _lineSpacing = spacing;
        });
      }
    });

    _fontColorSubscription = EditorSettingsEvents.fontColorStream.listen((
      color,
    ) {
      if (mounted) {
        setState(() {
          _fontColor = color;
          _useThemeFontColor = color == null;
        });
      }
    });

    _fontFamilySubscription = EditorSettingsEvents.fontFamilyStream.listen((
      family,
    ) {
      if (mounted) {
        setState(() {
          _fontFamily = family;
        });
      }
    });

    _autoSaveEnabledSubscription = EditorSettingsEvents.autoSaveEnabledStream
        .listen((isEnabled) {
          if (mounted) {
            setState(() {
              _isAutoSaveEnabled = isEnabled;
            });
          }
        });

    _showBottomBarSubscription = EditorSettingsEvents.showBottomBarStream
        .listen((show) {
          if (mounted) {
            setState(() {
              _showBottomBar = show;
            });
          }
        });
  }

  void _handleCreateScriptBlock() {
    final selection = widget.noteController.selection;
    if (selection.isValid && !selection.isCollapsed) {
      final text = widget.noteController.text;
      final selectedText = text.substring(selection.start, selection.end);

      ScriptModeHandlerDesktop.parseScript(text);
      final lines = text.split('\n');

      int currentPosition = 0;
      int selectionLineIndex = 0;
      List<int> blockNumbers = [];
      int? previousBlockNumber;
      int? nextBlockNumber;

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];

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
        currentPosition += line.length + 1;
      }

      int newBlockNumber;
      if (previousBlockNumber != null && nextBlockNumber != null) {
        newBlockNumber = previousBlockNumber + 1;
      } else if (previousBlockNumber != null) {
        newBlockNumber = previousBlockNumber + 1;
      } else if (nextBlockNumber != null) {
        newBlockNumber = 1;
      } else {
        newBlockNumber = 1;
      }

      final updatedLines = List<String>.from(lines);
      int currentNumber = newBlockNumber + 1;

      for (int i = 0; i < updatedLines.length; i++) {
        final line = updatedLines[i];
        if (i > selectionLineIndex) {
          updatedLines[i] = line.replaceAllMapped(
            RegExp(r'#\d+'),
            (match) => '#$currentNumber',
          );
          if (line.contains(RegExp(r'#\d+'))) {
            currentNumber++;
          }
        }
      }

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

      final newText = updatedLines
          .join('\n')
          .replaceRange(
            selection.start,
            selection.end,
            '${needsNewlineBefore ? '\n' : ''}#$newBlockNumber\n$selectedText${needsNewlineAfter ? '\n' : ''}',
          );

      widget.noteController.text = newText;

      final selectionOffset = needsNewlineBefore ? 1 : 0;
      widget.noteController.selection = TextSelection(
        baseOffset: selection.start + selectionOffset,
        extentOffset:
            selection.start +
            selectionOffset +
            '#$newBlockNumber\n'.length +
            selectedText.length +
            (needsNewlineAfter ? 1 : 0),
      );

      widget.onContentChanged();
    }
  }

  bool _isLineLevelFormat(FormatType type) {
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

  void _toggleLineFormat(FormatType type) {
    final controller = widget.noteController;
    final selection = controller.selection;
    final text = controller.text;
    final cursorPosition = selection.baseOffset;

    int lineStart =
        cursorPosition > 0 ? text.lastIndexOf('\n', cursorPosition - 1) + 1 : 0;
    int lineEnd = text.indexOf('\n', cursorPosition);
    if (lineEnd == -1) lineEnd = text.length;

    final currentLine = text.substring(lineStart, lineEnd);

    final whitespaceMatch = RegExp(r'^(\s*)').firstMatch(currentLine);
    final leadingWhitespace = whitespaceMatch?.group(1) ?? '';
    final lineWithoutWhitespace = currentLine.substring(
      leadingWhitespace.length,
    );

    String prefix = '';
    bool isList = false;
    ListType? targetListType;

    switch (type) {
      case FormatType.heading1:
        prefix = '# ';
        break;
      case FormatType.heading2:
        prefix = '## ';
        break;
      case FormatType.heading3:
        prefix = '### ';
        break;
      case FormatType.heading4:
        prefix = '#### ';
        break;
      case FormatType.heading5:
        prefix = '##### ';
        break;
      case FormatType.numbered:
        prefix = '1. ';
        isList = true;
        targetListType = ListType.numbered;
        break;
      case FormatType.bullet:
        prefix = '- ';
        isList = true;
        targetListType = ListType.bullet;
        break;
      case FormatType.checkboxUnchecked:
        prefix = '-[ ] ';
        isList = true;
        targetListType = ListType.checkbox;
        break;
      case FormatType.checkboxChecked:
        prefix = '-[x] ';
        isList = true;
        targetListType = ListType.checkbox;
        break;
      default:
        return;
    }

    String newLine;
    int newCursorOffset;

    if (isList) {
      final listItem = ListDetector.detectListItem(currentLine);
      if (listItem != null) {
        if (listItem.type == targetListType) {
          newLine = leadingWhitespace + listItem.content;

          int removedChars = currentLine.length - newLine.length;
          newCursorOffset = cursorPosition - removedChars;
        } else {
          newLine = leadingWhitespace + prefix + listItem.content;

          int oldPrefixLength =
              currentLine.length -
              leadingWhitespace.length -
              listItem.content.length;
          newCursorOffset = cursorPosition + (prefix.length - oldPrefixLength);
        }
      } else {
        newLine = leadingWhitespace + prefix + lineWithoutWhitespace;
        newCursorOffset = cursorPosition + prefix.length;
      }
    } else {
      final headingMatch = RegExp(
        r'^(#+)\s+(.*)$',
      ).firstMatch(lineWithoutWhitespace);
      if (headingMatch != null) {
        final currentPrefix = '${headingMatch.group(1)!} ';
        if (currentPrefix.trim() == prefix.trim()) {
          newLine = leadingWhitespace + headingMatch.group(2)!;
          newCursorOffset = cursorPosition - currentPrefix.length;
        } else {
          newLine = leadingWhitespace + prefix + headingMatch.group(2)!;
          newCursorOffset =
              cursorPosition + (prefix.length - currentPrefix.length);
        }
      } else {
        newLine = leadingWhitespace + prefix + lineWithoutWhitespace;
        newCursorOffset = cursorPosition + prefix.length;
      }
    }

    final newText =
        text.substring(0, lineStart) + newLine + text.substring(lineEnd);
    _updateControllerAndSplitView(
      newText,
      selection: TextSelection.collapsed(
        offset: newCursorOffset.clamp(lineStart, lineStart + newLine.length),
      ),
    );
    widget.onContentChanged();
    _editorFocusNode.requestFocus();
  }

  void _handleFormat(FormatType type) {
    final selection = widget.noteController.selection;
    if (!selection.isValid) return;

    if (type == FormatType.insertScript) {
      final text = widget.noteController.text;
      if (text.startsWith('#script')) {
        String newText = text.replaceFirst(RegExp(r'^#script\n?'), '');
        _updateControllerAndSplitView(newText);
        widget.onContentChanged();
      } else {
        _updateControllerAndSplitView('#script\n$text');
        widget.onContentChanged();
      }
      _editorFocusNode.requestFocus();
      return;
    }

    if (type == FormatType.convertToScript) {
      _handleCreateScriptBlock();
      return;
    }

    if (!selection.isCollapsed) {
      final text = widget.noteController.text;
      final newText = FormatUtils.toggleFormat(
        text,
        selection.start,
        selection.end,
        type,
      );

      if (newText != text) {
        _updateControllerAndSplitView(
          newText,
          selection: TextSelection(
            baseOffset: selection.start,
            extentOffset:
                selection.start +
                (newText.length -
                    (text.length - (selection.end - selection.start))),
          ),
        );
        widget.onContentChanged();
      }

      _editorFocusNode.requestFocus();
    } else {
      if (_isLineLevelFormat(type)) {
        _toggleLineFormat(type);
        return;
      }

      final text = widget.noteController.text;
      final start = selection.start;
      String prefix = '';
      String suffix = '';
      int cursorOffset = 0;

      switch (type) {
        case FormatType.bold:
          prefix = '**';
          suffix = '**';
          cursorOffset = 2;
          break;
        case FormatType.italic:
          prefix = '*';
          suffix = '*';
          cursorOffset = 1;
          break;
        case FormatType.strikethrough:
          prefix = '~~';
          suffix = '~~';
          cursorOffset = 2;
          break;
        case FormatType.code:
          prefix = '`';
          suffix = '`';
          cursorOffset = 1;
          break;
        case FormatType.taggedCode:
          prefix = '[';
          suffix = ']';
          cursorOffset = 1;
          break;
        case FormatType.heading1:
          prefix = '# ';
          cursorOffset = 2;
          break;
        case FormatType.heading2:
          prefix = '## ';
          cursorOffset = 3;
          break;
        case FormatType.heading3:
          prefix = '### ';
          cursorOffset = 4;
          break;
        case FormatType.heading4:
          prefix = '#### ';
          cursorOffset = 5;
          break;
        case FormatType.heading5:
          prefix = '##### ';
          cursorOffset = 6;
          break;
        case FormatType.numbered:
          prefix = '1. ';
          cursorOffset = 3;
          break;
        case FormatType.bullet:
          prefix = '- ';
          cursorOffset = 2;
          break;
        case FormatType.checkboxUnchecked:
          prefix = '-[ ] ';
          cursorOffset = 5;
          break;
        case FormatType.checkboxChecked:
          prefix = '-[x] ';
          cursorOffset = 5;
          break;
        case FormatType.noteLink:
          prefix = '[[note:';
          suffix = ']]';
          cursorOffset = 7;
          break;
        case FormatType.notebookLink:
          prefix = '[[notebook:';
          suffix = ']]';
          cursorOffset = 11;
          break;
        case FormatType.link:
          prefix = '[';
          suffix = ']()';
          cursorOffset = 1;
          break;
        case FormatType.horizontalRule:
          final currentText = widget.noteController.text;
          String insertText;
          int newCursorOffset;

          if (start == 0 || currentText[start - 1] == '\n') {
            insertText = '* * *\n';
            newCursorOffset = 6;
          } else {
            insertText = '\n* * *\n';
            newCursorOffset = 7;
          }

          final hrNewText =
              currentText.substring(0, start) +
              insertText +
              currentText.substring(start);
          widget.noteController.text = hrNewText;
          widget.noteController.selection = TextSelection.collapsed(
            offset: start + newCursorOffset,
          );
          widget.onContentChanged();
          _editorFocusNode.requestFocus();
          return;
        default:
          return;
      }

      final newText =
          text.substring(0, start) + prefix + suffix + text.substring(start);
      widget.noteController.text = newText;
      widget.noteController.selection = TextSelection.collapsed(
        offset: start + cursorOffset,
      );
      widget.onContentChanged();

      _editorFocusNode.requestFocus();
    }
  }

  void _handleFindInEditor() {
    if (_isReadMode) return;

    setState(() {
      _showFindBar = true;
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _findBarFocusNode.requestFocus();
      }
    });
  }

  void _hideFindBar() {
    _searchManager.clear(() {
      if (mounted) {
        setState(() {
          _showFindBar = false;
        });

        final activeTab = widget.tabManager?.activeTab;
        if (activeTab != null) {
          widget.tabManager!.setTabSearchQuery(activeTab, null);
        }
      }
    });
    _findController.clear();
    _editorFocusNode.requestFocus();
  }

  void _nextMatch() {
    _searchManager.nextMatch(() {
      if (mounted) setState(() {});
    });

    _findBarFocusNode.requestFocus();
  }

  void _previousMatch() {
    _searchManager.previousMatch(() {
      if (mounted) setState(() {});
    });

    _findBarFocusNode.requestFocus();
  }

  void _initializeImmersiveMode() {
    _immersiveModeService = ImmersiveModeService();
    _immersiveModeService.addListener(_onImmersiveModeChanged);
  }

  void _onImmersiveModeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _initializeEditorSettings() async {
    final cache = EditorSettingsCache.instance;

    if (!cache.isInitialized) {
      await cache.initialize();
    }

    if (mounted) {
      setState(() {
        _fontSize = cache.fontSize;
        _lineSpacing = cache.lineSpacing;
        _useThemeFontColor = cache.useThemeFontColor;
        _fontColor = cache.useThemeFontColor ? null : cache.fontColor;
        _fontFamily = cache.fontFamily;
        _isAutoSaveEnabled = cache.isAutoSaveEnabled;
        _showBottomBar = cache.showBottomBar;
      });
      _isEditorSettingsLoaded = true;
    }
  }

  void _loadEditorSettings() {
    final cache = EditorSettingsCache.instance;
    setState(() {
      _fontSize = cache.fontSize;
      _lineSpacing = cache.lineSpacing;
      _useThemeFontColor = cache.useThemeFontColor;
      _fontColor = cache.useThemeFontColor ? null : cache.fontColor;
      _fontFamily = cache.fontFamily;
      _isAutoSaveEnabled = cache.isAutoSaveEnabled;
      _showBottomBar = cache.showBottomBar;
      _splitViewUpdateDelay = cache.splitViewUpdateDelay;
    });
    _isEditorSettingsLoaded = true;
  }

  void _refreshEditorSettings() {
    final cache = EditorSettingsCache.instance;
    if (cache.isInitialized) {
      setState(() {
        _fontSize = cache.fontSize;
        _lineSpacing = cache.lineSpacing;
        _useThemeFontColor = cache.useThemeFontColor;
        _fontColor = cache.useThemeFontColor ? null : cache.fontColor;
        _fontFamily = cache.fontFamily;
        _isAutoSaveEnabled = cache.isAutoSaveEnabled;
        _showBottomBar = cache.showBottomBar;
        _splitViewUpdateDelay = cache.splitViewUpdateDelay;
      });
    }
  }

  void _showExportMenu() {
    final title =
        widget.titleController.text.trim().isEmpty
            ? 'Untitled Note'
            : widget.titleController.text.trim();
    final content = widget.noteController.text;

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
                  note: widget.selectedNote.copyWith(
                    title: widget.titleController.text,
                    content: widget.noteController.text,
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshEditorSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        ...ShortcutsHandler.getEditorShortcuts(
          onCreateScriptBlock: _handleCreateScriptBlock,
          onFindInEditor: _handleFindInEditor,
        ),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS):
            const SaveIntent(),
      },
      child: Actions(
        actions: {
          SaveIntent: CallbackAction<SaveIntent>(
            onInvoke: (_) {
              _handleSave();
              return null;
            },
          ),
          CreateScriptBlockIntent: CallbackAction<CreateScriptBlockIntent>(
            onInvoke: (_) => _handleCreateScriptBlock(),
          ),
          FindInEditorIntent: CallbackAction<FindInEditorIntent>(
            onInvoke: (_) => _handleFindInEditor(),
          ),
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            _searchManager.updateTextStyle(_textStyle);

            return Focus(
              onKeyEvent: (node, event) {
                if (_showFindBar) {
                  if (event is KeyDownEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.enter) {
                      if (HardwareKeyboard.instance.isShiftPressed) {
                        _previousMatch();
                      } else {
                        _nextMatch();
                      }
                      return KeyEventResult.handled;
                    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                      _hideFindBar();
                      return KeyEventResult.handled;
                    }
                  }
                  return KeyEventResult.ignored;
                }

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
                }

                return KeyEventResult.ignored;
              },
              child: Column(
                children: [
                  if (_immersiveModeService.isImmersiveMode &&
                      !Platform.isLinux &&
                      EditorSettingsCache.instance.hideTabsInImmersive)
                    const DraggableArea(height: 40),

                  Container(
                    padding: EdgeInsets.only(
                      left:
                          !_isSplitView &&
                                  _isEditorCentered &&
                                  constraints.maxWidth >= 600
                              ? _calculateCenteredPaddingForEditor(
                                constraints.maxWidth,
                              )
                              : 0,
                      right:
                          !_isSplitView &&
                                  _isEditorCentered &&
                                  constraints.maxWidth >= 600
                              ? _calculateCenteredPaddingForEditor(
                                constraints.maxWidth,
                              )
                              : 0,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        height: 44.0,
                        alignment: Alignment.center,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Focus(
                                onKeyEvent: (node, event) {
                                  if (event is KeyDownEvent) {
                                    if (event.logicalKey ==
                                            LogicalKeyboardKey.keyT &&
                                        HardwareKeyboard
                                            .instance
                                            .isControlPressed) {
                                      return KeyEventResult.ignored;
                                    }
                                    if (event.logicalKey ==
                                            LogicalKeyboardKey.keyN &&
                                        HardwareKeyboard
                                            .instance
                                            .isControlPressed) {
                                      return KeyEventResult.ignored;
                                    }
                                    if (event.logicalKey ==
                                            LogicalKeyboardKey.keyW &&
                                        HardwareKeyboard
                                            .instance
                                            .isControlPressed) {
                                      return KeyEventResult.ignored;
                                    }
                                    if (event.logicalKey ==
                                        LogicalKeyboardKey.tab) {
                                      if (!_isReadMode) {
                                        _editorFocusNode.requestFocus();
                                        widget.noteController.selection =
                                            const TextSelection.collapsed(
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
                                  controller: widget.titleController,
                                  decoration: const InputDecoration(
                                    hintText: 'Title',
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.only(
                                      top: 10,
                                      bottom: 10,
                                    ),
                                    isDense: true,
                                  ),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(height: 1.2),
                                  onChanged: (_) => widget.onTitleChanged(),
                                  readOnly: _isReadMode,
                                  maxLines: 1,
                                  textAlignVertical: TextAlignVertical.center,
                                  onSubmitted: (_) {
                                    if (!_isReadMode) {
                                      _editorFocusNode.requestFocus();
                                      widget.noteController.selection =
                                          const TextSelection.collapsed(
                                            offset: 0,
                                          );
                                    }
                                  },
                                ),
                              ),
                            ),
                            if (_isScript)
                              Padding(
                                padding: const EdgeInsets.only(left: 16.0),
                                child: DurationEstimatorDesktop(
                                  content: widget.noteController.text,
                                ),
                              ),
                            CustomTooltip(
                              message: 'Save note',
                              builder:
                                  (context, isHovering) => SaveButton(
                                    controller: _saveController,
                                    onPressed: () {
                                      _handleSave();
                                    },
                                  ),
                            ),
                            CustomTooltip(
                              message:
                                  _isReadMode
                                      ? 'Edit mode (Ctrl+P)'
                                      : 'Read mode (Ctrl+P)',
                              builder:
                                  (context, isHovering) => IconButton(
                                    icon: Icon(
                                      _isReadMode
                                          ? Icons.edit_rounded
                                          : Icons.visibility_rounded,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                    onPressed: _toggleReadMode,
                                  ),
                            ),
                            CustomTooltip(
                              message: 'Split view (Ctrl+Shift+P)',
                              builder:
                                  (context, isHovering) => IconButton(
                                    icon: Icon(
                                      _isSplitView
                                          ? Symbols.split_scene_right_rounded
                                          : Symbols.split_scene_rounded,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                    onPressed: _toggleSplitView,
                                  ),
                            ),
                            CustomTooltip(
                              message:
                                  _isEditorCentered
                                      ? 'Disable centered layout (F1)'
                                      : 'Enable centered layout (F1)',
                              builder:
                                  (context, isHovering) => IconButton(
                                    icon: Icon(
                                      _isEditorCentered
                                          ? Icons.format_align_justify_rounded
                                          : Icons.format_align_center_rounded,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                    onPressed: _toggleEditorCentered,
                                  ),
                            ),
                            CustomTooltip(
                              message:
                                  _showBottomBar
                                      ? 'Hide formatting bar'
                                      : 'Show formatting bar',
                              builder:
                                  (context, isHovering) => IconButton(
                                    icon: Icon(
                                      _showBottomBar
                                          ? Icons.keyboard_arrow_up_rounded
                                          : Icons.keyboard_arrow_down_rounded,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                    onPressed: () {
                                      EditorSettings.setShowBottomBar(
                                        !_showBottomBar,
                                      );
                                    },
                                  ),
                            ),
                            if (_immersiveModeService.isImmersiveMode)
                              CustomTooltip(
                                message: 'Exit immersive mode (F4)',
                                builder:
                                    (context, isHovering) => IconButton(
                                      icon: Icon(
                                        Icons.fullscreen_exit_rounded,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                      ),
                                      onPressed:
                                          () =>
                                              _immersiveModeService
                                                  .exitImmersiveMode(),
                                    ),
                              ),
                            IconButton(
                              key: _exportButtonKey,
                              icon: Icon(
                                Icons.more_vert_rounded,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              onPressed: _showExportMenu,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_showBottomBar)
                    Container(
                      padding: EdgeInsets.only(
                        left:
                            !_isSplitView &&
                                    _isEditorCentered &&
                                    constraints.maxWidth >= 600
                                ? _calculateCenteredPaddingForEditor(
                                  constraints.maxWidth,
                                )
                                : 0,
                        right:
                            !_isSplitView &&
                                    _isEditorCentered &&
                                    constraints.maxWidth >= 600
                                ? _calculateCenteredPaddingForEditor(
                                  constraints.maxWidth,
                                )
                                : 0,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: EditorBottomBar(
                          onUndo: () {
                            if (_undoController.value.canUndo) {
                              _undoController.undo();
                            }
                          },
                          onRedo: () {
                            if (_undoController.value.canRedo) {
                              _undoController.redo();
                            }
                          },
                          onNextNote: () => widget.onNextNote?.call(),
                          onPreviousNote: () => widget.onPreviousNote?.call(),
                          onFormatTap: _handleFormat,
                          isReadMode: _isReadMode,
                        ),
                      ),
                    ),

                  Expanded(
                    child: Container(
                      padding: EdgeInsets.only(
                        left:
                            !_isSplitView &&
                                    _isEditorCentered &&
                                    constraints.maxWidth >= 600
                                ? _calculateCenteredPaddingForEditor(
                                  constraints.maxWidth,
                                )
                                : 0,
                        right:
                            !_isSplitView &&
                                    _isEditorCentered &&
                                    constraints.maxWidth >= 600
                                ? _calculateCenteredPaddingForEditor(
                                  constraints.maxWidth,
                                )
                                : 0,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Stack(
                          children: [
                            _isReadMode
                                ? _isScript
                                    ? ScriptModeHandlerDesktop.buildScriptPreview(
                                      context,
                                      widget.noteController.text,
                                      textStyle: _textStyle,
                                      onNoteLinkTap: (note, isMiddleClick) {
                                        _handleNoteLinkTap(note, isMiddleClick);
                                      },
                                      onTextChanged: (newText) {
                                        widget.noteController.value = widget
                                            .noteController
                                            .value
                                            .copyWith(
                                              text: newText,
                                              selection:
                                                  widget
                                                      .noteController
                                                      .selection,
                                            );
                                      },
                                      controller: _previewScrollController,
                                    )
                                    : _buildNoteReadPreview(
                                      context,
                                      controller: _previewScrollController,
                                    )
                                : _isSplitView
                                ? Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: _buildHighlightedTextField(),
                                    ),
                                    const SizedBox(width: 16),
                                    VerticalDivider(
                                      width: 1,
                                      thickness: 1,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.outline.withAlpha(128),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child:
                                          _isScript
                                              ? ScriptModeHandlerDesktop.buildScriptPreview(
                                                context,
                                                _splitViewPreviewText,
                                                textStyle: _textStyle,
                                                onNoteLinkTap: (
                                                  note,
                                                  isMiddleClick,
                                                ) {
                                                  _handleNoteLinkTap(
                                                    note,
                                                    isMiddleClick,
                                                  );
                                                },
                                                onTextChanged: (newText) {
                                                  _updateControllerAndSplitView(
                                                    newText,
                                                    selection:
                                                        widget
                                                            .noteController
                                                            .selection,
                                                  );
                                                },
                                                controller:
                                                    _previewScrollController,
                                              )
                                              : _buildNoteReadPreview(
                                                context,
                                                overrideText:
                                                    _splitViewPreviewText,
                                                controller:
                                                    _previewScrollController,
                                              ),
                                    ),
                                  ],
                                )
                                : _buildHighlightedTextField(),

                            if (_showFindBar)
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: FindBar(
                                  textController: _findController,
                                  focusNode: _findBarFocusNode,
                                  onClose: _hideFindBar,
                                  onFind: (query) {
                                    _searchManager.performFind(query, () {
                                      if (mounted) setState(() {});
                                    });
                                  },
                                  onNext: _nextMatch,
                                  onPrevious: _previousMatch,
                                  currentIndex: _searchManager.currentFindIndex,
                                  totalMatches:
                                      _searchManager.findMatches.length,
                                  hasMatches: _searchManager.hasMatches,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  double _calculateCenteredPaddingForEditor(double availableWidth) {
    if (availableWidth < 600) {
      return 0.0;
    } else if (availableWidth < 800) {
      double minEditorWidth = 500.0;
      double maxPadding = (availableWidth - minEditorWidth) / 2;
      return maxPadding.clamp(16.0, 32.0);
    } else if (availableWidth < 1200) {
      double minEditorWidth = 600.0;
      double maxPadding = (availableWidth - minEditorWidth) / 2;

      double proportionalPadding = availableWidth * 0.10;
      return proportionalPadding.clamp(16.0, maxPadding);
    } else {
      double maxEditorWidth = 800.0;
      double padding = (availableWidth - maxEditorWidth) / 2;
      return padding.clamp(100.0, 400.0);
    }
  }

  Widget _buildHighlightedTextField() {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.enter) {
          final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;

          if (ListContinuationHandler.handleEnterKey(
            widget.noteController,
            isShiftPressed,
          )) {
            widget.onContentChanged();
            _scrollToCursor();
            return KeyEventResult.handled;
          }
        }

        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.tab) {
          final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
          final controller = widget.noteController;
          final selection = controller.selection;

          if (selection.isValid && selection.isCollapsed) {
            final text = controller.text;
            final cursorPosition = selection.baseOffset;

            int lineStart = text.lastIndexOf('\n', cursorPosition - 1) + 1;
            if (lineStart < 0) lineStart = 0;
            int lineEnd = text.indexOf('\n', cursorPosition);
            if (lineEnd == -1) lineEnd = text.length;

            final currentLine = text.substring(lineStart, lineEnd);
            final isListItem = ListDetector.detectListItem(currentLine) != null;

            if (isListItem) {
              if (!isShiftPressed) {
                final newText = text.replaceRange(lineStart, lineStart, '\t');
                controller.value = controller.value.copyWith(
                  text: newText,
                  selection: TextSelection.collapsed(
                    offset: cursorPosition + 1,
                  ),
                );
              } else {
                final indentMatch = RegExp(
                  r'^(\t|    )',
                ).firstMatch(currentLine);
                if (indentMatch != null) {
                  final indentLength = indentMatch.group(0)!.length;
                  final newText = text.replaceRange(
                    lineStart,
                    lineStart + indentLength,
                    '',
                  );
                  controller.value = controller.value.copyWith(
                    text: newText,
                    selection: TextSelection.collapsed(
                      offset: (cursorPosition - indentLength).clamp(
                        lineStart,
                        newText.length,
                      ),
                    ),
                  );
                }
              }
              widget.onContentChanged();
              _scrollToCursor();
              return KeyEventResult.handled;
            }
          }

          if (!isShiftPressed) {
            if (selection.isValid) {
              final text = controller.text;
              const tabString = '\t';

              final newText = text.replaceRange(
                selection.start,
                selection.end,
                tabString,
              );
              final newSelection = TextSelection.collapsed(
                offset: selection.start + tabString.length,
              );

              controller.value = controller.value.copyWith(
                text: newText,
                selection: newSelection,
              );
              widget.onContentChanged();
              _scrollToCursor();
            }
          }

          return KeyEventResult.handled;
        }

        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.keyS &&
            HardwareKeyboard.instance.isControlPressed &&
            !HardwareKeyboard.instance.isShiftPressed) {
          _handleSave();
          return KeyEventResult.handled;
        }

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
        }
        return KeyEventResult.ignored;
      },
      child: HighlightedTextField(
        controller: widget.noteController,
        undoController: _undoController,
        focusNode: _editorFocusNode,
        textStyle: _textStyle,
        hintText: 'Start writing...',
        onChanged: widget.onContentChanged,
        scrollController: _scrollController,
        searchManager: _searchManager,
        searchQuery: _findController.text,
      ),
    );
  }

  Widget _buildNoteReadPreview(
    BuildContext context, {
    String? overrideText,
    ScrollController? controller,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final text = overrideText ?? widget.noteController.text;

    final backgroundColor = colorScheme.surfaceContainerLow;

    final content =
        text.isEmpty
            ? Text(
              'No content to display',
              style: _textStyle,
              textAlign: TextAlign.start,
            )
            : UnifiedTextHandler(
              text: text,
              textStyle: _textStyle,
              enableNoteLinkDetection: true,
              enableLinkDetection: true,
              enableListDetection: true,
              enableFormatDetection: true,
              showNoteLinkBrackets: false,
              onNoteLinkTap: (note, isMiddleClick) {
                _handleNoteLinkTap(note, isMiddleClick);
              },
              onNotebookLinkTap: (notebook, isMiddleClick) {
                _handleNotebookLinkTap(notebook, isMiddleClick);
              },
              onTextChanged: (newText) {
                _updateControllerAndSplitView(
                  newText,
                  selection: widget.noteController.selection,
                );
              },
            );

    if (overrideText != null) {
      return SingleChildScrollView(controller: controller, child: content);
    }

    return SingleChildScrollView(
      controller: controller,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(top: 8),
        child: content,
      ),
    );
  }

  void _handleNotebookLinkTap(Notebook notebook, bool isMiddleClick) {
    if (widget.onNotebookLinkTap != null) {
      widget.onNotebookLinkTap!(notebook);
    }
  }

  void _handleNoteLinkTap(Note targetNote, bool openInNewTab) {
    if (widget.onNoteLinkTap != null) {
      widget.onNoteLinkTap!(targetNote, openInNewTab);
      return;
    }

    if (widget.tabManager == null) return;

    if (targetNote.notebookId == -1 || targetNote.id == null) {
      return;
    }

    if (openInNewTab) {
      widget.tabManager!.openTabWithNotebookChange(targetNote);
    } else {
      widget.tabManager!.replaceNoteInActiveTabWithNotebookChange(targetNote);
    }
  }
}

class SaveIntent extends Intent {
  const SaveIntent();
}

class DurationEstimatorDesktop extends StatelessWidget {
  final String content;

  const DurationEstimatorDesktop({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final duration = _calculateDuration();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
            duration,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  String _calculateDuration() {
    if (ScriptModeHandlerDesktop.isScript(content)) {
      final blocks = ScriptModeHandlerDesktop.parseScript(content);
      final totalWords = blocks.fold(
        0,
        (sum, block) =>
            sum +
            block.content
                .split(RegExp(r'\s+'))
                .where((w) => w.isNotEmpty)
                .length,
      );

      final wordsPerSecond = EditorSettingsCache.instance.wordsPerSecond;
      final totalSeconds = (totalWords / wordsPerSecond).ceil();
      final minutes = (totalSeconds / 60).floor();
      final seconds = totalSeconds % 60;
      return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
    } else {
      final wordCount =
          content.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
      final totalSeconds = (wordCount / 200 * 60).ceil();
      final minutes = (totalSeconds / 60).floor();
      final seconds = totalSeconds % 60;
      return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
    }
  }
}

class EditorManager {
  static Future<void> saveNote({
    required File selectedNote,
    required TextEditingController titleController,
    required TextEditingController noteController,
    required Directory currentDir,
    Function? onUpdateItems,
    Function(String, String)? onUpdatePath,
  }) async {
    final originalName = p.basename(selectedNote.path);
    File currentFile = selectedNote;

    try {
      await _saveNoteContent(
        selectedNote: currentFile,
        noteController: noteController,
      );

      final newPath = await _handleTitleChange(
        selectedNote: currentFile,
        titleController: titleController,
        currentDir: currentDir,
      );

      if (newPath != null) {
        currentFile = File(newPath);

        if (onUpdatePath != null) {
          onUpdatePath(selectedNote.path, newPath);
        }

        if (p.basename(newPath) != originalName && onUpdateItems != null) {
          await onUpdateItems();
        }
      }
    } catch (e) {
      print('Error saving note: $e');
      throw Exception('Error saving: $e');
    }
  }

  static Future<String?> _handleTitleChange({
    required File selectedNote,
    required TextEditingController titleController,
    required Directory currentDir,
  }) async {
    final currentTitle = titleController.text.trim();
    final previousTitle = p.basenameWithoutExtension(selectedNote.path);

    if (currentTitle.isNotEmpty && currentTitle != previousTitle) {
      final newName = '$currentTitle.md';
      final newPath = p.join(currentDir.path, newName);

      if (File(newPath).existsSync()) {
        return null;
      }

      try {
        await selectedNote.rename(newPath);
        return newPath;
      } catch (e) {
        print('Error renaming file: $e');
        return null;
      }
    }

    return null;
  }

  static Future<void> _saveNoteContent({
    required File selectedNote,
    required TextEditingController noteController,
  }) async {
    await selectedNote.writeAsString(noteController.text);
  }

  static Future<Timer?> configureAutoSave({
    required TextEditingController noteController,
    required TextEditingController titleController,
    required Function onSave,
    Timer? debounceNote,
    Timer? debounceTitle,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final autoSaveEnabled = prefs.getBool('auto_save_enabled') ?? true;

    if (!autoSaveEnabled) return null;

    debounceNote?.cancel();
    debounceTitle?.cancel();

    return Timer(const Duration(seconds: 3), () {
      onSave();
    });
  }

  static Future<bool> getEditorCentered() async {
    return EditorSettings.getEditorCentered();
  }

  static Future<void> setEditorCentered(bool centered) async {
    await EditorSettings.setEditorCentered(centered);
  }

  static Future<void> saveNoteContent({
    required File selectedNote,
    required TextEditingController noteController,
  }) async {
    await _saveNoteContent(
      selectedNote: selectedNote,
      noteController: noteController,
    );
  }
}
