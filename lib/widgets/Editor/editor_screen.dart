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
import '../../database/database_helper.dart';
import '../../database/repositories/note_repository.dart';
import '../../shortcuts_handler.dart';
import '../../services/immersive_mode_service.dart';
import '../../services/export_service.dart';
import '../find_bar.dart';
import '../context_menu.dart';
import 'unified_text_handler.dart';
import 'list_continuation_handler.dart';
import '../../services/tab_manager.dart';

// Global reference to the current active editor's toggle read mode function
VoidCallback? _currentActiveEditorToggleReadMode;

// Global function to toggle read mode on the currently active editor
void toggleActiveEditorReadMode() {
  _currentActiveEditorToggleReadMode?.call();
}

class NotaEditor extends StatefulWidget {
  final Note selectedNote;
  final TextEditingController noteController;
  final TextEditingController titleController;
  final VoidCallback onSave;
  final bool isEditorCentered;
  final VoidCallback onTitleChanged;
  final VoidCallback onContentChanged;
  final VoidCallback? onToggleEditorCentered;
  final String? searchQuery;
  final bool isAdvancedSearch;
  final VoidCallback? onAutoSaveCompleted;
  final TabManager? tabManager; // Para manejar navegación entre notas

  const NotaEditor({
    super.key,
    required this.selectedNote,
    required this.noteController,
    required this.titleController,
    required this.onSave,
    required this.isEditorCentered,
    required this.onTitleChanged,
    required this.onContentChanged,
    this.onToggleEditorCentered,
    this.searchQuery,
    this.isAdvancedSearch = false,
    this.onAutoSaveCompleted,
    this.tabManager,
  });

  @override
  State<NotaEditor> createState() => _NotaEditorState();
}

