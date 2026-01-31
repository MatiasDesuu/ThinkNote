import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import '../Mobile/services/webdav_service.dart';
import 'dart:developer' as developer;

enum SyncStep {
  initializing,
  checkingRemote,
  comparing,
  uploading,
  downloading,
  finalizing,
  completed,
  failed,
  idle,
}

class SyncStatus {
  final SyncStep step;
  final double progress;
  final String message;

  SyncStatus({
    required this.step,
    required this.progress,
    required this.message,
  });

  factory SyncStatus.idle() =>
      SyncStatus(step: SyncStep.idle, progress: 0.0, message: '');
}

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
  static const Duration defaultAutoSyncInterval = Duration(
    minutes: 60,
  ); // 1 hour default
  bool _ignoreChanges = false;

  // Stream for auto sync configuration changes
  final StreamController<bool> _autoSyncEnabledController =
      StreamController<bool>.broadcast();
  Stream<bool> get autoSyncEnabledStream => _autoSyncEnabledController.stream;

  // Stream for auto sync interval changes
  final StreamController<Duration> _autoSyncIntervalController =
      StreamController<Duration>.broadcast();
  Stream<Duration> get autoSyncIntervalStream =>
      _autoSyncIntervalController.stream;

  // Stream for screen open auto sync changes
  final StreamController<bool> _screenOpenAutoSyncController =
      StreamController<bool>.broadcast();
  Stream<bool> get screenOpenAutoSyncStream =>
      _screenOpenAutoSyncController.stream;

  factory SyncService() => _instance;

  SyncService._internal();

  final StreamController<SyncStatus> _statusController =
      StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _statusController.stream;
  SyncStatus _currentStatus = SyncStatus.idle();
  SyncStatus get currentStatus => _currentStatus;

  void _updateStatus(SyncStep step, double progress, String message) {
    _currentStatus = SyncStatus(
      step: step,
      progress: progress,
      message: message,
    );
    _statusController.add(_currentStatus);
  }

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

  Future<void> _performSync({bool isManual = false}) async {
    if (_isSyncing || !_isInitialized) return;

    try {
      _isSyncing = true;
      _ignoreChanges = true;

      if (isManual) {
        _updateStatus(SyncStep.initializing, 0.1, 'Connecting to server...');
      }

      await _webdavService.sync(
        onProgress:
            isManual
                ? (step, progress, message) {
                  SyncStep syncStep;
                  switch (step) {
                    case 'comparing':
                      syncStep = SyncStep.comparing;
                      break;
                    case 'uploading':
                      syncStep = SyncStep.uploading;
                      break;
                    case 'downloading':
                      syncStep = SyncStep.downloading;
                      break;
                    case 'checking_remote':
                      syncStep = SyncStep.checkingRemote;
                      break;
                    default:
                      syncStep = SyncStep.initializing;
                  }
                  _updateStatus(syncStep, progress, message);
                }
                : null,
      );

      _lastSyncTime = DateTime.now();
      _changeCount = 0;

      if (isManual) {
        _updateStatus(SyncStep.completed, 1.0, 'Sync completed');
        // Reset to idle after a delay
        Future.delayed(const Duration(milliseconds: 500), () {
          _updateStatus(SyncStep.idle, 0.0, '');
        });
      }
    } catch (e) {
      developer.log('Error during sync: $e', name: 'SyncService');
      if (isManual) {
        _updateStatus(SyncStep.failed, 0.0, 'Error: ${e.toString()}');
        Future.delayed(const Duration(seconds: 3), () {
          _updateStatus(SyncStep.idle, 0.0, '');
        });
      }
    } finally {
      _isSyncing = false;
      _ignoreChanges = false;
    }
  }

  Future<void> forceSync({bool isManual = false}) async {
    if (!_isInitialized) {
      try {
        if (isManual) {
          _updateStatus(SyncStep.initializing, 0.05, 'Initializing...');
        }
        await initialize();
      } catch (e) {
        developer.log(
          'Error initializing sync service for force sync: $e',
          name: 'SyncService',
        );
        if (isManual) {
          _updateStatus(SyncStep.failed, 0.0, 'Initialization failed');
        }
        rethrow;
      }
    }

    _changeCount = _minChangesForSync; // Forzar al menos un cambio
    await _performSync(isManual: isManual);
  }

  Future<Map<String, dynamic>> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'url': prefs.getString('webdav_url') ?? '',
      'username': prefs.getString('webdav_username') ?? '',
      'password': prefs.getString('webdav_password') ?? '',
      'enabled': prefs.getBool('webdav_enabled') ?? false,
      'autoSyncEnabled': prefs.getBool('webdav_auto_sync_enabled') ?? true,
      'autoSyncIntervalMinutes':
          prefs.getInt('webdav_auto_sync_interval_minutes') ??
          defaultAutoSyncInterval.inMinutes,
      'screenOpenAutoSyncEnabled':
          prefs.getBool('webdav_screen_open_auto_sync_enabled') ?? true,
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

  Future<bool> getAutoSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('webdav_auto_sync_enabled') ?? true;
  }

  Future<void> setAutoSyncEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('webdav_auto_sync_enabled', enabled);
    _autoSyncEnabledController.add(enabled);
  }

  Future<Duration> getAutoSyncInterval() async {
    final prefs = await SharedPreferences.getInstance();
    final minutes =
        prefs.getInt('webdav_auto_sync_interval_minutes') ??
        defaultAutoSyncInterval.inMinutes;
    return Duration(minutes: minutes);
  }

  Future<void> setAutoSyncInterval(Duration interval) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('webdav_auto_sync_interval_minutes', interval.inMinutes);
    _autoSyncIntervalController.add(interval);
  }

  Future<bool> getScreenOpenAutoSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('webdav_screen_open_auto_sync_enabled') ?? true;
  }

  Future<void> setScreenOpenAutoSyncEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('webdav_screen_open_auto_sync_enabled', enabled);
    _screenOpenAutoSyncController.add(enabled);
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
      developer.log(
        'Local database uploaded successfully',
        name: 'SyncService',
      );
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
      developer.log(
        'Starting forced download from server...',
        name: 'SyncService',
      );
      await _webdavService.downloadRemoteDatabase();
      developer.log(
        'Remote database downloaded and applied successfully',
        name: 'SyncService',
      );
    } catch (e) {
      developer.log(
        'Error downloading remote database: $e',
        name: 'SyncService',
      );
      rethrow;
    } finally {
      _ignoreChanges = false;
    }
  }

  void dispose() {
    _debounceTimer?.cancel();
    _dbChangeSubscription?.cancel();
    _autoSyncEnabledController.close();
    _autoSyncIntervalController.close();
    _screenOpenAutoSyncController.close();
  }
}
