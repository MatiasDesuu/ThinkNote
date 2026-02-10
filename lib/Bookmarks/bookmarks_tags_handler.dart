import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_service.dart';
import '../database/models/bookmark_tag.dart';

class TagsHandlerDB {
  static final TagsHandlerDB _instance = TagsHandlerDB._internal();
  factory TagsHandlerDB() => _instance;
  TagsHandlerDB._internal();

  final DatabaseService _databaseService = DatabaseService();
  List<TagUrlPattern> _urlPatterns = [];

  Future<void> loadPatterns() async {
    try {
      _urlPatterns =
          await _databaseService.bookmarkService.getAllTagUrlPatterns();
    } catch (e) {
      print('Error loading URL patterns: $e');
      _urlPatterns = [];
    }
  }

  List<TagUrlPattern> get allPatterns => _urlPatterns;

  Future<List<String>> getTagsForUrl(String url) async {
    return await _databaseService.bookmarkService.getTagsForUrl(url);
  }

  Future<void> addTagMapping(String urlPattern, String tag) async {
    try {
      await _databaseService.bookmarkService.createTagUrlPattern(
        urlPattern,
        tag,
      );
      await loadPatterns();
    } catch (e) {
      print('Error adding tag mapping: $e');
      rethrow;
    }
  }

  Future<void> removeTagMapping(String urlPattern, String tag) async {
    try {
      final pattern = _urlPatterns.firstWhere(
        (p) => p.urlPattern == urlPattern && p.tag == tag,
        orElse: () => TagUrlPattern(id: -1, urlPattern: '', tag: ''),
      );

      if (pattern.id != null && pattern.id! > 0) {
        await _databaseService.bookmarkService.deleteTagUrlPattern(pattern.id!);
        await loadPatterns();
      }
    } catch (e) {
      print('Error removing tag mapping: $e');
      rethrow;
    }
  }

  Future<void> migrateFromJson() async {
    try {
      final jsonPatterns = await _getUrlPatternsFromJsonFile();
      if (jsonPatterns.isEmpty) return;

      for (final pattern in jsonPatterns) {
        final urlPattern = pattern['urlPattern'] ?? '';
        final tag = pattern['tag'] ?? '';

        if (urlPattern.isNotEmpty && tag.isNotEmpty) {
          await _databaseService.bookmarkService.createTagUrlPattern(
            urlPattern,
            tag,
          );
        }
      }

      final file = await _getTagsFile();
      if (await file.exists()) {
        await file.delete();
      }

      await loadPatterns();
    } catch (e) {
      print('Error migrating URL patterns from JSON: $e');
    }
  }

  Future<List<Map<String, String>>> _getUrlPatternsFromJsonFile() async {
    try {
      final file = await _getTagsFile();
      if (!await file.exists()) {
        return [];
      }

      final String content = await file.readAsString();
      if (content.isEmpty) {
        return [];
      }

      final List<dynamic> decodedPatterns = json.decode(content);
      final patterns =
          decodedPatterns.map((pattern) {
            return {
              'urlPattern': pattern['urlPattern']?.toString() ?? '',
              'tag': pattern['tag']?.toString() ?? '',
            };
          }).toList();

      return patterns;
    } catch (e) {
      print('Error reading URL patterns from JSON file: $e');
      return [];
    }
  }

  Future<File> _getTagsFile() async {
    final prefs = await SharedPreferences.getInstance();
    final storageDirectoryPath = prefs.getString('notes_directory');
    if (storageDirectoryPath == null) {
      throw Exception('Directory not configured');
    }

    final bookmarksDir = Directory(p.join(storageDirectoryPath, '.bookmarks'));
    if (!await bookmarksDir.exists()) {
      await bookmarksDir.create(recursive: true);
    }

    return File(p.join(bookmarksDir.path, 'tags.json'));
  }
}
