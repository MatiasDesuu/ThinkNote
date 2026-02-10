import 'dart:async';
import '../database/models/note.dart';
import '../database/repositories/note_repository.dart';
import '../database/database_helper.dart';
import '../database/database_service.dart';

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

  void dispose() {
    _databaseChangeSubscription.cancel();
    _tagsController.close();
    _isInitialized = false;
  }

  static List<String> extractTags(String text) {
    if (text.isEmpty) return [];

    if (_containsNoTag(text)) {
      return [];
    }

    final isScriptNote = _isScriptNote(text);

    final RegExp tagRegex = RegExp(r'#([a-zA-Z0-9_áéíóúÁÉÍÓÚñÑüÜ]+)');
    final matches = tagRegex.allMatches(text);

    final Set<String> uniqueTags = {};
    for (final match in matches) {
      if (match.groupCount > 0) {
        var tag = match.group(1)?.toLowerCase();
        if (tag != null && tag.isNotEmpty) {
          tag = _removeDiacritics(tag);

          if (isScriptNote && _isScriptSpecialTag(tag)) {
            continue;
          }
          uniqueTags.add(tag);
        }
      }
    }

    return uniqueTags.toList()..sort();
  }

  static bool _isScriptNote(String content) {
    final lines = content.split('\n');
    return lines.isNotEmpty && lines.first.trim() == "#script";
  }

  static bool _isScriptSpecialTag(String tag) {
    if (tag == 'script') return true;

    return RegExp(r'^\d+$').hasMatch(tag);
  }

  static bool _containsNoTag(String content) {
    return content.toLowerCase().contains('#notag');
  }

  Future<Map<String, int>> getAllTags() async {
    if (!_isInitialized) {
      await initialize();
    }
    return Map.from(_cachedTags);
  }

  Future<List<Note>> getNotesByTag(String tag) async {
    if (!_isInitialized) {
      await initialize();
    }

    final allNotes = await _noteRepository.getAllNotes();
    final normalizedTag = _removeDiacritics(tag.toLowerCase());

    return allNotes.where((note) {
      final contentTags = extractTags(note.content);
      final titleTags = extractTags(note.title);
      final allNoteTags = [...contentTags, ...titleTags];

      return allNoteTags.any((t) => t.toLowerCase() == normalizedTag);
    }).toList();
  }

  Future<void> _refreshTags() async {
    try {
      final allNotes = await _noteRepository.getAllNotes();
      final Map<String, int> tagCounts = {};

      for (final note in allNotes) {
        if (note.deletedAt != null) continue;

        if (note.content.contains('{{') || note.title.contains('{{')) continue;

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

  Map<String, int> getCachedTags() {
    return Map.from(_cachedTags);
  }

  static bool noteHasTag(Note note, String tag) {
    final normalizedTag = _removeDiacritics(tag.toLowerCase());
    final contentTags = extractTags(note.content);
    final titleTags = extractTags(note.title);
    final allNoteTags = [...contentTags, ...titleTags];

    return allNoteTags.any((t) => t.toLowerCase() == normalizedTag);
  }

  static List<String> getNoteTags(Note note) {
    final contentTags = extractTags(note.content);
    final titleTags = extractTags(note.title);
    final allTags = {...contentTags, ...titleTags};

    return allTags.toList()..sort();
  }

  static String _removeDiacritics(String str) {
    const withDia = 'áéíóúü';
    const withoutDia = 'aeiouu';

    for (int i = 0; i < withDia.length; i++) {
      str = str.replaceAll(withDia[i], withoutDia[i]);
    }
    return str;
  }
}
