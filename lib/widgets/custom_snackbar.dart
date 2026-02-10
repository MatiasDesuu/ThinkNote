import 'package:flutter/material.dart';
import 'dart:io' show Platform;

enum CustomSnackbarType { error, success, warning }

class CustomSnackbar extends StatelessWidget {
  final String message;
  final CustomSnackbarType type;
  final Duration duration;
  final VoidCallback? onActionPressed;
  final String? actionLabel;

  const CustomSnackbar({
    super.key,
    required this.message,
    this.type = CustomSnackbarType.error,
    this.duration = const Duration(seconds: 3),
    this.onActionPressed,
    this.actionLabel,
  });

  static void show({
    required BuildContext context,
    required String message,
    CustomSnackbarType type = CustomSnackbarType.error,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onActionPressed,
    String? actionLabel,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          left:
              Platform.isWindows || Platform.isLinux || Platform.isMacOS
                  ? 74
                  : 16,
          right: 16,
          bottom: 16,
        ),
        dismissDirection: DismissDirection.horizontal,
        padding: const EdgeInsets.only(left: 16, right: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: _getBackgroundColor(context, type),
        duration: duration,
        content: SizedBox(
          height: 48,
          child: Row(
            children: [
              Icon(_getIcon(type), color: _getTextColor(context, type)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: _getTextColor(context, type)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onActionPressed != null && actionLabel != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    onActionPressed();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: _getTextColor(context, type),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 32),
                  ),
                  child: Text(actionLabel),
                ),
              ],
              IconButton(
                icon: Icon(
                  Icons.close,
                  color: _getTextColor(context, type),
                  size: 20,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
                splashRadius: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _getBackgroundColor(
    BuildContext context,
    CustomSnackbarType type,
  ) {
    switch (type) {
      case CustomSnackbarType.error:
        return Theme.of(context).colorScheme.errorContainer;
      case CustomSnackbarType.success:
        return Theme.of(context).colorScheme.primary;
      case CustomSnackbarType.warning:
        return Theme.of(context).colorScheme.tertiary;
    }
  }

  static Color _getTextColor(BuildContext context, CustomSnackbarType type) {
    switch (type) {
      case CustomSnackbarType.error:
        return Theme.of(context).colorScheme.onErrorContainer;
      case CustomSnackbarType.success:
        return Theme.of(context).colorScheme.onPrimary;
      case CustomSnackbarType.warning:
        return Theme.of(context).colorScheme.onTertiary;
    }
  }

  static IconData _getIcon(CustomSnackbarType type) {
    switch (type) {
      case CustomSnackbarType.error:
        return Icons.error_outline_rounded;
      case CustomSnackbarType.success:
        return Icons.check_circle_outline_rounded;
      case CustomSnackbarType.warning:
        return Icons.warning_amber_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.only(
        left:
            Platform.isWindows || Platform.isLinux || Platform.isMacOS
                ? 74
                : 16,
        right: 16,
        bottom: 16,
      ),
      dismissDirection: DismissDirection.horizontal,
      padding: const EdgeInsets.only(left: 16, right: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: _getBackgroundColor(context, type),
      duration: duration,
      content: SizedBox(
        height: 48,
        child: Row(
          children: [
            Icon(_getIcon(type), color: _getTextColor(context, type)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: _getTextColor(context, type)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onActionPressed != null && actionLabel != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  onActionPressed!();
                },
                style: TextButton.styleFrom(
                  foregroundColor: _getTextColor(context, type),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 32),
                ),
                child: Text(actionLabel!),
              ),
            ],
            IconButton(
              icon: Icon(
                Icons.close,
                color: _getTextColor(context, type),
                size: 20,
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
              splashRadius: 20,
            ),
          ],
        ),
      ),
    );
  }
}
