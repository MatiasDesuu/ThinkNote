import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

class FilePickerService {
  static Future<Map<String, String>?> pickLocalFile() async {
    try {
      final FilePickerResult? result = await FilePicker.pickFiles(
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final fileName = p.basename(filePath);
        return {
          'name': fileName,
          'path': filePath,
        };
      }
    } catch (_) {}
    return null;
  }

  static Future<Map<String, String>?> pickLocalFolder() async {
    try {
      final String? directoryPath = await FilePicker.getDirectoryPath();

      if (directoryPath != null) {
        final folderName = p.basename(directoryPath);
        return {
          'name': folderName,
          'path': directoryPath,
        };
      }
    } catch (_) {}
    return null;
  }
}
