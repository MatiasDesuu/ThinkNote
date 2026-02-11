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
    final existingTabIndex = _tabs.indexWhere(
      (tab) => tab.note != null && tab.note!.id == note.id,
    );

    if (existingTabIndex != -1) {
      final existingTab = _tabs[existingTabIndex];
      final updatedTab = existingTab.copyWith(
        searchQuery: searchQuery,
        isAdvancedSearch: isAdvancedSearch,
        lastAccessed: DateTime.now(),
      );
      _tabs[existingTabIndex] = updatedTab;
      _activeTab = updatedTab;
    } else {
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  void createEmptyTab() {
    if (hasEmptyTab) {
      moveEmptyTabToEnd();
    } else {
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

      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  void assignNoteToActiveTab(Note note) {
    if (_activeTab == null || _activeTab!.note != null) return;

    final existingTabIndex = _tabs.indexWhere(
      (tab) => tab.note != null && tab.note!.id == note.id,
    );

    if (existingTabIndex != -1) {
      final emptyTab = _activeTab!;
      _activeTab = _tabs[existingTabIndex];
      _tabs.remove(emptyTab);
      _saveTabsToStorage();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          emptyTab.noteController.dispose();
        } catch (e) {
          // Ignore errors when disposing controllers
        }
        try {
          emptyTab.titleController.dispose();
        } catch (e) {
          // Ignore errors when disposing controllers
        }
        notifyListeners();
      });
      return;
    }

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        oldNoteController.dispose();
      } catch (e) {
        // Ignore errors when disposing controllers
      }
      try {
        oldTitleController.dispose();
      } catch (e) {
        // Ignore errors when disposing controllers
      }
      notifyListeners();
    });
  }

  void replaceNoteInActiveTab(Note note) {
    if (_activeTab == null) return;

    final existingTabIndex = _tabs.indexWhere(
      (tab) => tab.note != null && tab.note!.id == note.id,
    );

    if (existingTabIndex != -1 && _tabs[existingTabIndex] != _activeTab) {
      final currentTab = _activeTab!;
      _activeTab = _tabs[existingTabIndex];
      _tabs.remove(currentTab);
      _saveTabsToStorage();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          currentTab.noteController.dispose();
        } catch (e) {
          // Ignore errors when disposing controllers
        }
        try {
          currentTab.titleController.dispose();
        } catch (e) {
          // Ignore errors when disposing controllers
        }
        notifyListeners();
      });
      return;
    }

    final activeTabIndex = _tabs.indexOf(_activeTab!);
    if (activeTabIndex == -1) return;

    final oldNoteController = _activeTab!.noteController;
    final oldTitleController = _activeTab!.titleController;

    final updatedTab = _activeTab!.copyWith(
      note: note,
      noteController: SearchTextEditingController(text: note.content),
      titleController: TextEditingController(text: note.title),
      lastAccessed: DateTime.now(),
      isDirty: false,
    );

    _tabs[activeTabIndex] = updatedTab;
    _activeTab = updatedTab;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      oldNoteController.dispose();
      oldTitleController.dispose();
      notifyListeners();
    });
  }

  void openTabWithNotebookChange(
    Note note, {
    String? searchQuery,
    bool isAdvancedSearch = false,
  }) {
    if (onNotebookChangeRequested != null) {
      onNotebookChangeRequested!.call(note);
    } else {}

    openTab(note, searchQuery: searchQuery, isAdvancedSearch: isAdvancedSearch);
  }

  void replaceNoteInActiveTabWithNotebookChange(Note note) {
    if (onNotebookChangeRequested != null) {
      onNotebookChangeRequested!.call(note);
    } else {}

    replaceNoteInActiveTab(note);
  }

  void selectTab(EditorTab tab) {
    if (_tabs.contains(tab)) {
      _activeTab = tab;
      _saveTabsToStorage();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  void togglePin(EditorTab tab) {
    final index = _tabs.indexOf(tab);
    if (index == -1) return;

    final updated = tab.copyWith(isPinned: !tab.isPinned);

    _tabs[index] = updated;

    if (updated.isPinned) {
      _tabs.removeAt(index);
      _tabs.insert(0, updated);
    } else {
      _tabs.removeAt(index);
      final firstUnpinned = _tabs.indexWhere((t) => !t.isPinned);
      final insertIndex = firstUnpinned == -1 ? _tabs.length : firstUnpinned;
      _tabs.insert(insertIndex, updated);
    }

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

      if (_activeTab == tab) {
        if (_tabs.isNotEmpty) {
          _activeTab = _tabs.last;
        } else {
          _activeTab = null;
        }
      }

      _saveTabsToStorage();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          noteController.dispose();
        } catch (e) {
          // Ignore errors when disposing controllers
        }
        try {
          titleController.dispose();
        } catch (e) {
          // Ignore errors when disposing controllers
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final (noteController, titleController) in controllersToDispose) {
        try {
          noteController.dispose();
        } catch (e) {
          // Ignore errors when disposing controllers
        }
        try {
          titleController.dispose();
        } catch (e) {
          // Ignore errors when disposing controllers
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

    _tabs.removeWhere((tab) => tab != keepTab);

    if (_activeTab != null && !_tabs.contains(_activeTab)) {
      if (_tabs.isNotEmpty) {
        _activeTab = _tabs.last;
      } else {
        _activeTab = null;
      }
    }

    _saveTabsToStorage();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final (noteController, titleController) in controllersToDispose) {
        try {
          noteController.dispose();
        } catch (e) {
          // Ignore errors when disposing controllers
        }
        try {
          titleController.dispose();
        } catch (e) {
          // Ignore errors when disposing controllers
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

      WidgetsBinding.instance.addPostFrameCallback((_) {
        oldNoteController.dispose();
        oldTitleController.dispose();
        notifyListeners();
      });
    }
  }

  void setTabSearchQuery(
    EditorTab tab,
    String? query, {
    bool isAdvanced = false,
  }) {
    final index = _tabs.indexOf(tab);
    if (index != -1) {
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
    }
  }

  void setTabSplitView(EditorTab tab, bool isSplitView) {
    final index = _tabs.indexOf(tab);
    if (index != -1) {
      final updatedTab = tab.copyWith(isSplitView: isSplitView);
      _tabs[index] = updatedTab;

      if (_activeTab == tab) {
        _activeTab = updatedTab;
      }

      _saveTabsToStorage();
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

      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          oldNoteController.dispose();
        } catch (e) {
          // Ignore errors when disposing controllers
        }
        try {
          oldTitleController.dispose();
        } catch (e) {
          // Ignore errors when disposing controllers
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
      final updatedTab = tab.copyWith(note: updatedNote);

      _tabs[index] = updatedTab;

      if (_activeTab?.note?.id == updatedNote.id) {
        _activeTab = updatedTab;
      }

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

    final movingTab = _tabs[oldIndex];
    final wasPinned = movingTab.isPinned;
    final pinnedCount = _tabs.where((t) => t.isPinned).length;

    final allowedStart = wasPinned ? 0 : pinnedCount;
    final allowedEnd = wasPinned ? (pinnedCount - 1) : (_tabs.length - 1);

    if (newIndex < allowedStart || newIndex > allowedEnd) {
      return;
    }

    final tab = _tabs.removeAt(oldIndex);
    _tabs.insert(newIndex, tab);

    notifyListeners();

    _saveTabsToStorage();
  }

  void moveEmptyTabToEnd() {
    final existingEmptyTabIndex = _tabs.indexWhere((tab) => tab.note == null);

    if (existingEmptyTabIndex != -1) {
      final existingEmptyTab = _tabs[existingEmptyTabIndex];
      _tabs.removeAt(existingEmptyTabIndex);
      _tabs.add(existingEmptyTab);
      _activeTab = existingEmptyTab;
      _saveTabsToStorage();

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
          'isSplitView': tab.isSplitView,
          'lastAccessed': tab.lastAccessed.toIso8601String(),
        };

        if (tab.note != null) {
          tabData['noteId'] = tab.note!.id;
        }

        tabsData.add(tabData);
      }

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
          final isSplitView = tabData['isSplitView'] as bool? ?? false;
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
              noteController: SearchTextEditingController(
                text: note?.content ?? '',
              ),
              titleController: TextEditingController(text: note?.title ?? ''),
              searchQuery: searchQuery,
              isAdvancedSearch: isAdvancedSearch,
              isDirty: isDirty,
              isPinned: isPinned,
              isReadMode: isReadMode,
              isEditorCentered: isEditorCentered,
              isSplitView: isSplitView,
              lastAccessed: lastAccessed,
              tabId: tabId,
            );
            loadedTabs.add(tab);
          }
        }

        closeAllTabs();

        loadedTabs.sort((a, b) {
          if (a.isPinned && !b.isPinned) return -1;
          if (!a.isPinned && b.isPinned) return 1;
          return 0;
        });

        _tabs.addAll(loadedTabs);

        if (activeTabIndex >= 0 && activeTabIndex < _tabs.length) {
          _activeTab = _tabs[activeTabIndex];
        } else if (_tabs.isNotEmpty) {
          _activeTab = _tabs.last;
        }

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
    saveTabsToStorage();

    for (final tab in _tabs) {
      try {
        tab.noteController.dispose();
      } catch (e) {
        // Ignore errors when disposing controllers
      }
      try {
        tab.titleController.dispose();
      } catch (e) {
        // Ignore errors when disposing controllers
      }
    }
    super.dispose();
  }
}
