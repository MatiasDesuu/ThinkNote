import 'package:flutter/material.dart';
import 'note.dart';

class EditorTab {
  final Note? note;
  final TextEditingController noteController;
  final TextEditingController titleController;
  final String? searchQuery;
  final bool isAdvancedSearch;
  final bool isDirty;
  final bool isPinned;
  final bool isReadMode;
  final bool isEditorCentered; // Individual centered state for each tab
  final DateTime lastAccessed;
  final String? tabId; // Unique identifier for empty tabs

  const EditorTab({
    this.note,
    required this.noteController,
    required this.titleController,
    this.searchQuery,
    this.isAdvancedSearch = false,
    this.isDirty = false,
    this.isPinned = false,
    this.isReadMode = false,
    this.isEditorCentered = false,
    required this.lastAccessed,
    this.tabId,
  });

  EditorTab copyWith({
    Note? note,
    TextEditingController? noteController,
    TextEditingController? titleController,
    String? searchQuery,
    bool? isAdvancedSearch,
    bool? isDirty,
    bool? isPinned,
    bool? isReadMode,
    bool? isEditorCentered,
    DateTime? lastAccessed,
    String? tabId,
  }) {
    return EditorTab(
      note: note ?? this.note,
      noteController: noteController ?? this.noteController,
      titleController: titleController ?? this.titleController,
      searchQuery: searchQuery ?? this.searchQuery,
      isAdvancedSearch: isAdvancedSearch ?? this.isAdvancedSearch,
      isDirty: isDirty ?? this.isDirty,
      isPinned: isPinned ?? this.isPinned,
      isReadMode: isReadMode ?? this.isReadMode,
      isEditorCentered: isEditorCentered ?? this.isEditorCentered,
      lastAccessed: lastAccessed ?? this.lastAccessed,
      tabId: tabId ?? this.tabId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (note != null && other is EditorTab && other.note != null) {
      return other.note!.id == note!.id;
    }
    if (note == null && other is EditorTab && other.note == null) {
      return other.tabId == tabId;
    }
    return false;
  }

  @override
  int get hashCode {
    if (note != null) {
      return note!.id.hashCode;
    }
    return tabId.hashCode;
  }

  bool get isEmpty => note == null;
  String get displayTitle {
    if (note != null) {
      return note!.title.isEmpty ? 'Untitled' : note!.title;
    }
    return 'New Tab';
  }
}
