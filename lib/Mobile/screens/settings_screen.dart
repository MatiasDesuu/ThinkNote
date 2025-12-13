import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/webdav_service.dart';
import '../../widgets/custom_snackbar.dart';
import '../../Settings/editor_settings_panel.dart';
import '../../widgets/sync_action_dialog.dart';
import '../../database/sync_service.dart';

class SettingsScreen extends StatefulWidget {
  final Function({bool? isDarkMode, bool? isColorMode, bool? isMonochrome, bool? isEInk})
  onUpdateTheme;
  final bool isDarkMode;
  final bool isColorModeEnabled;
  final bool isMonochromeEnabled;
  final bool isEInkEnabled;

  const SettingsScreen({
    super.key,
    required this.onUpdateTheme,
    required this.isDarkMode,
    required this.isColorModeEnabled,
    required this.isMonochromeEnabled,
    required this.isEInkEnabled,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _isDarkMode;
  late bool _isColorModeEnabled;
  late bool _isMonochromeEnabled;
  late bool _isEInkEnabled;
  bool _isAnimationDisabled = false;
  bool _isWebDAVEnabled = false;
  bool _showNotebookIcons = true;
  bool _showNoteIcons = true;
  final _webdavUrlController = TextEditingController();
  final _webdavUserController = TextEditingController();
  final _webdavPassController = TextEditingController();
  bool _isLoading = false;
  bool _isInitialized = false;
  final _webdavService = WebDAVService();

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
    _isColorModeEnabled = widget.isColorModeEnabled;
    _isMonochromeEnabled = widget.isMonochromeEnabled;
    _isEInkEnabled = widget.isEInkEnabled;
    _loadInitialSettingsSync();
  }

  @override
  void dispose() {
    _webdavUrlController.dispose();
    _webdavUserController.dispose();
    _webdavPassController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialSettingsSync() async {
    try {
      // Asegurar que el cache esté inicializado
      await EditorSettings.preloadSettings();

      final prefs = await SharedPreferences.getInstance();
      final showNotebookIcons = await EditorSettings.getShowNotebookIcons();
      final showNoteIcons = await EditorSettings.getShowNoteIcons();

      if (mounted) {
        setState(() {
          _isWebDAVEnabled = prefs.getBool('webdav_enabled') ?? false;
          _isAnimationDisabled = prefs.getBool('disable_animations') ?? false;
          _webdavUrlController.text = prefs.getString('webdav_url') ?? '';
          _webdavUserController.text = prefs.getString('webdav_username') ?? '';
          _webdavPassController.text = prefs.getString('webdav_password') ?? '';
          _showNotebookIcons = showNotebookIcons;
          _showNoteIcons = showNoteIcons;
          timeDilation = _isAnimationDisabled ? 0.0001 : 1.0;
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('Error loading settings: $e');
      // En caso de error, usar valores por defecto
      if (mounted) {
        setState(() {
          _isWebDAVEnabled = false;
          _isAnimationDisabled = false;
          _webdavUrlController.text = '';
          _webdavUserController.text = '';
          _webdavPassController.text = '';
          _showNotebookIcons = true;
          _showNoteIcons = true;
          timeDilation = 1.0;
          _isInitialized = true;
        });
      }
    }
  }

  Future<void> _saveWebDAVConfig() async {
    setState(() => _isLoading = true);

    try {
      final success = await _webdavService.testConnection(
        _webdavUrlController.text,
        _webdavUserController.text,
        _webdavPassController.text,
      );

      if (!success) {
        throw Exception('Could not connect to WebDAV server');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('webdav_url', _webdavUrlController.text);
      await prefs.setString('webdav_username', _webdavUserController.text);
      await prefs.setString('webdav_password', _webdavPassController.text);
      await prefs.setBool('webdav_enabled', _isWebDAVEnabled);

      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'WebDAV settings saved successfully',
          type: CustomSnackbarType.success,
        );

        // Show sync dialog if WebDAV is enabled
        if (_isWebDAVEnabled) {
          _showSyncDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error saving WebDAV settings: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showSyncDialog() async {
    final result = await showSyncActionDialog(context: context);
    
    if (!mounted || result == null || result == SyncAction.cancel) {
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      switch (result) {
        case SyncAction.uploadLocal:
          await SyncService().uploadLocalDatabase();
          if (mounted) {
            CustomSnackbar.show(
              context: context,
              message: 'Local database uploaded successfully',
              type: CustomSnackbarType.success,
            );
          }
          break;
        case SyncAction.downloadRemote:
          await SyncService().downloadRemoteDatabase();
          if (mounted) {
            CustomSnackbar.show(
              context: context,
              message: 'Database downloaded from server successfully',
              type: CustomSnackbarType.success,
            );
          }
          break;
        case SyncAction.cancel:
          break;
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Sync error: ${e.toString().replaceAll('Exception: ', '')}',
          type: CustomSnackbarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _updatePreferences() {
    widget.onUpdateTheme(
      isDarkMode: _isDarkMode,
      isColorMode: _isColorModeEnabled,
      isMonochrome: _isMonochromeEnabled,
      isEInk: _isEInkEnabled,
    );
  }

  void _toggleAnimations(bool value) async {
    setState(() {
      _isAnimationDisabled = value;
      timeDilation = value ? 0.0001 : 1.0;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('disable_animations', value);
  }

  void _toggleWebDAV(bool value) async {
    setState(() {
      _isWebDAVEnabled = value;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('webdav_enabled', value);
  }

  void _toggleShowNotebookIcons(bool value) async {
    setState(() {
      _showNotebookIcons = value;
    });
    await EditorSettings.setShowNotebookIcons(value);
  }

  void _toggleShowNoteIcons(bool value) async {
    setState(() {
      _showNoteIcons = value;
    });
    await EditorSettings.setShowNoteIcons(value);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mediaQuery = MediaQuery.of(context);

    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          backgroundColor: colorScheme.surface,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, bool? result) {
        if (!didPop) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        extendBody: true,
        appBar: AppBar(
          title: const Text('Settings'),
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          backgroundColor: colorScheme.surface,
        ),
        body: Container(
          decoration: BoxDecoration(color: colorScheme.surface),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              top: 8.0,
              bottom: mediaQuery.viewPadding.bottom + 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Appearance',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerHigh,
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Dark Mode'),
                        subtitle: const Text(
                          'Switch between light and dark theme',
                        ),
                        value: _isDarkMode,
                        onChanged: (value) {
                          setState(() => _isDarkMode = value);
                          _updatePreferences();
                        },
                      ),

                      SwitchListTile(
                        title: const Text('E-Ink Mode'),
                        subtitle: const Text(
                          'Pure black and white for e-ink displays',
                        ),
                        value: _isEInkEnabled,
                        onChanged: (value) {
                          setState(() {
                            _isEInkEnabled = value;
                            if (value) {
                              _isColorModeEnabled = false;
                              _isMonochromeEnabled = false;
                            }
                          });
                          _updatePreferences();
                        },
                      ),

                      if (!_isEInkEnabled) ...[
                        SwitchListTile(
                          title: const Text('Color Mode'),
                          subtitle: const Text(
                            'Tint all elements with themed colors',
                          ),
                          value: _isColorModeEnabled,
                          onChanged: (value) {
                            setState(() => _isColorModeEnabled = value);
                            _updatePreferences();
                          },
                        ),
                        if (!_isColorModeEnabled) ...[
                          SwitchListTile(
                            title: const Text('Monochrome Mode'),
                            subtitle: const Text('Use a grayscale palette'),
                            value: _isMonochromeEnabled,
                            onChanged: (value) {
                              setState(() => _isMonochromeEnabled = value);
                              _updatePreferences();
                            },
                          ),
                        ],
                      ],
                      SwitchListTile(
                        title: const Text('Disable Animations'),
                        subtitle: const Text(
                          'Disable all app animations for better performance',
                        ),
                        value: _isAnimationDisabled,
                        onChanged: _toggleAnimations,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Interface',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerHigh,
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Show Notebook Icons'),
                        subtitle: const Text(
                          'Display icons next to notebook names in the sidebar',
                        ),
                        value: _showNotebookIcons,
                        onChanged: _toggleShowNotebookIcons,
                      ),
                      SwitchListTile(
                        title: const Text('Show Note Icons'),
                        subtitle: const Text(
                          'Display icons next to note names in the notes list',
                        ),
                        value: _showNoteIcons,
                        onChanged: _toggleShowNoteIcons,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'WebDAV Synchronization',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerHigh,
                  child:
                      !_isInitialized
                          ? const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: CircularProgressIndicator()),
                          )
                          : Column(
                            children: [
                              const SizedBox(height: 8),
                              SwitchListTile(
                                title: const Text('Enable WebDAV Sync'),
                                subtitle: const Text(
                                  'Synchronize your notes with a WebDAV server',
                                ),
                                value: _isWebDAVEnabled,
                                onChanged: _toggleWebDAV,
                              ),
                              if (_isWebDAVEnabled) ...[
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    children: [
                                      TextField(
                                        controller: _webdavUrlController,
                                        decoration: InputDecoration(
                                          labelText: 'Server URL (http://)',
                                          hintText:
                                              'http://tuserver.com/webdav',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          filled: true,
                                          fillColor: colorScheme
                                              .surfaceContainerHighest
                                              .withAlpha(76),
                                          prefixIcon: const Icon(
                                            Icons.link_rounded,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      TextField(
                                        controller: _webdavUserController,
                                        decoration: InputDecoration(
                                          labelText: 'Username',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          filled: true,
                                          fillColor: colorScheme
                                              .surfaceContainerHighest
                                              .withAlpha(76),
                                          prefixIcon: const Icon(
                                            Icons.person_rounded,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      TextField(
                                        controller: _webdavPassController,
                                        decoration: InputDecoration(
                                          labelText: 'Password',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          filled: true,
                                          fillColor: colorScheme
                                              .surfaceContainerHighest
                                              .withAlpha(76),
                                          prefixIcon: const Icon(
                                            Icons.lock_rounded,
                                          ),
                                        ),
                                        obscureText: true,
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton.icon(
                                        onPressed:
                                            _isLoading
                                                ? null
                                                : _saveWebDAVConfig,
                                        icon:
                                            _isLoading
                                                ? const SizedBox(
                                                  height: 20,
                                                  width: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                                : const Icon(
                                                  Icons.save_rounded,
                                                ),
                                        label: Text(
                                          _isLoading
                                              ? 'Saving...'
                                              : 'Save settings',
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: colorScheme.primary,
                                          foregroundColor:
                                              colorScheme.onPrimary,
                                          minimumSize: const Size.fromHeight(
                                            50,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                ),
                const SizedBox(height: 8),
                Text(
                  'About',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerHigh,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 0),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      leading: Icon(
                        Icons.info_outline_rounded,
                        color: colorScheme.primary,
                      ),
                      title: Text(
                        'ThinkNote',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        'Version 0.8.0',
                        style: TextStyle(
                          color: colorScheme.onSurface.withAlpha(150),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
