// storage_settings_panel.dart
// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_service.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/confirmation_dialogue.dart';
import '../widgets/custom_dialog.dart';

class StorageSettingsPanel extends StatefulWidget {
  const StorageSettingsPanel({super.key});

  @override
  State<StorageSettingsPanel> createState() => _StorageSettingsPanelState();
}

class _StorageSettingsPanelState extends State<StorageSettingsPanel> {
  bool _isImporting = false;
  bool _isDeleting = false;
  bool _isExporting = false;
  bool _isExportingToFiles = false;
  bool _isImportingFromFolder = false;
  bool _isExportingBookmarks = false;
  bool _isOptimizing = false;
  bool _isPickerOpen = false;
  double _importProgress = 0.0;

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

    return ListView(
      children: [
        const Text(
          'Storage Settings',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),

        // Import Section
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.file_download_rounded,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Import Data',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Import your data from external sources',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon:
                        _isImporting
                            ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.archive_rounded),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _isImporting
                            ? 'Importing (${(_importProgress * 100).toStringAsFixed(0)}%)...'
                            : 'Import from ZIP',
                        style: textStyle?.copyWith(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    onPressed: _isImporting || _isImportingFromFolder || _isPickerOpen ? null : _importZipFile,
                    style: buttonStyle,
                  ),
                ),
                if (_isImporting) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: _importProgress),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon:
                        _isImportingFromFolder
                            ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.drive_file_move_rtl_rounded),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _isImportingFromFolder
                            ? 'Importing (${(_importProgress * 100).toStringAsFixed(0)}%)...'
                            : 'Import from Folder',
                        style: textStyle?.copyWith(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    onPressed:
                        _isImporting || _isImportingFromFolder || _isPickerOpen ? null : _importFromFolder,
                    style: buttonStyle,
                  ),
                ),
                if (_isImportingFromFolder) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: _importProgress),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Export Section
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.file_upload_rounded, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Export Data',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Export your data to external formats',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon:
                        _isExporting
                            ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.backup_rounded),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _isExporting ? 'Exporting...' : 'Export Database (.db)',
                        style: textStyle?.copyWith(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    onPressed: _isExporting ? null : _exportDatabase,
                    style: buttonStyle,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon:
                        _isExportingToFiles
                            ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.drive_file_move_rounded),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _isExportingToFiles
                            ? 'Exporting...'
                            : 'Export to Folder',
                        style: textStyle?.copyWith(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    onPressed: _isExportingToFiles ? null : _exportToFiles,
                    style: buttonStyle,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon:
                        _isExportingBookmarks
                            ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.bookmark_rounded),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _isExportingBookmarks
                            ? 'Exporting...'
                            : 'Export Bookmarks to HTML',
                        style: textStyle?.copyWith(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    onPressed:
                        _isExportingBookmarks ? null : _exportBookmarksToHtml,
                    style: buttonStyle,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Danger Zone Section
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_rounded, color: colorScheme.error),
                    const SizedBox(width: 8),
                    Text(
                      'Danger Zone',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'These actions cannot be undone. Please be careful.',
                  style: TextStyle(color: colorScheme.error),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon:
                        _isOptimizing
                            ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.auto_fix_high_rounded),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _isOptimizing ? 'Optimizing...' : 'Optimize Database',
                        style: textStyle?.copyWith(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    onPressed: _isOptimizing ? null : _optimizeDatabase,
                    style: buttonStyle,
                  ),
                ),
                if (_isOptimizing) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon:
                        _isDeleting
                            ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.delete_forever_rounded),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _isDeleting ? 'Deleting...' : 'Delete Database',
                        style: textStyle?.copyWith(
                          color: colorScheme.onError,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    onPressed: _isDeleting ? null : _deleteDatabase,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                      minimumSize: const Size.fromHeight(50),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBulletPoint(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 7, right: 10),
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _importZipFile() async {
    setState(() => _isPickerOpen = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result != null && result.files.isNotEmpty) {
        final zipFile = result.files.first;
        if (zipFile.path != null) {
          setState(() {
            _isImporting = true;
            _importProgress = 0.0;
            _isPickerOpen = false;
          });
          await DatabaseService().importFromZip(
            zipFile.path!,
            onProgress: (progress) {
              setState(() => _importProgress = progress);
            },
          );

          if (!mounted) return;
          CustomSnackbar.show(
            context: context,
            message: 'Import completed successfully',
            type: CustomSnackbarType.success,
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      CustomSnackbar.show(
        context: context,
        message: 'Error importing file: $e',
        type: CustomSnackbarType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
          _isPickerOpen = false;
          _importProgress = 0.0;
        });
      }
    }
  }

  Future<void> _importFromFolder() async {
    setState(() => _isPickerOpen = true);
    try {
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Import Directory',
      );

      if (result != null) {
        setState(() {
          _isImportingFromFolder = true;
          _importProgress = 0.0;
          _isPickerOpen = false;
        });
        await DatabaseService().importFromFolder(
          result,
          onProgress: (progress) {
            setState(() => _importProgress = progress);
          },
        );

        if (!mounted) return;
        CustomSnackbar.show(
          context: context,
          message: 'Import from folder completed successfully',
          type: CustomSnackbarType.success,
        );
      }
    } catch (e) {
      if (!mounted) return;
      CustomSnackbar.show(
        context: context,
        message: 'Error importing from folder: $e',
        type: CustomSnackbarType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isImportingFromFolder = false;
          _isPickerOpen = false;
          _importProgress = 0.0;
        });
      }
    }
  }

  Future<void> _optimizeDatabase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => CustomDialog(
            title: 'Optimize Database',
            icon: Icons.auto_fix_high_rounded,
            width: 450,
            bottomBar: Container(
              height: 64,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.surfaceContainerHigh,
                        foregroundColor: Theme.of(context).colorScheme.onSurface,
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        minimumSize: const Size(0, 44),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Optimize',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This process will perform a VACUUM operation on your database. It includes:',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildBulletPoint(
                    context,
                    'Reclaiming unused disk space.',
                  ),
                  _buildBulletPoint(
                    context,
                    'Defragmenting the database file.',
                  ),
                  _buildBulletPoint(
                    context,
                    'Improving database performance.',
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withAlpha(50),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withAlpha(50),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Your notes and data will NOT be deleted.',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
    );

    if (confirmed != true) return;

    setState(() => _isOptimizing = true);
    try {
      await DatabaseService().optimizeDatabase();

      if (!mounted) return;
      CustomSnackbar.show(
        context: context,
        message: 'Database optimized successfully',
        type: CustomSnackbarType.success,
      );
    } catch (e) {
      if (!mounted) return;
      CustomSnackbar.show(
        context: context,
        message: 'Error optimizing database: $e',
        type: CustomSnackbarType.error,
      );
    } finally {
      setState(() => _isOptimizing = false);
    }
  }

  Future<void> _deleteDatabase() async {
    setState(() => _isDeleting = true);
    try {
      final colorScheme = Theme.of(context).colorScheme;
      final confirmed = await showDeleteConfirmationDialog(
        context: context,
        title: 'Delete Database',
        message:
            'Are you sure you want to delete the database? This action cannot be undone. All your data will be lost.',
        confirmText: 'Delete',
        confirmColor: colorScheme.error,
      );

      if (confirmed == true) {
        await DatabaseService().deleteDatabase();

        if (!mounted) return;
        CustomSnackbar.show(
          context: context,
          message: 'Database deleted successfully',
          type: CustomSnackbarType.success,
        );
      }
    } catch (e) {
      if (!mounted) return;
      CustomSnackbar.show(
        context: context,
        message: 'Error deleting database: $e',
        type: CustomSnackbarType.error,
      );
    } finally {
      setState(() => _isDeleting = false);
    }
  }

  Future<void> _exportDatabase() async {
    setState(() => _isExporting = true);
    try {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Database',
        fileName: 'thinknote_backup.db',
        type: FileType.custom,
        allowedExtensions: ['db'],
      );

      if (result != null) {
        await DatabaseService().exportDatabase(result);

        if (!mounted) return;
        CustomSnackbar.show(
          context: context,
          message: 'Database exported successfully',
          type: CustomSnackbarType.success,
        );
      }
    } catch (e) {
      if (!mounted) return;
      CustomSnackbar.show(
        context: context,
        message: 'Error exporting database: $e',
        type: CustomSnackbarType.error,
      );
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportToFiles() async {
    setState(() => _isExportingToFiles = true);
    try {
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Export Directory',
      );

      if (result != null) {
        await DatabaseService().exportToFiles(result);

        if (!mounted) return;
        CustomSnackbar.show(
          context: context,
          message: 'Database exported to files successfully',
          type: CustomSnackbarType.success,
        );
      }
    } catch (e) {
      if (!mounted) return;
      CustomSnackbar.show(
        context: context,
        message: 'Error exporting database to files: $e',
        type: CustomSnackbarType.error,
      );
    } finally {
      setState(() => _isExportingToFiles = false);
    }
  }

  Future<void> _exportBookmarksToHtml() async {
    setState(() => _isExportingBookmarks = true);
    try {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Bookmarks to HTML',
        fileName: 'thinknote_bookmarks.html',
        type: FileType.custom,
        allowedExtensions: ['html'],
      );

      if (result != null) {
        await DatabaseService().exportBookmarksToHtml(result);

        if (!mounted) return;
        CustomSnackbar.show(
          context: context,
          message: 'Bookmarks exported to HTML successfully',
          type: CustomSnackbarType.success,
        );
      }
    } catch (e) {
      if (!mounted) return;
      CustomSnackbar.show(
        context: context,
        message: 'Error exporting bookmarks to HTML: $e',
        type: CustomSnackbarType.error,
      );
    } finally {
      setState(() => _isExportingBookmarks = false);
    }
  }
}

class StorageManager {
  static Future<String?> getNotesDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('notes_directory');
  }

  static Future<void> setNotesDirectory(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notes_directory', path);
  }
}
