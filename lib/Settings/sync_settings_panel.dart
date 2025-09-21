// sync_settings_panel.dart
// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import '../database/sync_service.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/sync_action_dialog.dart';

class SyncSettingsPanel extends StatefulWidget {
  const SyncSettingsPanel({super.key});

  @override
  State<SyncSettingsPanel> createState() => _SyncSettingsPanelState();
}

class _SyncSettingsPanelState extends State<SyncSettingsPanel> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isEnabled = false;
  bool _isLoading = true;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final settings = await SyncService().getSettings();
      setState(() {
        _urlController.text = settings['url'] as String;
        _usernameController.text = settings['username'] as String;
        _passwordController.text = settings['password'] as String;
        _isEnabled = settings['enabled'] as bool;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await SyncService().saveSettings(
        url: _urlController.text,
        username: _usernameController.text,
        password: _passwordController.text,
        enabled: _isEnabled,
      );
      setState(() => _isLoading = false);
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Settings saved successfully',
          type: CustomSnackbarType.success,
        );

        // Show sync dialog if WebDAV is enabled
        if (_isEnabled) {
          _showSyncDialog();
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error saving settings: $e',
          type: CustomSnackbarType.error,
        );
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

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isTesting = true;
    });

    try {
      // Guardar temporalmente las credenciales para la prueba
      await SyncService().saveSettings(
        url: _urlController.text,
        username: _usernameController.text,
        password: _passwordController.text,
        enabled: _isEnabled,
      );

      final success = await SyncService().testConnection();
      setState(() {
        _isTesting = false;
      });

      if (!mounted) return;
      if (success) {
        CustomSnackbar.show(
          context: context,
          message: 'Connection successful!',
          type: CustomSnackbarType.success,
        );
      } else {
        CustomSnackbar.show(
          context: context,
          message:
              'Connection failed. Please check your credentials and try again.',
          type: CustomSnackbarType.error,
        );
      }
    } catch (e) {
      setState(() {
        _isTesting = false;
      });

      if (!mounted) return;
      CustomSnackbar.show(
        context: context,
        message:
            'Error testing connection: ${e.toString().replaceAll('Exception: ', '')}',
        type: CustomSnackbarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurface,
      fontWeight: FontWeight.normal,
      fontSize: 15,
    );

    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      minimumSize: const Size.fromHeight(50),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      children: [
        const Text(
          'WebDAV Sync Settings',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),

        // Sync Configuration Section
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.sync_rounded, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Sync Configuration',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Configure WebDAV synchronization settings',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Enable Switch
                  Row(
                    children: [
                      Expanded(
                        child: Text('Enable WebDAV Sync', style: textStyle),
                      ),
                      Switch(
                        value: _isEnabled,
                        onChanged: (value) {
                          setState(() => _isEnabled = value);
                          _saveSettings();
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // URL Field
                  TextFormField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      labelText: 'WebDAV URL',
                      hintText: 'https://example.com/webdav',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest.withAlpha(
                        76,
                      ),
                      prefixIcon: const Icon(Icons.link_rounded),
                    ),
                    enabled: _isEnabled,
                    validator: (value) {
                      if (_isEnabled && (value == null || value.isEmpty)) {
                        return 'Please enter WebDAV URL';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 12),

                  // Username Field
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest.withAlpha(
                        76,
                      ),
                      prefixIcon: const Icon(Icons.person_rounded),
                    ),
                    enabled: _isEnabled,
                    validator: (value) {
                      if (_isEnabled && (value == null || value.isEmpty)) {
                        return 'Please enter username';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 12),

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest.withAlpha(
                        76,
                      ),
                      prefixIcon: const Icon(Icons.lock_rounded),
                    ),
                    obscureText: true,
                    enabled: _isEnabled,
                    validator: (value) {
                      if (_isEnabled && (value == null || value.isEmpty)) {
                        return 'Please enter password';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isEnabled ? _testConnection : null,
                          icon:
                              _isTesting
                                  ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(
                                    Icons.check_circle_outline_rounded,
                                  ),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _isTesting ? 'Testing...' : 'Test Connection',
                              style: textStyle?.copyWith(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          style: buttonStyle,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isEnabled ? _saveSettings : null,
                          icon: const Icon(Icons.save_rounded),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Save Settings',
                              style: textStyle?.copyWith(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          style: buttonStyle,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
