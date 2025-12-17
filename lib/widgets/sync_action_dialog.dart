import 'package:flutter/material.dart';
import 'custom_dialog.dart';

enum SyncAction { uploadLocal, downloadRemote, cancel }

Future<SyncAction?> showSyncActionDialog({required BuildContext context}) {
  final colorScheme = Theme.of(context).colorScheme;

  return showDialog<SyncAction>(
    context: context,
    builder:
        (context) => CustomDialog(
          title: 'Database Synchronization',
          icon: Icons.sync_rounded,
          width: 400,
          bottomBar: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, SyncAction.cancel),
                    style: TextButton.styleFrom(
                      backgroundColor: colorScheme.surfaceContainerHigh,
                      foregroundColor: colorScheme.onSurface,
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
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Choose how to synchronize your database with the WebDAV server.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                // Upload Local Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        () => Navigator.pop(context, SyncAction.uploadLocal),
                    icon: const Icon(Icons.cloud_upload_rounded),
                    label: const Text(
                      'Upload Local Database',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      minimumSize: const Size(0, 44),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Download Remote Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        () => Navigator.pop(context, SyncAction.downloadRemote),
                    icon: const Icon(Icons.cloud_download_rounded),
                    label: const Text(
                      'Download from Server',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      minimumSize: const Size(0, 44),
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
  );
}
