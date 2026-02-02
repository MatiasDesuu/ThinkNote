import 'dart:async';
import 'package:flutter/material.dart';
import '../database/sync_service.dart';
import 'resizable_icon_sidebar.dart';

class SyncProgressOverlayManager {
  BuildContext context;
  final bool isMobile;
  OverlayEntry? _overlayEntry;
  StreamSubscription<SyncStatus>? _subscription;
  SyncStatus? _currentStatus;

  SyncProgressOverlayManager({required this.context, this.isMobile = false});

  void initialize() {
    _subscription = SyncService().statusStream.listen((status) {
      _currentStatus = status;
      _updateOverlay();
    });
  }

  void dispose() {
    _subscription?.cancel();
    removeOverlay();
  }

  void removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _updateOverlay() {
    if (_currentStatus == null || _currentStatus!.step == SyncStep.idle) {
      removeOverlay();
      return;
    }

    if (_overlayEntry == null) {
      _overlayEntry = OverlayEntry(
        builder:
            (overlayContext) => Theme(
              data: Theme.of(context),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: removeOverlay,
                      behavior: HitTestBehavior.translucent,
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                  isMobile
                      ? Positioned(
                        left: 10,
                        right: 10,
                        bottom: 110,
                        child: SyncProgressPopup(status: _currentStatus!),
                      )
                      : AnimatedBuilder(
                        animation: GlobalIconSidebarState(),
                        builder: (context, child) {
                          final sidebarState = GlobalIconSidebarState();
                          final leftOffset =
                              sidebarState.isExpanded
                                  ? sidebarState.width
                                  : 0.0;
                          return Positioned(
                            left: leftOffset + 10,
                            bottom: 16,
                            child: SyncProgressPopup(status: _currentStatus!),
                          );
                        },
                      ),
                ],
              ),
            ),
      );
      Overlay.of(context).insert(_overlayEntry!);
    } else {
      _overlayEntry!.markNeedsBuild();
    }
  }
}

class SyncProgressPopup extends StatelessWidget {
  final SyncStatus status;
  final double width;

  const SyncProgressPopup({super.key, required this.status, this.width = 220});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outline.withAlpha(40)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getIconForStep(status.step),
                  size: 16,
                  color:
                      status.step == SyncStep.failed
                          ? colorScheme.error
                          : colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    status.message,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (status.step == SyncStep.failed)
                  Icon(Icons.error_rounded, size: 16, color: colorScheme.error),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value:
                    status.step == SyncStep.completed
                        ? 1.0
                        : (status.step == SyncStep.failed
                            ? 0.0
                            : status.progress),
                backgroundColor: colorScheme.primary.withAlpha(30),
                valueColor: AlwaysStoppedAnimation<Color>(
                  status.step == SyncStep.failed
                      ? colorScheme.error
                      : colorScheme.primary,
                ),
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForStep(SyncStep step) {
    switch (step) {
      case SyncStep.initializing:
        return Icons.sync_rounded;
      case SyncStep.checkingRemote:
        return Icons.cloud_download_rounded;
      case SyncStep.comparing:
        return Icons.compare_arrows_rounded;
      case SyncStep.uploading:
        return Icons.cloud_upload_rounded;
      case SyncStep.downloading:
        return Icons.cloud_download_rounded;
      case SyncStep.finalizing:
        return Icons.check_circle_outline_rounded;
      case SyncStep.completed:
        return Icons.check_circle_rounded;
      case SyncStep.failed:
        return Icons.error_rounded;
      default:
        return Icons.sync_rounded;
    }
  }
}
