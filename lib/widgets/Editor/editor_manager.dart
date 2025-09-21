import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../database/models/note.dart';
import '../../database/repositories/note_repository.dart';
import '../../database/database_helper.dart';
import '../../services/tab_manager.dart';

class EditorManager {
  static const String _editorCenteredKey = 'editor_centered';

  static Future<bool> getEditorCentered() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_editorCenteredKey) ?? false;
  }

  static Future<void> setEditorCentered(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_editorCenteredKey, value);
  }

  static Future<void> saveNote({
    required Note selectedNote,
    required TextEditingController titleController,
    required TextEditingController noteController,
    required Function() onUpdateItems,
  }) async {
    final dbHelper = DatabaseHelper();
    final noteRepository = NoteRepository(dbHelper);

    try {
      final updatedNote = Note(
        id: selectedNote.id,
        title: titleController.text,
        content: noteController.text,
        notebookId: selectedNote.notebookId,
        createdAt: selectedNote.createdAt,
        updatedAt: DateTime.now(),
        isFavorite: selectedNote.isFavorite,
        tags: selectedNote.tags,
        orderIndex: selectedNote.orderIndex,
        isTask: selectedNote.isTask,
        isCompleted: selectedNote.isCompleted,
      );

      await noteRepository.updateNote(updatedNote);
      onUpdateItems();
    } catch (e) {
      debugPrint('Error saving note: $e');
    }
  }

  static Future<Timer?> configureAutoSave({
    required TextEditingController noteController,
    required TextEditingController titleController,
    required Future<void> Function() onSave,
    Timer? debounceNote,
    Timer? debounceTitle,
  }) async {
    debounceNote?.cancel();
    return Timer(const Duration(seconds: 1), () async {
      await onSave();
    });
  }

  /// Handles note link taps - opens note in current tab or new tab
  static void handleNoteLinkTap(
    Note targetNote,
    bool openInNewTab,
    TabManager tabManager,
  ) {
    if (openInNewTab) {
      // Open in new tab (middle click or Ctrl+click)
      tabManager.openTab(targetNote);
    } else {
      // Open in current tab (left click)
      tabManager.replaceNoteInActiveTab(targetNote);
    }
  }
}
