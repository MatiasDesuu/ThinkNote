import 'dart:io' as io;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:xml/xml.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../database/database_helper.dart';
import '../../database/database_config.dart';

class WebDAVService {
  static const String _dbFileName = 'thinknote.db';
  static const int _syncToleranceSeconds = 0;

  late Dio _dio;
  bool _isInitialized = false;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  WebDAVService();

  Future<bool> _checkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return !connectivityResult.contains(ConnectivityResult.none);
    } catch (e) {
      return true;
    }
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('webdav_url');
    final username = prefs.getString('webdav_username');
    final password = prefs.getString('webdav_password');

    if (url == null || username == null || password == null) {
      throw Exception('WebDAV not configured');
    }

    final auth = base64Encode(utf8.encode('$username:$password'));
    _dio = Dio(BaseOptions(
      baseUrl: url,
      headers: {
        'Authorization': 'Basic $auth',
      },
      connectTimeout: Duration(seconds: 8),
      sendTimeout: Duration(seconds: 8),
      receiveTimeout: Duration(seconds: 8),
    ));

    _isInitialized = true;
  }

  Future<String> _getDatabasePath() async {
    return await DatabaseConfig.databasePath;
  }

  bool _areDatesClose(DateTime date1, DateTime date2) {
    final difference = date1.difference(date2).abs();
    return difference.inSeconds <= _syncToleranceSeconds;
  }

  Future<void> sync() async {
    if (!await _checkConnectivity()) {
      return;
    }

    if (!_isInitialized) {
      await initialize();
    }

    try {
      final dbPath = await _getDatabasePath();

      final remoteFile = await _getRemoteFile();
      if (remoteFile == null) {
        await _uploadLocalFile(dbPath);
        return;
      }

      final localLastModified = await _dbHelper.getLastModified();
      final tempPath = '$dbPath.temp';
      DatabaseHelper? tempDb;
      try {
        final response = await _dio.get('/$_dbFileName', options: Options(responseType: ResponseType.bytes));
        await io.File(tempPath).writeAsBytes(response.data);
        tempDb = DatabaseHelper();
        await tempDb.initialize(tempPath);
        final remoteLastModified = await tempDb.getLastModified();

        if (_areDatesClose(localLastModified, remoteLastModified)) {
          return;
        }

        if (localLastModified.isAfter(remoteLastModified)) {
          await _uploadLocalFile(dbPath);
        } else if (remoteLastModified.isAfter(localLastModified)) {
          await _downloadRemoteFile(dbPath);

          await _dbHelper.dispose();
          await _dbHelper.initialize(dbPath);

          final db = await _dbHelper.database;
          final result = db.select(
            'SELECT last_modified FROM sync_info WHERE id = 1',
          );
          if (result.isEmpty) {
            throw Exception('Database initialized but sync_info is empty');
          }
        }
      } finally {
        if (tempDb != null) {
          await tempDb.close();
        }
        final tempFile = io.File(tempPath);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
      // Notify database changes after successful sync
      DatabaseHelper.notifyDatabaseChanged();
    } catch (e) {
      if (e is io.SocketException) {
        return;
      }
      throw Exception('Error during sync: $e');
    }
  }

  Future<Map<String, dynamic>?> _getRemoteFile() async {
    try {
      final response = await _dio.request('/', options: Options(method: 'PROPFIND', headers: {'Depth': '1'}));
      final xml = XmlDocument.parse(response.data as String);
      final responses = xml.findAllElements('d:response', namespace: 'DAV:');
      for (var res in responses) {
        final href = res.findElements('d:href', namespace: 'DAV:').first.innerText;
        if (href == '/$_dbFileName' || href == '/$_dbFileName/') {
          final propstat = res.findElements('d:propstat', namespace: 'DAV:').first;
          final prop = propstat.findElements('d:prop', namespace: 'DAV:').first;
          final mtimeElement = prop.findElements('d:getlastmodified', namespace: 'DAV:');
          if (mtimeElement.isNotEmpty) {
            final mtime = DateTime.parse(mtimeElement.first.innerText);
            return {'mtime': mtime};
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _uploadLocalFile(String dbPath) async {
    final localFile = io.File(dbPath);
    if (!await localFile.exists()) {
      throw Exception('Local file not found at $dbPath');
    }

    try {
      final bytes = await localFile.readAsBytes();
      await _dio.put('/$_dbFileName', data: bytes, options: Options(headers: {'Content-Type': 'application/octet-stream'}));

      // Verify upload by checking if the file exists
      try {
        await _dio.head('/$_dbFileName');
      } catch (e) {
        throw Exception('Upload failed: Remote file not found after upload');
      }
    } catch (e) {
      throw Exception('Error uploading file: $e');
    }
  }

  Future<void> _downloadRemoteFile(String dbPath) async {
    final localFile = io.File(dbPath);
    final backupPath = '$dbPath.backup';

    try {
      if (await localFile.exists()) {
        await localFile.copy(backupPath);
        await _dbHelper.close();
      }

      final response = await _dio.get('/$_dbFileName', options: Options(responseType: ResponseType.bytes));
      await localFile.writeAsBytes(response.data);

      if (!await localFile.exists()) {
        throw Exception('Downloaded file not found at $dbPath');
      }

      await _dbHelper.initialize(dbPath);

      final db = await _dbHelper.database;
      final result = db.select(
        'SELECT last_modified FROM sync_info WHERE id = 1',
      );
      if (result.isEmpty) {
        throw Exception('Database initialized but sync_info is empty');
      }
    } catch (e) {
      if (await io.File(backupPath).exists()) {
        await io.File(backupPath).copy(dbPath);
        await _dbHelper.initialize(dbPath);
      }

      throw Exception('Error downloading remote file: $e');
    } finally {
      final backupFile = io.File(backupPath);
      if (await backupFile.exists()) {
        await backupFile.delete();
      }
    }
  }

  Future<bool> testConnection(
    String url,
    String username,
    String password,
  ) async {
    try {
      final auth = base64Encode(utf8.encode('$username:$password'));
      final dio = Dio(BaseOptions(
        baseUrl: url,
        headers: {
          'Authorization': 'Basic $auth',
        },
        connectTimeout: Duration(seconds: 5),
        sendTimeout: Duration(seconds: 5),
        receiveTimeout: Duration(seconds: 5),
      ));

      await dio.head('/');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Public method to upload the local database to the WebDAV server
  Future<void> uploadLocalDatabase() async {
    if (!_isInitialized) {
      await initialize();
    }

    final dbPath = await _getDatabasePath();
    await _uploadLocalFile(dbPath);
  }

  /// Public method to download the database from the WebDAV server
  /// Forces a download from server to local, similar to sync but prioritizing remote
  Future<void> downloadRemoteDatabase() async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!await _checkConnectivity()) {
      throw Exception('No internet connectivity');
    }

    final dbPath = await _getDatabasePath();
    
    // Check if remote file exists
    final remoteFile = await _getRemoteFile();
    if (remoteFile == null) {
      throw Exception('No database found on server');
    }

    // Force download without backup - close database first
    await _dbHelper.close();
    
    try {
      // Download directly, overwriting local file
      final response = await _dio.get('/$_dbFileName', options: Options(responseType: ResponseType.bytes));
      await io.File(dbPath).writeAsBytes(response.data);
      
      // Reinitialize database helper with the new file
      await _dbHelper.initialize(dbPath);
      
      // Verify the download was successful
      final localFile = io.File(dbPath);
      if (!await localFile.exists()) {
        throw Exception('Downloaded file not found at $dbPath');
      }

      // Verify database integrity
      final db = await _dbHelper.database;
      final result = db.select(
        'SELECT last_modified FROM sync_info WHERE id = 1',
      );
      if (result.isEmpty) {
        throw Exception('Database downloaded but sync_info is empty');
      }
    } catch (e) {
      // Try to reinitialize with whatever file exists
      try {
        await _dbHelper.initialize(dbPath);
      } catch (initError) {
        // If that fails too, this is a serious error
        throw Exception('Error downloading remote file and failed to recover: $e');
      }
      throw Exception('Error downloading remote file: $e');
    }
  }
}
