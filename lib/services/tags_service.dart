import 'dart:async';
import '../database/models/note.dart';
import '../database/repositories/note_repository.dart';
import '../database/database_helper.dart';
import '../database/database_service.dart';

/// Service for managing and extracting tags from notes
/// Tags are identified by the # symbol followed by alphanumeric characters
class TagsService {
  static final TagsService _instance = TagsService._internal();
  factory TagsService() => _instance;
  TagsService._internal();

  final _tagsController = StreamController<Map<String, int>>.broadcast();
  Stream<Map<String, int>> get tagsStream => _tagsController.stream;

  late final NoteRepository _noteRepository;
  late final StreamSubscription<void> _databaseChangeSubscription;
  Map<String, int> _cachedTags = {};
  bool _isInitialized = false;

  /// Initialize the tags service
  Future<void> initialize() async {
    if (_isInitialized) return;

    _noteRepository = NoteRepository(DatabaseHelper());
    _databaseChangeSubscription = DatabaseService().onDatabaseChanged.listen((
      _,
    ) {
      _refreshTags();
    });

    await _refreshTags();
    _isInitialized = true;
  }

  /// Dispose the service and clean up resources
  void dispose() {
    _databaseChangeSubscription.cancel();
    _tagsController.close();
    _isInitialized = false;
  }

  /// Extract all tags from a given text
  /// Tags are identified by # followed by alphanumeric characters (including underscores)
  /// Example: "This is a note about #books and #reading_list" -> ["books", "reading_list"]
  /// Excludes #script and numeric tags (#1, #2, etc.) when the text is a script
  /// Excludes all tags if the note contains #notag
  static List<String> extractTags(String text) {
    if (text.isEmpty) return [];

    // Check if this note contains #notag - if so, exclude all tags
    if (_containsNoTag(text)) {
      return [];
    }

    // Check if this is a script note (starts with #script)
    final isScriptNote = _isScriptNote(text);

    // Regular expression to match hashtags
    // Matches # followed by one or more alphanumeric characters, underscores, or Spanish accented characters
    final RegExp tagRegex = RegExp(r'#([a-zA-Z0-9_áéíóúÁÉÍÓÚñÑüÜ]+)');
    final matches = tagRegex.allMatches(text);

    // Extract unique tags (case-insensitive)
    final Set<String> uniqueTags = {};
    for (final match in matches) {
      if (match.groupCount > 0) {
        var tag = match.group(1)?.toLowerCase();
        if (tag != null && tag.isNotEmpty) {
          // Normalize tag by removing diacritics
          tag = _removeDiacritics(tag);

          // If it's a script note, exclude special tags
          if (isScriptNote && _isScriptSpecialTag(tag)) {
            continue;
          }
          uniqueTags.add(tag);
        }
      }
    }

    return uniqueTags.toList()..sort();
  }

  /// Check if the text represents a script note
  static bool _isScriptNote(String content) {
    final lines = content.split('\n');
    return lines.isNotEmpty && lines.first.trim() == "#script";
  }

  /// Check if a tag is a special script tag that should be excluded
  /// Returns true for #script and numeric tags like #1, #2, #3, etc.
  static bool _isScriptSpecialTag(String tag) {
    // Exclude "script"
    if (tag == 'script') return true;

    // Exclude numeric tags (e.g., "1", "2", "3")
    return RegExp(r'^\d+$').hasMatch(tag);
  }

  /// Check if the text contains #notag tag
  static bool _containsNoTag(String content) {
    return content.toLowerCase().contains('#notag');
  }

  /// Get all tags from all notes with their occurrence count
  /// Returns a map of tag name to count
  Future<Map<String, int>> getAllTags() async {
    if (!_isInitialized) {
      await initialize();
    }
    return Map.from(_cachedTags);
  }

  /// Get all notes that contain a specific tag
  Future<List<Note>> getNotesByTag(String tag) async {
    if (!_isInitialized) {
      await initialize();
    }

    final allNotes = await _noteRepository.getAllNotes();
    final normalizedTag = _removeDiacritics(tag.toLowerCase());

    return allNotes.where((note) {
      // Search in both title and content
      final contentTags = extractTags(note.content);
      final titleTags = extractTags(note.title);
      final allNoteTags = [...contentTags, ...titleTags];

      return allNoteTags.any((t) => t.toLowerCase() == normalizedTag);
    }).toList();
  }

  /// Refresh the cached tags from the database
  Future<void> _refreshTags() async {
    try {
      final allNotes = await _noteRepository.getAllNotes();
      final Map<String, int> tagCounts = {};

      for (final note in allNotes) {
        // Skip deleted notes
        if (note.deletedAt != null) continue;

        // Skip template notes (those containing template variables)
        if (note.content.contains('{{') || note.title.contains('{{')) continue;

        // Extract tags from both title and content
        final contentTags = extractTags(note.content);
        final titleTags = extractTags(note.title);
        final allNoteTags = {...contentTags, ...titleTags};

        for (final tag in allNoteTags) {
          tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
        }
      }

      _cachedTags = tagCounts;
      _tagsController.add(Map.from(_cachedTags));
    } catch (e) {
      print('Error refreshing tags: $e');
    }
  }

  /// Get the cached tags without refreshing
  Map<String, int> getCachedTags() {
    return Map.from(_cachedTags);
  }

  /// Check if a note contains a specific tag
  static bool noteHasTag(Note note, String tag) {
    final normalizedTag = _removeDiacritics(tag.toLowerCase());
    final contentTags = extractTags(note.content);
    final titleTags = extractTags(note.title);
    final allNoteTags = [...contentTags, ...titleTags];

    return allNoteTags.any((t) => t.toLowerCase() == normalizedTag);
  }

  /// Get all tags from a specific note
  static List<String> getNoteTags(Note note) {
    final contentTags = extractTags(note.content);
    final titleTags = extractTags(note.title);
    final allTags = {...contentTags, ...titleTags};

    return allTags.toList()..sort();
  }

  /// Remove diacritics from a string (e.g., "rápido" -> "rapido")
  static String _removeDiacritics(String str) {
    const withDia = 'áéíóúü';
    const withoutDia = 'aeiouu';

    for (int i = 0; i < withDia.length; i++) {
      str = str.replaceAll(withDia[i], withoutDia[i]);
    }
    return str;
  }
}
