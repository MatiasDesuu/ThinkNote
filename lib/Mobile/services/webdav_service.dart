import 'dart:io' as io;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webdav_client/webdav_client.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../database/database_helper.dart';
import '../../database/database_config.dart';

class WebDAVService {
  static const String _dbFileName = 'thinknote.db';
  static const int _syncToleranceSeconds = 0;

  late final dynamic _client;
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

    _client = newClient(url, user: username, password: password);

    _client.setHeaders({'content-type': 'application/octet-stream'});

    _client.setConnectTimeout(8000);
    _client.setSendTimeout(8000);
    _client.setReceiveTimeout(8000);

    _isInitialized = true;
  }

  Future<String> _getDatabasePath() async {
    return await DatabaseConfig.databasePath;
  }

  bool _areDatesClose(DateTime date1, DateTime date2) {
    final difference = date1.difference(date2).abs();
    return difference.inSeconds <= _syncToleranceSeconds;
  }

  Future<void> sync({
    void Function(String step, double progress, String message)? onProgress,
  }) async {
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
        onProgress?.call('uploading', 0.5, 'Uploading local database...');
        await _uploadLocalFile(dbPath);
        onProgress?.call('finalizing', 0.9, 'Finalizing...');
        return;
      }

      onProgress?.call('comparing', 0.3, 'Comparing versions...');

      final localLastModified = await _dbHelper.getLastModified();
      final tempPath = '$dbPath.temp';
      DatabaseHelper? tempDb;
      try {
        await _client.read2File('/$_dbFileName', tempPath);
        tempDb = DatabaseHelper();
        await tempDb.initialize(tempPath);
        final remoteLastModified = await tempDb.getLastModified();

        if (_areDatesClose(localLastModified, remoteLastModified)) {
          return;
        }

        if (localLastModified.isAfter(remoteLastModified)) {
          onProgress?.call('uploading', 0.6, 'Uploading changes...');
          await _uploadLocalFile(dbPath);
        } else if (remoteLastModified.isAfter(localLastModified)) {
          onProgress?.call('downloading', 0.6, 'Downloading changes...');
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
        onProgress?.call('finalizing', 0.9, 'Finalizing...');
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

  Future<dynamic> _getRemoteFile() async {
    try {
      final files = await _client.readDir('/');
      for (var file in files) {
        if (file.name == _dbFileName) {
          return file;
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
      await _client.writeFromFile(dbPath, '/$_dbFileName');

      final remoteFile = await _getRemoteFile();
      if (remoteFile == null) {
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

      await _client.read2File('/$_dbFileName', dbPath);

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
      final client = newClient(url, user: username, password: password);

      client.setConnectTimeout(5000);
      client.setSendTimeout(5000);
      client.setReceiveTimeout(5000);

      await client.ping();
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
      await _client.read2File('/$_dbFileName', dbPath);

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
        throw Exception(
          'Error downloading remote file and failed to recover: $e',
        );
      }
      throw Exception('Error downloading remote file: $e');
    }
  }
}
