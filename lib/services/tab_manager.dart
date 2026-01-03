import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../database/models/editor_tab.dart';
import '../database/models/note.dart';
import '../database/repositories/note_repository.dart';
import '../database/database_helper.dart';
import '../widgets/Editor/search_handler.dart';

class TabManager extends ChangeNotifier {
  final List<EditorTab> _tabs = [];
  EditorTab? _activeTab;
  int _emptyTabCounter = 0;

  // Callback to change notebook when opening notes from different notebooks
  Function(Note)? onNotebookChangeRequested;

  List<EditorTab> get tabs => List.unmodifiable(_tabs);
  EditorTab? get activeTab => _activeTab;
  bool get hasMultipleTabs => _tabs.length > 1;
  bool get hasEmptyTab => _tabs.any((tab) => tab.note == null);
  int get emptyTabCount => _tabs.where((tab) => tab.note == null).length;

  void openTab(
    Note note, {
    String? searchQuery,
    bool isAdvancedSearch = false,
  }) {
    // Check if tab already exists
    final existingTabIndex = _tabs.indexWhere(
      (tab) => tab.note != null && tab.note!.id == note.id,
    );

    if (existingTabIndex != -1) {
      // Update existing tab
      final existingTab = _tabs[existingTabIndex];
      final updatedTab = existingTab.copyWith(
        searchQuery: searchQuery,
        isAdvancedSearch: isAdvancedSearch,
        lastAccessed: DateTime.now(),
      );
      _tabs[existingTabIndex] = updatedTab;
      _activeTab = updatedTab;
    } else {
      // Create new tab
      final newTab = EditorTab(
        note: note,
        noteController: SearchTextEditingController(text: note.content),
        titleController: TextEditingController(text: note.title),
        searchQuery: searchQuery,
        isAdvancedSearch: isAdvancedSearch,
        lastAccessed: DateTime.now(),
      );
      _tabs.add(newTab);
      _activeTab = newTab;
    }

    _saveTabsToStorage();

    // Diferir la notificación para evitar problemas con los controladores
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  void createEmptyTab() {
    // Check if there's already an empty tab
    if (hasEmptyTab) {
      // Move existing empty tab to the end and make it active
      moveEmptyTabToEnd();
    } else {
      // Create new empty tab only if none exists
      final emptyTabId = 'empty_${++_emptyTabCounter}';
      final newTab = EditorTab(
        note: null,
        noteController: SearchTextEditingController(),
        titleController: TextEditingController(),
        lastAccessed: DateTime.now(),
        tabId: emptyTabId,
      );
      _tabs.add(newTab);
      _activeTab = newTab;

      _saveTabsToStorage();

      // Diferir la notificación para evitar problemas con los controladores
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  void assignNoteToActiveTab(Note note) {
    if (_activeTab == null || _activeTab!.note != null) return;

    final activeTabIndex = _tabs.indexOf(_activeTab!);
    if (activeTabIndex == -1) return;

    final oldNoteController = _activeTab!.noteController;
    final oldTitleController = _activeTab!.titleController;

    final updatedTab = _activeTab!.copyWith(
      note: note,
      noteController: SearchTextEditingController(text: note.content),
      titleController: TextEditingController(text: note.title),
      lastAccessed: DateTime.now(),
    );

    _tabs[activeTabIndex] = updatedTab;
    _activeTab = updatedTab;

    // Diferir la notificación para evitar problemas con los controladores
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Dispose old controllers after the frame
      try {
        oldNoteController.dispose();
      } catch (e) {
        // Already disposed
      }
      try {
        oldTitleController.dispose();
      } catch (e) {
        // Already disposed
      }
      notifyListeners();
    });
  }

  void replaceNoteInActiveTab(Note note) {
    if (_activeTab == null) return;

    final activeTabIndex = _tabs.indexOf(_activeTab!);
    if (activeTabIndex == -1) return;

    final oldNoteController = _activeTab!.noteController;
    final oldTitleController = _activeTab!.titleController;

    final updatedTab = _activeTab!.copyWith(
      note: note,
      noteController: SearchTextEditingController(text: note.content),
      titleController: TextEditingController(text: note.title),
      lastAccessed: DateTime.now(),
      isDirty: false, // Reset dirty state for new note
    );

    _tabs[activeTabIndex] = updatedTab;
    _activeTab = updatedTab;

    // Diferir la notificación para evitar problemas con los controladores
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Dispose old controllers after the frame
      oldNoteController.dispose();
      oldTitleController.dispose();
      notifyListeners();
    });
  }

  /// Opens a note and changes notebook if necessary
  void openTabWithNotebookChange(
    Note note, {
    String? searchQuery,
    bool isAdvancedSearch = false,
  }) {
    // Request notebook change if needed
    if (onNotebookChangeRequested != null) {
      onNotebookChangeRequested!.call(note);
    } else {}

    // Then open the tab normally
    openTab(note, searchQuery: searchQuery, isAdvancedSearch: isAdvancedSearch);
  }

  /// Replaces note in current tab and changes notebook if necessary
  void replaceNoteInActiveTabWithNotebookChange(Note note) {
    // Request notebook change if needed
    if (onNotebookChangeRequested != null) {
      onNotebookChangeRequested!.call(note);
    } else {}

    // Then replace the note in the active tab
    replaceNoteInActiveTab(note);
  }

  void selectTab(EditorTab tab) {
    if (_tabs.contains(tab)) {
      _activeTab = tab;
      _saveTabsToStorage();

      // Diferir la notificación para evitar problemas con los controladores
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  /// Toggle pinned state for a tab. Pinned tabs are moved to the front.
  void togglePin(EditorTab tab) {
    final index = _tabs.indexOf(tab);
    if (index == -1) return;

    final updated = tab.copyWith(isPinned: !tab.isPinned);

    // Dispose old controllers are the same, keep them
    _tabs[index] = updated;

    if (updated.isPinned) {
      // Move to front (index 0)
      _tabs.removeAt(index);
      _tabs.insert(0, updated);
    } else {
      // Unpinned - move after other pinned tabs (end of pinned area)
      _tabs.removeAt(index);
      final firstUnpinned = _tabs.indexWhere((t) => !t.isPinned);
      final insertIndex = firstUnpinned == -1 ? _tabs.length : firstUnpinned;
      _tabs.insert(insertIndex, updated);
    }

    // Update active tab reference if needed
    if (_activeTab == tab) {
      _activeTab = updated;
    }

    _saveTabsToStorage();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  void closeTab(EditorTab tab) {
    final index = _tabs.indexOf(tab);
    if (index != -1) {
      final noteController = tab.noteController;
      final titleController = tab.titleController;

      _tabs.removeAt(index);

      // Update active tab if needed
      if (_activeTab == tab) {
        if (_tabs.isNotEmpty) {
          _activeTab = _tabs.last;
        } else {
          _activeTab = null;
        }
      }

      _saveTabsToStorage();

      // Diferir la notificación y dispose para evitar problemas con los controladores
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          noteController.dispose();
        } catch (e) {
          // Controller already disposed
        }
        try {
          titleController.dispose();
        } catch (e) {
          // Controller already disposed
        }
        notifyListeners();
      });
    }
  }

  void closeAllTabs() {
    final controllersToDispose =
        _tabs.map((tab) => (tab.noteController, tab.titleController)).toList();
    _tabs.clear();
    _activeTab = null;

    // Diferir la notificación y dispose para evitar problemas con los controladores
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final (noteController, titleController) in controllersToDispose) {
        try {
          noteController.dispose();
        } catch (e) {
          // Already disposed
        }
        try {
          titleController.dispose();
        } catch (e) {
          // Already disposed
        }
      }
      notifyListeners();
    });
  }

  void closeOtherTabs(EditorTab keepTab) {
    final tabsToClose = _tabs.where((tab) => tab != keepTab).toList();
    final controllersToDispose =
        tabsToClose
            .map((tab) => (tab.noteController, tab.titleController))
            .toList();

    // Remove tabs
    _tabs.removeWhere((tab) => tab != keepTab);

    // Update active tab if needed
    if (_activeTab != null && !_tabs.contains(_activeTab)) {
      if (_tabs.isNotEmpty) {
        _activeTab = _tabs.last;
      } else {
        _activeTab = null;
      }
    }

    _saveTabsToStorage();

    // Single notification and dispose after all operations
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final (noteController, titleController) in controllersToDispose) {
        try {
          noteController.dispose();
        } catch (e) {
          // Already disposed
        }
        try {
          titleController.dispose();
        } catch (e) {
          // Already disposed
        }
      }
      notifyListeners();
    });
  }

  void updateTabContent(EditorTab tab, String content, String title) {
    final index = _tabs.indexOf(tab);
    if (index != -1) {
      final oldNoteController = tab.noteController;
      final oldTitleController = tab.titleController;

      // Crear nuevos controladores con el contenido actualizado
      final updatedTab = tab.copyWith(
        noteController: SearchTextEditingController(text: content),
        titleController: TextEditingController(text: title),
        note: tab.note?.copyWith(
          content: content,
          title: title,
          updatedAt: DateTime.now(),
        ),
        isDirty: true,
      );

      _tabs[index] = updatedTab;

      if (_activeTab == tab) {
        _activeTab = updatedTab;
      }

      _saveTabsToStorage();

      // Diferir la notificación y dispose para evitar problemas con los controladores
      WidgetsBinding.instance.addPostFrameCallback((_) {
        oldNoteController.dispose();
        oldTitleController.dispose();
        notifyListeners();
      });
    }
  }
  void setTabSearchQuery(EditorTab tab, String? query, {bool isAdvanced = false}) {
    final index = _tabs.indexOf(tab);
    if (index != -1) {
      // Only update if different to avoid unnecessary notifications
      if (_tabs[index].searchQuery == query &&
          _tabs[index].isAdvancedSearch == isAdvanced) {
        return;
      }

      final updatedTab = _tabs[index].copyWith(
        searchQuery: query,
        isAdvancedSearch: isAdvanced,
      );
      _tabs[index] = updatedTab;
      if (_activeTab == tab) {
        _activeTab = updatedTab;
      }
      _saveTabsToStorage();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }
  void markTabAsSaved(EditorTab tab) {
    final index = _tabs.indexOf(tab);
    if (index != -1) {
      final updatedTab = tab.copyWith(isDirty: false);
      _tabs[index] = updatedTab;

      if (_activeTab == tab) {
        _activeTab = updatedTab;
      }

      // Diferir la notificación para evitar problemas con los controladores
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  void markTabAsDirty(EditorTab tab) {
    final index = _tabs.indexOf(tab);
    if (index != -1) {
      final updatedTab = tab.copyWith(isDirty: true);
      _tabs[index] = updatedTab;

      if (_activeTab == tab) {
        _activeTab = updatedTab;
      }

      // Diferir la notificación para evitar problemas con los controladores
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  void setTabReadMode(EditorTab tab, bool isReadMode) {
    final index = _tabs.indexOf(tab);
    if (index != -1) {
      final updatedTab = tab.copyWith(isReadMode: isReadMode);
      _tabs[index] = updatedTab;

      if (_activeTab == tab) {
        _activeTab = updatedTab;
      }

      _saveTabsToStorage();

      // No notificamos listeners aquí para evitar reconstrucciones innecesarias
      // El estado del modo lectura se maneja localmente en el editor
    }
  }

  void setTabEditorCentered(EditorTab tab, bool isEditorCentered) {
    final index = _tabs.indexOf(tab);
    if (index != -1) {
      final updatedTab = tab.copyWith(isEditorCentered: isEditorCentered);
      _tabs[index] = updatedTab;

      if (_activeTab == tab) {
        _activeTab = updatedTab;
      }

      _saveTabsToStorage();

      // No notificamos listeners aquí para evitar reconstrucciones innecesarias
      // El estado del centrado se maneja localmente en el editor
    }
  }

  void updateNoteInTab(Note updatedNote) {
    final index = _tabs.indexWhere(
      (tab) => tab.note != null && tab.note!.id == updatedNote.id,
    );
    if (index != -1) {
      final tab = _tabs[index];
      final oldNoteController = tab.noteController;
      final oldTitleController = tab.titleController;

      final updatedTab = tab.copyWith(
        note: updatedNote,
        noteController: SearchTextEditingController(text: updatedNote.content),
        titleController: TextEditingController(text: updatedNote.title),
      );

      _tabs[index] = updatedTab;

      if (_activeTab?.note?.id == updatedNote.id) {
        _activeTab = updatedTab;
      }

      // Diferir la notificación para evitar problemas con los controladores
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Dispose old controllers after the frame
        try {
          oldNoteController.dispose();
        } catch (e) {
          // Already disposed
        }
        try {
          oldTitleController.dispose();
        } catch (e) {
          // Already disposed
        }
        notifyListeners();
      });
    }
  }

  void updateNoteObjectInTab(Note updatedNote) {
    final index = _tabs.indexWhere(
      (tab) => tab.note != null && tab.note!.id == updatedNote.id,
    );
    if (index != -1) {
      final tab = _tabs[index];
      final updatedTab = tab.copyWith(
        note: updatedNote,
        // Keep existing controllers to avoid losing focus
      );

      _tabs[index] = updatedTab;

      if (_activeTab?.note?.id == updatedNote.id) {
        _activeTab = updatedTab;
      }

      // Diferir la notificación para evitar problemas con los controladores
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  void updateNoteObjectsInTabs(List<Note> updatedNotes) {
    if (updatedNotes.isEmpty) return;

    bool changed = false;
    for (final updatedNote in updatedNotes) {
      final index = _tabs.indexWhere(
        (tab) => tab.note != null && tab.note!.id == updatedNote.id,
      );
      if (index != -1) {
        final tab = _tabs[index];
        final updatedTab = tab.copyWith(note: updatedNote);

        _tabs[index] = updatedTab;

        if (_activeTab?.note?.id == updatedNote.id) {
          _activeTab = updatedTab;
        }
        changed = true;
      }
    }

    if (changed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  void reorderTabs(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    if (oldIndex < 0 || oldIndex >= _tabs.length) return;
    if (newIndex < 0 || newIndex >= _tabs.length) return;

    // Determine pinned groups before any modification
    final movingTab = _tabs[oldIndex];
    final wasPinned = movingTab.isPinned;
    final pinnedCount = _tabs.where((t) => t.isPinned).length;

    final allowedStart = wasPinned ? 0 : pinnedCount;
    final allowedEnd = wasPinned ? (pinnedCount - 1) : (_tabs.length - 1);

    // If target is outside allowed range for the group, abort (revert)
    if (newIndex < allowedStart || newIndex > allowedEnd) {
      // Do nothing to revert to previous position
      return;
    }

    // Perform reorder
    final tab = _tabs.removeAt(oldIndex);
    _tabs.insert(newIndex, tab);

    // Notificar inmediatamente para feedback visual instantáneo
    notifyListeners();

    // Guardar en storage de forma asíncrona
    _saveTabsToStorage();
  }

  /// Moves an existing empty tab to the end of the tab list and makes it active
  void moveEmptyTabToEnd() {
    final existingEmptyTabIndex = _tabs.indexWhere((tab) => tab.note == null);

    if (existingEmptyTabIndex != -1) {
      final existingEmptyTab = _tabs[existingEmptyTabIndex];
      _tabs.removeAt(existingEmptyTabIndex);
      _tabs.add(existingEmptyTab);
      _activeTab = existingEmptyTab;
      _saveTabsToStorage();

      // Diferir la notificación para evitar problemas con los controladores
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  Future<void> saveTabsToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tabsData = <Map<String, dynamic>>[];

      for (final tab in _tabs) {
        final tabData = <String, dynamic>{
          'tabId': tab.tabId,
          'searchQuery': tab.searchQuery,
          'isAdvancedSearch': tab.isAdvancedSearch,
          'isDirty': tab.isDirty,
          'isPinned': tab.isPinned,
          'isReadMode': tab.isReadMode,
          'isEditorCentered': tab.isEditorCentered,
          'lastAccessed': tab.lastAccessed.toIso8601String(),
        };

        if (tab.note != null) {
          tabData['noteId'] = tab.note!.id;
        }

        tabsData.add(tabData);
      }

      // Guardar índice de la pestaña activa
      final activeTabIndex =
          _activeTab != null ? _tabs.indexOf(_activeTab!) : -1;

      await prefs.setString('saved_tabs', jsonEncode(tabsData));
      await prefs.setInt('active_tab_index', activeTabIndex);
    } catch (e) {
      debugPrint('Error saving tabs: $e');
    }
  }

  Future<void> loadTabsFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tabsJson = prefs.getString('saved_tabs');
      final activeTabIndex = prefs.getInt('active_tab_index') ?? -1;

      if (tabsJson != null) {
        final tabsData = List<Map<String, dynamic>>.from(
          jsonDecode(tabsJson) as List,
        );

        final noteRepo = NoteRepository(DatabaseHelper());
        final loadedTabs = <EditorTab>[];

        for (final tabData in tabsData) {
          final noteId = tabData['noteId'] as int?;
          final tabId = tabData['tabId'] as String?;
          final searchQuery = tabData['searchQuery'] as String?;
          final isAdvancedSearch =
              tabData['isAdvancedSearch'] as bool? ?? false;
          final isDirty = tabData['isDirty'] as bool? ?? false;
          final isPinned = tabData['isPinned'] as bool? ?? false;
          final isReadMode = tabData['isReadMode'] as bool? ?? false;
          final isEditorCentered =
              tabData['isEditorCentered'] as bool? ?? false;
          final lastAccessed = DateTime.parse(
            tabData['lastAccessed'] as String,
          );

          Note? note;
          if (noteId != null) {
            note = await noteRepo.getNote(noteId);
          }

          if (note != null || tabId != null) {
            final tab = EditorTab(
              note: note,
              noteController: SearchTextEditingController(text: note?.content ?? ''),
              titleController: TextEditingController(text: note?.title ?? ''),
              searchQuery: searchQuery,
              isAdvancedSearch: isAdvancedSearch,
              isDirty: isDirty,
              isPinned: isPinned,
              isReadMode: isReadMode,
              isEditorCentered: isEditorCentered,
              lastAccessed: lastAccessed,
              tabId: tabId,
            );
            loadedTabs.add(tab);
          }
        }

        // Cerrar todas las pestañas existentes
        closeAllTabs();

        // Ensure pinned tabs come first when restoring order
        loadedTabs.sort((a, b) {
          if (a.isPinned && !b.isPinned) return -1;
          if (!a.isPinned && b.isPinned) return 1;
          return 0;
        });

        // Cargar las pestañas guardadas
        _tabs.addAll(loadedTabs);

        // Restaurar la pestaña activa
        if (activeTabIndex >= 0 && activeTabIndex < _tabs.length) {
          _activeTab = _tabs[activeTabIndex];
        } else if (_tabs.isNotEmpty) {
          _activeTab = _tabs.last;
        }

        // Diferir la notificación para evitar problemas con los controladores
        WidgetsBinding.instance.addPostFrameCallback((_) {
          notifyListeners();
        });
      }
    } catch (e) {
      debugPrint('Error loading tabs: $e');
    }
  }

  void _saveTabsToStorage() {
    saveTabsToStorage();
  }

  @override
  void dispose() {
    // Guardar pestañas antes de cerrar
    saveTabsToStorage();

    for (final tab in _tabs) {
      try {
        tab.noteController.dispose();
      } catch (e) {
        // Already disposed
      }
      try {
        tab.titleController.dispose();
      } catch (e) {
        // Already disposed
      }
    }
    super.dispose();
  }
}
