import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

// Global reference to the current active editor's toggle read mode function
VoidCallback? _currentActiveEditorToggleReadMode;

// Global function to toggle read mode on the currently active editor
void toggleActiveEditorReadMode() {
  _currentActiveEditorToggleReadMode?.call();
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
  final TabManager? tabManager; // Para manejar navegación entre notas
  final bool initialReadMode; // Estado inicial del modo lectura desde el tab
  final ValueChanged<bool>?
  onReadModeChanged; // Callback cuando cambia el modo lectura
  final bool initialEditorCentered; // Estado inicial del centrado desde el tab
  final ValueChanged<bool>?
  onEditorCenteredChanged; // Callback cuando cambia el centrado
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
  bool _isEditorCentered = false; // Estado individual de centrado por tab
  bool _showFindBar = false;
  bool _isRestoringSearch = false;
  bool _isEditorSettingsLoaded = false;
  Timer? _scriptDetectionDebouncer;
  Timer? _autoSaveDebounce;
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
  StreamSubscription? _fontSizeSubscription;
  StreamSubscription? _lineSpacingSubscription;
  StreamSubscription? _fontColorSubscription;
  StreamSubscription? _fontFamilySubscription;
  StreamSubscription? _autoSaveEnabledSubscription;
  StreamSubscription? _wordsPerSecondSubscription;
  StreamSubscription? _showBottomBarSubscription;
  late ImmersiveModeService _immersiveModeService;
  late SearchManager _searchManager;
  final UndoHistoryController _undoController = UndoHistoryController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _exportButtonKey = GlobalKey();

  TextStyle get _textStyle => TextStyle(
    fontSize: _fontSize,
    height: _lineSpacing,
    fontFamily: _fontFamily,
    color:
        _useThemeFontColor
            ? Theme.of(context).colorScheme.onSurface
            : _fontColor ?? Theme.of(context).colorScheme.onSurface,
    letterSpacing: 0.0,
  );

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
      // Use multiple approaches to ensure highlighting works

      // 1. Set selection immediately
      widget.noteController.selection = TextSelection(
        baseOffset: queryIndex,
        extentOffset: queryIndex + widget.searchQuery!.length,
      );

      // 2. Use a timer to ensure the selection is applied after the widget is fully built
      Timer(const Duration(milliseconds: 100), () {
        if (mounted) {
          // Set selection again to ensure it's applied
          widget.noteController.selection = TextSelection(
            baseOffset: queryIndex,
            extentOffset: queryIndex + widget.searchQuery!.length,
          );

          // Focus the editor to ensure it's visible
          _editorFocusNode.requestFocus();
        }
      });

      // 3. Use another timer with longer delay as backup
      Timer(const Duration(milliseconds: 500), () {
        if (mounted) {
          // Set selection one more time as backup
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
    _findController.addListener(() {
      if (_isRestoringSearch) return;
      final query = _findController.text;
      _searchManager.performFind(query, () {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {});
              // Update TabManager with the current search query to persist it across tab switches
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

    // Inicializar modo lectura desde el tab
    _isReadMode = widget.initialReadMode;

    // Inicializar centrado desde el tab
    _isEditorCentered = widget.initialEditorCentered;

    // Register this editor as the active one for global toggle function
    _currentActiveEditorToggleReadMode = _toggleReadMode;

    // Initialize SearchManager
    _searchManager = SearchManager(
      noteController: widget.noteController,
      scrollController: _scrollController,
      textStyle: TextStyle(
        fontSize: _fontSize,
        height: _lineSpacing,
        fontFamily: _fontFamily,
      ),
    );

    // Inicializar configuraciones después de que el widget esté completamente montado
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeEditorSettings();
      _highlightSearchText();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Cuando la app vuelve a estar activa, actualizar configuraciones
      _refreshEditorSettings();
    }
  }

  @override
  void didUpdateWidget(NotaEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If changed note (by ID), reconfigure listeners for new controllers
    // We use the ID instead of comparing objects because Note does not have operator ==
    final noteChanged = oldWidget.selectedNote.id != widget.selectedNote.id;
    final findBarHadFocus = _findBarFocusNode.hasFocus;

    if (noteChanged) {
      _reconfigureListeners(oldWidget);
      _detectScriptMode();

      // Update the SearchManager with the new controllers
      _searchManager.updateControllers(
        newNoteController: widget.noteController,
        newScrollController: _scrollController,
      );

      // Sync read mode with the new tab's state
      if (_isReadMode != widget.initialReadMode) {
        setState(() {
          _isReadMode = widget.initialReadMode;
        });
      }

      // Restore search text and re-run search for the new note
      if (_showFindBar) {
        final newQuery = widget.searchQuery ?? '';
        _isRestoringSearch = true;
        _findController.text = newQuery;
        _isRestoringSearch = false;

        // Re-run search on the new note content and restore focus if needed
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

    // Sync editor centering with the new tab's state (always, not just when the note changes)
    if (_isEditorCentered != widget.initialEditorCentered) {
      setState(() {
        _isEditorCentered = widget.initialEditorCentered;
      });
    }

    // Sync read mode with the new tab's state (always, not just when the note changes)
    if (_isReadMode != widget.initialReadMode) {
      setState(() {
        _isReadMode = widget.initialReadMode;
      });
    }

    if (oldWidget.searchQuery != widget.searchQuery ||
        oldWidget.isAdvancedSearch != widget.isAdvancedSearch) {
      // Highlight search text when search parameters change
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _highlightSearchText();
      });
    }

    // Only reload settings if they are not loaded
    if (!_isEditorSettingsLoaded) {
      _loadEditorSettings();
    }

    // Force refresh settings when the widget is shown again
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
    _fontSizeSubscription?.cancel();
    _lineSpacingSubscription?.cancel();
    _fontColorSubscription?.cancel();
    _fontFamilySubscription?.cancel();
    _autoSaveEnabledSubscription?.cancel();
    _wordsPerSecondSubscription?.cancel();
    _showBottomBarSubscription?.cancel();
    _immersiveModeService.removeListener(_onImmersiveModeChanged);
    _scrollController.dispose();

    // Clear global reference if this is the active editor
    if (_currentActiveEditorToggleReadMode == _toggleReadMode) {
      _currentActiveEditorToggleReadMode = null;
    }

    super.dispose();
  }

  void _onTitleChanged() {
    widget.onTitleChanged();

    if (_isAutoSaveEnabled) {
      _autoSaveDebounce?.cancel();
      _autoSaveDebounce = Timer(const Duration(milliseconds: 1000), () {
        if (mounted && _isAutoSaveEnabled) {
          // Usar método que no afecte el foco para auto-guardado
          _performSilentAutoSave();
        }
      });
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

    if (_isAutoSaveEnabled) {
      _autoSaveDebounce?.cancel();
      _autoSaveDebounce = Timer(const Duration(milliseconds: 1000), () {
        if (mounted && _isAutoSaveEnabled) {
          // Usar método que no afecte el foco para auto-guardado
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
    // Remover listeners antiguos de los controladores del componente anterior
    try {
      oldWidget.noteController.removeListener(_onContentChanged);
      oldWidget.titleController.removeListener(_onTitleChanged);
    } catch (e) {
      // Si ya están dispuestos, ignorar
    }

    // Agregar listeners a los nuevos controladores
    widget.noteController.addListener(_onContentChanged);
    widget.titleController.addListener(_onTitleChanged);
  }

  void _toggleReadMode() {
    setState(() {
      _isReadMode = !_isReadMode;
    });

    // Notificar al TabManager del cambio de modo lectura
    widget.onReadModeChanged?.call(_isReadMode);

    // Close search when switching to read mode
    if (_isReadMode && _showFindBar) {
      _hideFindBar();
    }
  }

  void _toggleEditorCentered() {
    setState(() {
      _isEditorCentered = !_isEditorCentered;
    });

    // Notificar al TabManager del cambio de centrado
    widget.onEditorCenteredChanged?.call(_isEditorCentered);
  }

  Future<void> _handleSave({bool isAutoSave = false}) async {
    if (!mounted) return;

    // Guardar el estado del foco y cursor antes del guardado
    final bool hadFocus = _editorFocusNode.hasFocus;
    final TextSelection currentSelection = widget.noteController.selection;
    final int? originalNoteId = widget.selectedNote.id;

    // Para auto-guardado, usar método separado que no interfiera con el foco
    if (isAutoSave) {
      try {
        await _performAutoSave();
      } catch (e) {
        print('Error in auto-save: $e');
      }
      return;
    }

    // Para guardado manual, ejecutar en background sin afectar el UI
    try {
      if (!mounted) return;

      // Iniciar animación de guardado sin bloquear
      _saveController.start();

      // Ejecutar guardado en background
      await _performBackgroundSave();

      // Completar animación sin reconstruir el widget principal
      await _saveController.complete();

      // Restaurar foco y posición del cursor si se perdieron
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
        // Restaurar foco incluso en caso de error
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

    // Guardar directamente en la base de datos sin reconstruir el widget
    try {
      final dbHelper = DatabaseHelper();
      final noteRepository = NoteRepository(dbHelper);

      await noteRepository.updateNoteTitleAndContent(
        widget.selectedNote.id!,
        widget.titleController.text.trim(),
        widget.noteController.text,
      );

      // En SQLite con drift/sqlite3, updateNoteTitleAndContent no devuelve un valor,
      // pero podemos asumir que fue exitoso si no lanzó excepción.
      // Notificar cambios sin reconstruir el widget
      DatabaseHelper.notifyDatabaseChanged();

      // Actualizar el estado del tab para quitar el indicador dirty
      // Creamos un objeto Note actualizado para el tab, pero manteniendo la metadata actual
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
      // Ejecutar el guardado sin afectar el UI
      // Usar el mismo método de auto-save para mantener consistencia
      await _performAutoSave();
    } catch (e) {
      print('Error in background save: $e');
      rethrow;
    }
  }

  void _performSilentAutoSave() async {
    if (!mounted) return;

    try {
      // Ejecutar auto-guardado de forma completamente silenciosa
      // sin afectar el foco ni el estado del UI
      await _performAutoSave();
    } catch (e) {
      print('Error in silent auto-save: $e');
      // No propagar el error para evitar interrumpir la experiencia del usuario
    }
  }

  void _updateTabStateAfterAutoSave(Note updatedNote) {
    // Notificar al widget padre que el auto-guardado se completó
    // sin reconstruir el widget actual
    if (widget.onAutoSaveCompleted != null) {
      // Usar scheduleMicrotask para evitar interrumpir el ciclo de construcción
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

    _wordsPerSecondSubscription = EditorSettingsEvents.wordsPerSecondStream
        .listen((wps) {
          if (mounted) {
            setState(() {
              // Force rebuild to update duration estimator
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

      // Get all blocks and their positions
      ScriptModeHandlerDesktop.parseScript(text);
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
      widget.noteController.text = newText;

      // Update the selection to include the new block header
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

      // Trigger content changed
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

    // Find the start and end of the current line
    int lineStart = text.lastIndexOf('\n', cursorPosition - 1) + 1;
    int lineEnd = text.indexOf('\n', cursorPosition);
    if (lineEnd == -1) lineEnd = text.length;

    final currentLine = text.substring(lineStart, lineEnd);

    // Extract leading whitespace to preserve it
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
        // It's already a list item
        if (listItem.type == targetListType) {
          // Same type, remove it
          newLine = leadingWhitespace + listItem.content;
          // Calculate how many characters were removed
          int removedChars = currentLine.length - newLine.length;
          newCursorOffset = cursorPosition - removedChars;
        } else {
          // Different type, replace it
          newLine = leadingWhitespace + prefix + listItem.content;
          // Calculate the difference in prefix length
          int oldPrefixLength =
              currentLine.length -
              leadingWhitespace.length -
              listItem.content.length;
          newCursorOffset = cursorPosition + (prefix.length - oldPrefixLength);
        }
      } else {
        // Not a list, add it
        newLine = leadingWhitespace + prefix + lineWithoutWhitespace;
        newCursorOffset = cursorPosition + prefix.length;
      }
    } else {
      // Heading
      final headingMatch = RegExp(
        r'^(#+)\s+(.*)$',
      ).firstMatch(lineWithoutWhitespace);
      if (headingMatch != null) {
        final currentPrefix = '${headingMatch.group(1)!} ';
        if (currentPrefix.trim() == prefix.trim()) {
          // Same heading level, remove it
          newLine = leadingWhitespace + headingMatch.group(2)!;
          newCursorOffset = cursorPosition - currentPrefix.length;
        } else {
          // Different heading level, replace it
          newLine = leadingWhitespace + prefix + headingMatch.group(2)!;
          newCursorOffset =
              cursorPosition + (prefix.length - currentPrefix.length);
        }
      } else {
        // Not a heading, add it
        newLine = leadingWhitespace + prefix + lineWithoutWhitespace;
        newCursorOffset = cursorPosition + prefix.length;
      }
    }

    final newText =
        text.substring(0, lineStart) + newLine + text.substring(lineEnd);
    controller.text = newText;
    controller.selection = TextSelection.collapsed(
      offset: newCursorOffset.clamp(lineStart, lineStart + newLine.length),
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
        // Remove #script and any following newline
        String newText = text.replaceFirst(RegExp(r'^#script\n?'), '');
        widget.noteController.text = newText;
        widget.onContentChanged();
      } else {
        widget.noteController.text = '#script\n$text';
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
        widget.noteController.text = newText;
        widget.onContentChanged();
      }

      // Restore focus and selection
      _editorFocusNode.requestFocus();
    } else {
      // No selection

      // Check if it's a line-level format (list or heading)
      if (_isLineLevelFormat(type)) {
        _toggleLineFormat(type);
        return;
      }

      // No selection, insert empty format markers and place cursor inside
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
          prefix = '[[';
          suffix = ']]';
          cursorOffset = 2;
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
          // Insert horizontal rule on a new line
          final currentText = widget.noteController.text;
          String insertText;
          int newCursorOffset;

          // Check if we're at the start of a line or need to add a newline before
          if (start == 0 || currentText[start - 1] == '\n') {
            insertText = '* * *\n';
            newCursorOffset = 6; // After the newline
          } else {
            insertText = '\n* * *\n';
            newCursorOffset = 7; // After the newline
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

      // Ensure editor has focus
      _editorFocusNode.requestFocus();
    }
  }

  void _handleFindInEditor() {
    if (_isReadMode) return; // Don't show find bar in read mode

    setState(() {
      _showFindBar = true;
    });

    // Focus the find bar after a short delay to ensure it's built
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

        // Clear search query in TabManager when closing the find bar
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
    // Keep focus on find bar
    _findBarFocusNode.requestFocus();
  }

  void _previousMatch() {
    _searchManager.previousMatch(() {
      if (mounted) setState(() {});
    });
    // Keep focus on find bar
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

    // Asegurar que el cache esté inicializado
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

    // Get the position of the specific button using GlobalKey
    final RenderBox? button =
        _exportButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (button != null) {
      final Offset offset = button.localToGlobal(Offset.zero);
      final Size size = button.size;

      // Calculate position to show menu below the button
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
            // Update SearchManager's textStyle when building
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

                // Allow global shortcuts to propagate when not in find mode
                // Check for Ctrl+T (new tab) and other global shortcuts
                if (event is KeyDownEvent) {
                  if (event.logicalKey == LogicalKeyboardKey.keyT &&
                      HardwareKeyboard.instance.isControlPressed) {
                    // Let the global shortcut handler deal with this
                    return KeyEventResult.ignored;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.keyN &&
                      HardwareKeyboard.instance.isControlPressed) {
                    // Let the global shortcut handler deal with this
                    return KeyEventResult.ignored;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.keyW &&
                      HardwareKeyboard.instance.isControlPressed) {
                    // Let the global shortcut handler deal with this
                    return KeyEventResult.ignored;
                  }
                  // Ctrl+S is handled by the Shortcuts widget with SaveIntent
                  // Don't propagate it to global handlers to preserve focus
                }

                return KeyEventResult.ignored;
              },
              child: Column(
                children: [
                  if (_immersiveModeService.isImmersiveMode &&
                      !Platform.isLinux &&
                      EditorSettingsCache.instance.hideTabsInImmersive)
                    const DraggableArea(height: 40),
                  // Title bar - with centered padding when editor is centered
                  Container(
                    padding: EdgeInsets.only(
                      left:
                          _isEditorCentered && constraints.maxWidth >= 600
                              ? _calculateCenteredPaddingForEditor(
                                constraints.maxWidth,
                              )
                              : 0,
                      right:
                          _isEditorCentered && constraints.maxWidth >= 600
                              ? _calculateCenteredPaddingForEditor(
                                constraints.maxWidth,
                              )
                              : 0,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        height:
                            44.0, // Slightly increase height to prevent vertical cutoff
                        alignment: Alignment.center,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Focus(
                                onKeyEvent: (node, event) {
                                  // Allow global shortcuts to propagate
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
                                    // Ctrl+S is handled by the Shortcuts widget with SaveIntent
                                    // Don't propagate it to global handlers to preserve focus
                                  }
                                  return KeyEventResult.ignored;
                                },
                                child: TextField(
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
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall?.copyWith(
                                    height:
                                        1.2, // Reduce line height to prevent vertical cutoff
                                  ),
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
                              builder: (context, isHovering) => SaveButton(
                                controller: _saveController,
                                onPressed: () {
                                  _handleSave();
                                },
                              ),
                            ),
                            CustomTooltip(
                              message: _isReadMode ? 'Edit mode' : 'Read mode',
                              builder: (context, isHovering) => IconButton(
                                icon: Icon(
                                  _isReadMode
                                      ? Icons.edit_rounded
                                      : Icons.visibility_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                onPressed: _toggleReadMode,
                              ),
                            ),
                            CustomTooltip(
                              message: _isEditorCentered ? 'Disable centered layout' : 'Enable centered layout',
                              builder: (context, isHovering) => IconButton(
                                icon: Icon(
                                  _isEditorCentered
                                      ? Icons.format_align_justify_rounded
                                      : Icons.format_align_center_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                onPressed: _toggleEditorCentered,
                              ),
                            ),
                            CustomTooltip(
                              message: _showBottomBar ? 'Hide formatting bar' : 'Show formatting bar',
                              builder: (context, isHovering) => IconButton(
                                icon: Icon(
                                  _showBottomBar
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  color: Theme.of(context).colorScheme.primary,
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
                                message: 'Exit immersive mode',
                                builder: (context, isHovering) => IconButton(
                                  icon: Icon(
                                    Icons.fullscreen_exit_rounded,
                                    color: Theme.of(context).colorScheme.primary,
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
                            _isEditorCentered && constraints.maxWidth >= 600
                                ? _calculateCenteredPaddingForEditor(
                                  constraints.maxWidth,
                                )
                                : 0,
                        right:
                            _isEditorCentered && constraints.maxWidth >= 600
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

                  // Editor content - with centered padding when needed
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.only(
                        left:
                            _isEditorCentered && constraints.maxWidth >= 600
                                ? _calculateCenteredPaddingForEditor(
                                  constraints.maxWidth,
                                )
                                : 0,
                        right:
                            _isEditorCentered && constraints.maxWidth >= 600
                                ? _calculateCenteredPaddingForEditor(
                                  constraints.maxWidth,
                                )
                                : 0,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Stack(
                          children: [
                            // Main editor content
                            _isReadMode
                                ? _isScript
                                    ? ScriptModeHandlerDesktop.buildScriptPreview(
                                      context,
                                      widget.noteController.text,
                                      textStyle: _textStyle,
                                      onNoteLinkTap: (note, isMiddleClick) {
                                        _handleNoteLinkTap(note, isMiddleClick);
                                      },
                                    )
                                    : _buildNoteReadPreview(context)
                                : _buildHighlightedTextField(),

                            // Find bar as floating overlay
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
    // For very small screens, don't center to avoid content cutoff
    if (availableWidth < 600) {
      return 0.0; // No centering on very small screens
    } else if (availableWidth < 800) {
      // Small screens: minimal centering with safety margin
      double minEditorWidth =
          500.0; // Ensure enough space for title and buttons
      double maxPadding = (availableWidth - minEditorWidth) / 2;
      return maxPadding.clamp(16.0, 32.0); // Very conservative padding
    } else if (availableWidth < 1200) {
      // Medium screens: adaptive width approach
      double minEditorWidth = 600.0; // More space for title
      double maxPadding = (availableWidth - minEditorWidth) / 2;

      // Use proportional padding but respect minimum width
      double proportionalPadding = availableWidth * 0.10; // 10% padding
      return proportionalPadding.clamp(16.0, maxPadding);
    } else {
      // Large screens: fixed width centering
      double maxEditorWidth = 800.0; // Optimal reading width
      double padding = (availableWidth - maxEditorWidth) / 2;
      return padding.clamp(100.0, 400.0);
    }
  }

  Widget _buildHighlightedTextField() {
    return Focus(
      onKeyEvent: (node, event) {
        // Handle Enter key for list continuation
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.enter) {
          final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;

          // Try to handle list continuation
          if (ListContinuationHandler.handleEnterKey(
            widget.noteController,
            isShiftPressed,
          )) {
            widget.onContentChanged();
            return KeyEventResult.handled;
          }

          // If not handled by list continuation, let default behavior proceed
        }

        // Handle Ctrl+S for manual save (workaround for Linux)
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.keyS &&
            HardwareKeyboard.instance.isControlPressed &&
            !HardwareKeyboard.instance.isShiftPressed) {
          _handleSave();
          return KeyEventResult.handled;
        }

        // Allow global shortcuts to propagate
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
          // Ctrl+S is handled by the Shortcuts widget with SaveIntent
          // Don't propagate it to global handlers to preserve focus
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

  Widget _buildNoteReadPreview(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final text = widget.noteController.text;
    // Use the same color as the first script mode block
    final backgroundColor = colorScheme.surfaceContainerLow;

    return SingleChildScrollView(
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(top: 8),
        child:
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
                    widget.noteController.value = widget.noteController.value.copyWith(
                      text: newText,
                      selection: TextSelection.collapsed(offset: newText.length),
                    );
                  },
                ),
      ),
    );
  }

  void _handleNotebookLinkTap(Notebook notebook, bool isMiddleClick) {
    if (widget.onNotebookLinkTap != null) {
      widget.onNotebookLinkTap!(notebook);
    }
  }

  /// Handles note link taps - opens note in current tab or new tab
  void _handleNoteLinkTap(Note targetNote, bool openInNewTab) {
    if (widget.onNoteLinkTap != null) {
      widget.onNoteLinkTap!(targetNote, openInNewTab);
      return;
    }

    if (widget.tabManager == null) return;

    // Skip if the note doesn't exist (notebookId -1 indicates a dummy note)
    if (targetNote.notebookId == -1 || targetNote.id == null) {
      return;
    }

    if (openInNewTab) {
      // Open in new tab (middle click or Ctrl+click) and change notebook
      widget.tabManager!.openTabWithNotebookChange(targetNote);
    } else {
      // Open in current tab (left click) and change notebook
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
      final totalSeconds =
          (wordCount / 200 * 60).ceil(); // 200 words per minute
      final minutes = (totalSeconds / 60).floor();
      final seconds = totalSeconds % 60;
      return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
    }
  }
}

// Class to manage editor settings
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
      // First save content before renaming
      await _saveNoteContent(
        selectedNote: currentFile,
        noteController: noteController,
      );

      // Then rename if necessary
      final newPath = await _handleTitleChange(
        selectedNote: currentFile,
        titleController: titleController,
        currentDir: currentDir,
      );

      if (newPath != null) {
        // Update reference to current file
        currentFile = File(newPath);

        // Notify path change
        if (onUpdatePath != null) {
          onUpdatePath(selectedNote.path, newPath);
        }

        // If name changed, update file list
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

      // Check if destination file already exists
      if (File(newPath).existsSync()) {
        // If it exists, don't try to rename and return null
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
