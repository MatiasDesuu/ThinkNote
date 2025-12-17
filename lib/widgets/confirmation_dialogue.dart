import 'package:flutter/material.dart';

import 'custom_dialog.dart';

Future<bool?> showDeleteConfirmationDialog({
  required BuildContext context,
  required String title,
  required String message,
  String cancelText = 'Cancel',
  String confirmText = 'Yes, delete',
  Color? confirmColor,
  bool barrierDismissible = true,
  IconData icon = Icons.delete_rounded,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
    color: colorScheme.onSurface,
    fontWeight: FontWeight.normal,
    fontSize: 15,
  );

  return showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder:
        (context) => CustomDialog(
          title: title,
          icon: icon,
          width: 400,
          bottomBar: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            height: 56,
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      backgroundColor: colorScheme.surfaceContainerHigh,
                      foregroundColor: colorScheme.onSurface,
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        cancelText,
                        style: textStyle,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmColor ?? colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      minimumSize: const Size(0, 44),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        confirmText,
                        style: textStyle?.copyWith(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
  );
}