class _NotaEditorState extends State<NotaEditor>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _isScript = false;
  bool _isReadMode = false;
  bool _showFindBar = false;
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
  StreamSubscription? _fontSizeSubscription;
  StreamSubscription? _lineSpacingSubscription;
  StreamSubscription? _fontColorSubscription;
  StreamSubscription? _fontFamilySubscription;
  StreamSubscription? _editorCenteredSubscription;
  StreamSubscription? _autoSaveEnabledSubscription;
  late ImmersiveModeService _immersiveModeService;
  int _currentFindIndex = -1;
  List<int> _findMatches = [];
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
      _performFind(_findController.text);
    });
    _detectScriptMode();
    _setupSettingsListeners();
    _initializeImmersiveMode();

    // Register this editor as the active one for global toggle function
    _currentActiveEditorToggleReadMode = _toggleReadMode;

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

    // Si cambió la nota, reconfigurar los listeners para los nuevos controladores
    if (oldWidget.selectedNote != widget.selectedNote) {
      _reconfigureListeners();
      _detectScriptMode();
    }

    if (oldWidget.searchQuery != widget.searchQuery ||
        oldWidget.isAdvancedSearch != widget.isAdvancedSearch) {
      // Highlight search text when search parameters change
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _highlightSearchText();
      });
    }

    // Solo recargar configuraciones si no están cargadas
    if (!_isEditorSettingsLoaded) {
      _loadEditorSettings();
    }

    // Forzar actualización de configuraciones cuando el widget se vuelve a mostrar
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
    _editorFocusNode.dispose();
    _findBarFocusNode.dispose();
    _findController.dispose();
    _fontSizeSubscription?.cancel();
    _lineSpacingSubscription?.cancel();
    _fontColorSubscription?.cancel();
    _fontFamilySubscription?.cancel();
    _editorCenteredSubscription?.cancel();
    _autoSaveEnabledSubscription?.cancel();
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

  void _reconfigureListeners() {
    // Remover listeners antiguos si existen
    widget.noteController.removeListener(_onContentChanged);
    widget.titleController.removeListener(_onTitleChanged);

    // Agregar listeners a los nuevos controladores
    widget.noteController.addListener(_onContentChanged);
    widget.titleController.addListener(_onTitleChanged);
  }

  void _toggleReadMode() {
    setState(() {
      _isReadMode = !_isReadMode;
    });

    // Close search when switching to read mode
    if (_isReadMode && _showFindBar) {
      _hideFindBar();
    }
  }

  Future<void> _handleSave({bool isAutoSave = false}) async {
    if (!mounted) return;

    // Guardar el estado del foco y cursor antes del guardado
    final bool hadFocus = _editorFocusNode.hasFocus;
    final TextSelection currentSelection = widget.noteController.selection;

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
          if (mounted) {
            _editorFocusNode.requestFocus();
            widget.noteController.selection = currentSelection;
          }
        });
      }
      
    } catch (e) {
      print('Error in _handleSave: $e');
      if (mounted) {
        _saveController.reset();
        // Restaurar foco incluso en caso de error
        if (hadFocus) {
          _editorFocusNode.requestFocus();
          widget.noteController.selection = currentSelection;
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

      final updatedNote = Note(
        id: widget.selectedNote.id,
        title: widget.titleController.text.trim(),
        content: widget.noteController.text,
        notebookId: widget.selectedNote.notebookId,
        createdAt: widget.selectedNote.createdAt,
        updatedAt: DateTime.now(),
        isFavorite: widget.selectedNote.isFavorite,
        tags: widget.selectedNote.tags,
        orderIndex: widget.selectedNote.orderIndex,
        isTask: widget.selectedNote.isTask,
        isCompleted: widget.selectedNote.isCompleted,
      );

      final result = await noteRepository.updateNote(updatedNote);

      if (result > 0) {
        // Notificar cambios sin reconstruir el widget
        DatabaseHelper.notifyDatabaseChanged();

        // Actualizar el estado del tab para quitar el indicador dirty
        _updateTabStateAfterAutoSave(updatedNote);
      }
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
    _editorCenteredSubscription?.cancel();
    _autoSaveEnabledSubscription?.cancel();

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

    _editorCenteredSubscription = EditorSettingsEvents.editorCenteredStream
        .listen((isCentered) {
          // Esta configuración se maneja en el widget padre (main.dart)
          // Solo actualizamos el estado local si es necesario
        });

    _autoSaveEnabledSubscription = EditorSettingsEvents.autoSaveEnabledStream
        .listen((isEnabled) {
          if (mounted) {
            setState(() {
              _isAutoSaveEnabled = isEnabled;
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
    setState(() {
      _showFindBar = false;
      _currentFindIndex = -1;
      _findMatches.clear();
    });
    _findController.clear();
    _editorFocusNode.requestFocus();
  }

  void _performFind(String query) {
    if (query.isEmpty) {
      setState(() {
        _currentFindIndex = -1;
        _findMatches.clear();
      });
      return;
    }

    final text = widget.noteController.text;
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();

    List<int> matches = [];
    int index = 0;

    while ((index = lowerText.indexOf(lowerQuery, index)) != -1) {
      matches.add(index);
      index += 1;
    }

    setState(() {
      _findMatches = matches;
      _currentFindIndex = matches.isNotEmpty ? 0 : -1;
    });

    if (matches.isNotEmpty) {
      _selectCurrentMatch();
      // Keep focus on find bar
      _findBarFocusNode.requestFocus();
    }
  }

  void _selectCurrentMatch() {
    if (_currentFindIndex >= 0 && _currentFindIndex < _findMatches.length) {
      // Check if ScrollController is attached
      if (!_scrollController.hasClients) {
        // If not attached, schedule for next frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scrollController.hasClients) {
            _selectCurrentMatch();
          }
        });
        return;
      }

      // Calculate the position of the current match
      final matchPosition = _findMatches[_currentFindIndex];
      final text = widget.noteController.text;

      // Calculate scroll position more accurately
      final textBeforeMatch = text.substring(0, matchPosition);
      final lines = textBeforeMatch.split('\n');
      final lineNumber = lines.length - 1;

      // Estimate position based on line number and average line height
      final lineHeight = _fontSize * _lineSpacing;
      final estimatedPosition = lineNumber * lineHeight;

      // Get current scroll position and viewport height
      final viewportHeight = _scrollController.position.viewportDimension;

      // Calculate target position to center the match in the viewport
      final targetPosition = (estimatedPosition - viewportHeight / 2).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );

      // Animate scroll to the target position
      _scrollController.animateTo(
        targetPosition,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

      // Keep focus on find bar
      _findBarFocusNode.requestFocus();
    }
  }

  void _nextMatch() {
    if (_findMatches.isEmpty) return;

    setState(() {
      _currentFindIndex = (_currentFindIndex + 1) % _findMatches.length;
    });

    // Force rebuild to update highlighting
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });

    _selectCurrentMatch();
    // Keep focus on find bar
    _findBarFocusNode.requestFocus();
  }

  void _previousMatch() {
    if (_findMatches.isEmpty) return;

    setState(() {
      _currentFindIndex =
          _currentFindIndex <= 0
              ? _findMatches.length - 1
              : _currentFindIndex - 1;
    });

    // Force rebuild to update highlighting
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });

    _selectCurrentMatch();
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
              // Preservar foco antes del guardado para shortcuts
              final hadFocus = _editorFocusNode.hasFocus;
              final currentSelection = widget.noteController.selection;
              
              _handleSave().then((_) {
                // Restaurar foco después del guardado si se perdió
                if (hadFocus && !_editorFocusNode.hasFocus) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _editorFocusNode.requestFocus();
                      widget.noteController.selection = currentSelection;
                    }
                  });
                }
              });
              
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
                  if (event.logicalKey == LogicalKeyboardKey.keyS &&
                      HardwareKeyboard.instance.isControlPressed) {
                    // Let the global shortcut handler deal with this
                    return KeyEventResult.ignored;
                  }
                }

                return KeyEventResult.ignored;
              },
              child: Column(
                children: [
                  const SizedBox(height: 16.0),
                  // Title bar - with centered padding when editor is centered
                  Container(
                    padding: EdgeInsets.only(
                      left:
                          widget.isEditorCentered && constraints.maxWidth >= 600
                              ? _calculateCenteredPaddingForEditor(
                                constraints.maxWidth,
                              )
                              : 0,
                      right:
                          widget.isEditorCentered && constraints.maxWidth >= 600
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
                                    if (event.logicalKey ==
                                            LogicalKeyboardKey.keyS &&
                                        HardwareKeyboard
                                            .instance
                                            .isControlPressed) {
                                      return KeyEventResult.ignored;
                                    }
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
                            const SizedBox(width: 8),
                            SaveButton(
                              controller: _saveController,
                              onPressed: () {
                                // Preservar foco antes del guardado
                                final hadFocus = _editorFocusNode.hasFocus;
                                final currentSelection = widget.noteController.selection;
                                
                                _handleSave().then((_) {
                                  // Restaurar foco después del guardado si se perdió
                                  if (hadFocus && !_editorFocusNode.hasFocus) {
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      if (mounted) {
                                        _editorFocusNode.requestFocus();
                                        widget.noteController.selection = currentSelection;
                                      }
                                    });
                                  }
                                });
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                _isReadMode
                                    ? Icons.edit_rounded
                                    : Icons.visibility_rounded,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              onPressed: _toggleReadMode,
                            ),
                            if (widget.onToggleEditorCentered != null)
                              Tooltip(
                                message: '',
                                child: IconButton(
                                  icon: Icon(
                                    widget.isEditorCentered
                                        ? Icons.format_align_justify_rounded
                                        : Icons.format_align_center_rounded,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                  onPressed: widget.onToggleEditorCentered,
                                ),
                              ),
                            if (_immersiveModeService.isImmersiveMode)
                              IconButton(
                                icon: Icon(
                                  Icons.fullscreen_exit_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                onPressed:
                                    () =>
                                        _immersiveModeService
                                            .exitImmersiveMode(),
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

                  // Editor content - with centered padding when needed
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.only(
                        left:
                            widget.isEditorCentered &&
                                    constraints.maxWidth >= 600
                                ? _calculateCenteredPaddingForEditor(
                                  constraints.maxWidth,
                                )
                                : 0,
                        right:
                            widget.isEditorCentered &&
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
                                  onFind: _performFind,
                                  onNext: _nextMatch,
                                  onPrevious: _previousMatch,
                                  currentIndex: _currentFindIndex,
                                  totalMatches: _findMatches.length,
                                  hasMatches: _findMatches.isNotEmpty,
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
    // If no search query or no matches, show normal TextField
    if (_findController.text.isEmpty || _findMatches.isEmpty) {
      return Focus(
        onKeyEvent: (node, event) {
          // Handle Enter key for list continuation
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
            final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
            
            // Try to handle list continuation
            if (ListContinuationHandler.handleEnterKey(widget.noteController, isShiftPressed)) {
              widget.onContentChanged();
              return KeyEventResult.handled;
            }
            
            // If not handled by list continuation, let default behavior proceed
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
            if (event.logicalKey == LogicalKeyboardKey.keyS &&
                HardwareKeyboard.instance.isControlPressed) {
              return KeyEventResult.ignored;
            }
          }
          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: widget.noteController,
          focusNode: _editorFocusNode,
          style: _textStyle,
          maxLines: null,
          expands: true,
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: 'Start writing...',
            hintStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: _fontSize,
              height: _lineSpacing,
            ),
          ),
          onChanged: (value) {
            widget.onContentChanged();
          },
        ),
      );
    }

    // For search mode, use a Stack with ScrollView containing both TextField and overlay
    return SingleChildScrollView(
      controller: _scrollController,
      child: Stack(
        children: [
          // Main TextField for editing
          Focus(
            onKeyEvent: (node, event) {
              // Handle Enter key for list continuation
              if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
                final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
                
                // Try to handle list continuation
                if (ListContinuationHandler.handleEnterKey(widget.noteController, isShiftPressed)) {
                  widget.onContentChanged();
                  return KeyEventResult.handled;
                }
                
                // If not handled by list continuation, let default behavior proceed
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
                if (event.logicalKey == LogicalKeyboardKey.keyS &&
                    HardwareKeyboard.instance.isControlPressed) {
                  return KeyEventResult.ignored;
                }
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              controller: widget.noteController,
              focusNode: _editorFocusNode,
              style: _textStyle,
              maxLines: null,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Start writing...',
                hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: _fontSize,
                  height: _lineSpacing,
                ),
              ),
              onChanged: (value) {
                widget.onContentChanged();
                // Don't perform search while editing to avoid focus issues
                // Search will be performed when find bar is used
              },
            ),
          ),
          // Overlay for highlighting (non-interactive)
          Positioned.fill(
            child: IgnorePointer(child: _buildHighlightOverlay()),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightOverlay() {
    final text = widget.noteController.text;
    final query = _findController.text;

    if (query.isEmpty || _findMatches.isEmpty) {
      return const SizedBox.shrink();
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();

    List<TextSpan> spans = [];
    int lastIndex = 0;

    // Find all matches and build text spans
    int index = 0;
    int matchIndex = 0;
    while ((index = lowerText.indexOf(lowerQuery, index)) != -1) {
      // Add text before match
      if (index > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, index),
            style: _textStyle.copyWith(color: Colors.transparent),
          ),
        );
      }

      // Add highlighted match - only current match gets bold
      final isCurrentMatch = matchIndex == _currentFindIndex;
      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: _textStyle.copyWith(
            backgroundColor:
                isCurrentMatch
                    ? Theme.of(context).colorScheme.primary.withAlpha(120)
                    : Theme.of(context).colorScheme.primary.withAlpha(50),
            fontWeight: isCurrentMatch ? FontWeight.w600 : FontWeight.normal,
            color: Colors.transparent,
          ),
        ),
      );

      lastIndex = index + query.length;
      index = lastIndex;
      matchIndex++;
    }

    // Add remaining text
    if (lastIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastIndex),
          style: _textStyle.copyWith(color: Colors.transparent),
        ),
      );
    }

    // If no spans were created, use original text
    if (spans.isEmpty) {
      spans.add(
        TextSpan(
          text: text,
          style: _textStyle.copyWith(color: Colors.transparent),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.only(
        top: 4.0, // Match TextField's default padding
        bottom: 4.0,
        left: 0.0,
        right: 0.0,
      ),
      alignment: Alignment.topLeft,
      child: RichText(
        text: TextSpan(children: spans),
        textAlign: TextAlign.start,
        textHeightBehavior: TextHeightBehavior(
          leadingDistribution: TextLeadingDistribution.even,
        ),
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
        child: text.isEmpty 
            ? Text(
                'No content to display',
                style: _textStyle,
                textAlign: TextAlign.start,
              )
            : _buildEnhancedTextView(text),
      ),
    );
  }

  Widget _buildEnhancedTextView(String text) {
    // Use the new UnifiedTextHandler that handles ALL formatting types
    return UnifiedTextHandler(
      text: text,
      textStyle: _textStyle,
      enableNoteLinkDetection: true,
      enableLinkDetection: true,
      enableListDetection: true,
      enableFormatDetection: true,
      onNoteLinkTap: (note, isMiddleClick) {
        _handleNoteLinkTap(note, isMiddleClick);
      },
      controller: widget.noteController,
      onTextChanged: (newText) {
        widget.noteController.text = newText;
        widget.onContentChanged();
      },
    );
  }

  /// Handles note link taps - opens note in current tab or new tab
  void _handleNoteLinkTap(Note targetNote, bool openInNewTab) {
    if (widget.tabManager == null) return;    
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
            duration,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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

      final totalSeconds = (totalWords * 0.20).ceil();
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
