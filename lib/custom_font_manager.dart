import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';

class CustomFontManager {
  static const String _customFontsKey = 'custom_fonts_list';

  static final List<String> customFonts = [];

  static final Map<String, String> _fontPaths = {};

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final fontsJson = prefs.getString(_customFontsKey);

    if (fontsJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(fontsJson);
        for (var entry in decoded.entries) {
          final fontFamily = entry.key;
          final filePath = entry.value.toString();

          if (await File(filePath).exists()) {
            await _loadFontIntoEngine(fontFamily, filePath);
            customFonts.add(fontFamily);
            _fontPaths[fontFamily] = filePath;
          }
        }
      } catch (e) {
        print('Error loading custom fonts: $e');
      }
    }
  }

  static Future<String?> pickAndLoadFont() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['ttf', 'otf'],
      );

      if (result != null && result.files.single.path != null) {
        final originalFile = File(result.files.single.path!);
        final fileName = result.files.single.name;

        final fontFamily = path.basenameWithoutExtension(fileName);

        if (customFonts.contains(fontFamily)) {
          return fontFamily;
        }

        final appDir = await getApplicationDocumentsDirectory();
        final fontsDir = Directory(path.join(appDir.path, 'custom_fonts'));
        if (!await fontsDir.exists()) {
          await fontsDir.create(recursive: true);
        }

        final newFilePath = path.join(fontsDir.path, fileName);
        await originalFile.copy(newFilePath);

        await _loadFontIntoEngine(fontFamily, newFilePath);

        customFonts.add(fontFamily);
        _fontPaths[fontFamily] = newFilePath;
        await _saveCustomFonts();

        return fontFamily;
      }
    } catch (e) {
      print('Error picking/loading font: $e');
    }
    return null;
  }

  static Future<void> _loadFontIntoEngine(
    String fontFamily,
    String filePath,
  ) async {
    final file = File(filePath);
    final fontBytes = await file.readAsBytes();
    final fontLoader = FontLoader(fontFamily);
    fontLoader.addFont(Future.value(ByteData.view(fontBytes.buffer)));
    await fontLoader.load();
  }

  static Future<void> _saveCustomFonts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customFontsKey, jsonEncode(_fontPaths));
  }
}
