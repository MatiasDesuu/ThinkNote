import 'package:flutter/material.dart';

Future<bool?> showDeleteConfirmationDialog({
  required BuildContext context,
  required String title,
  required String message,
  String cancelText = 'Cancel',
  String confirmText = 'Yes, delete',
  Color? confirmColor,
  bool barrierDismissible = true,
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
    useRootNavigator: false,
    builder:
        (context) => PopScope(
          canPop: true,
          onPopInvokedWithResult: (bool didPop, bool? result) {
            if (didPop) return;
            Navigator.pop(context, false);
          },
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 400,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: textStyle?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        message,
                        style: textStyle?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              style: TextButton.styleFrom(
                                backgroundColor:
                                    colorScheme.surfaceContainerHigh,
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
                                backgroundColor:
                                    confirmColor ?? colorScheme.primary,
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
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
  );
}
