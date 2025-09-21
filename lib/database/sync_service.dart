import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import '../Mobile/services/webdav_service.dart';
import 'dart:developer' as developer;

class SyncService {
  static final SyncService _instance = SyncService._internal();
  final WebDAVService _webdavService = WebDAVService();
  Timer? _debounceTimer;
  bool _isSyncing = false;
  bool _isInitialized = false;
  StreamSubscription? _dbChangeSubscription;
  int _changeCount = 0;
  DateTime? _lastSyncTime;
  static const Duration _minSyncInterval = Duration(seconds: 10);
  static const int _minChangesForSync = 1;
  bool _ignoreChanges = false;

  factory SyncService() => _instance;

  SyncService._internal();

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final isEnabled = prefs.getBool('webdav_enabled') ?? false;

      if (!isEnabled) {
        return;
      }

      await _webdavService.initialize();
      _isInitialized = true;

      _dbChangeSubscription = DatabaseHelper.onDatabaseChanged.listen((_) {
        if (_ignoreChanges) {
          return;
        }
        _changeCount++;
        _triggerSync();
      });

      await forceSync();
    } catch (e) {
      developer.log('Error initializing sync service: $e', name: 'SyncService');
    }
  }

  void _triggerSync() {
    if (!_isInitialized) return;

    // Cancelar el timer anterior si existe
    _debounceTimer?.cancel();

    // Verificar si ha pasado suficiente tiempo desde la última sincronización
    final now = DateTime.now();
    if (_lastSyncTime != null &&
        now.difference(_lastSyncTime!) < _minSyncInterval &&
        _changeCount < _minChangesForSync) {
      return;
    }

    // Crear un nuevo timer
    _debounceTimer = Timer(const Duration(seconds: 2), () async {
      if (!_isSyncing && _changeCount >= _minChangesForSync) {
        await _performSync();
      }
    });
  }

  Future<void> _performSync() async {
    if (_isSyncing || !_isInitialized) return;

    try {
      _isSyncing = true;
      _ignoreChanges = true;
      await _webdavService.sync();
      _lastSyncTime = DateTime.now();
      _changeCount = 0;

    } catch (e) {
      developer.log('Error during sync: $e', name: 'SyncService');
    } finally {
      _isSyncing = false;
      _ignoreChanges = false;
    }
  }

  Future<void> forceSync() async {
    if (!_isInitialized) {
      try {
        await initialize();
      } catch (e) {
        developer.log(
          'Error initializing sync service for force sync: $e',
          name: 'SyncService',
        );
        rethrow;
      }
    }

    _changeCount = _minChangesForSync; // Forzar al menos un cambio
    await _performSync();
  }

  Future<Map<String, dynamic>> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'url': prefs.getString('webdav_url') ?? '',
      'username': prefs.getString('webdav_username') ?? '',
      'password': prefs.getString('webdav_password') ?? '',
      'enabled': prefs.getBool('webdav_enabled') ?? false,
    };
  }

  Future<void> saveSettings({
    required String url,
    required String username,
    required String password,
    required bool enabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('webdav_url', url);
    await prefs.setString('webdav_username', username);
    await prefs.setString('webdav_password', password);
    await prefs.setBool('webdav_enabled', enabled);

    if (enabled) {
      await _webdavService.initialize();
    }
  }

  Future<bool> testConnection() async {
    try {
      // Obtener las credenciales actuales
      final prefs = await SharedPreferences.getInstance();
      final url = prefs.getString('webdav_url') ?? '';
      final username = prefs.getString('webdav_username') ?? '';
      final password = prefs.getString('webdav_password') ?? '';

      // Verificar que las credenciales no estén vacías
      if (url.isEmpty || username.isEmpty || password.isEmpty) {
        developer.log(
          'Missing credentials for connection test',
          name: 'SyncService',
        );
        return false;
      }

      // Intentar una operación real de WebDAV
      return await _webdavService.testConnection(url, username, password);
    } catch (e) {
      developer.log('Error testing connection: $e', name: 'SyncService');
      return false;
    }
  }

  /// Upload the local database to the WebDAV server
  Future<void> uploadLocalDatabase() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      _ignoreChanges = true;
      await _webdavService.uploadLocalDatabase();
      developer.log('Local database uploaded successfully', name: 'SyncService');
    } catch (e) {
      developer.log('Error uploading local database: $e', name: 'SyncService');
      rethrow;
    } finally {
      _ignoreChanges = false;
    }
  }

  /// Download the database from the WebDAV server
  Future<void> downloadRemoteDatabase() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      _ignoreChanges = true;
      developer.log('Starting forced download from server...', name: 'SyncService');
      await _webdavService.downloadRemoteDatabase();
      developer.log('Remote database downloaded and applied successfully', name: 'SyncService');
    } catch (e) {
      developer.log('Error downloading remote database: $e', name: 'SyncService');
      rethrow;
    } finally {
      _ignoreChanges = false;
    }
  }

  void dispose() {
    _debounceTimer?.cancel();
    _dbChangeSubscription?.cancel();
  }
}
