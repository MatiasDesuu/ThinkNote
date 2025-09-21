import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

class ContextMenu extends StatelessWidget {
  final Offset tapPosition;
  final List<ContextMenuItem> items;
  final VoidCallback onClose;
  final VoidCallback? onOutsideTap;

  const ContextMenu({
    super.key,
    required this.tapPosition,
    required this.items,
    required this.onClose,
    this.onOutsideTap,
  });

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double menuHeight = items.length * 48.0;
    final double menuWidth =
        240.0; // Valor fijo o estimado para el ancho del menú

    final bool wouldOverflowBottom =
        tapPosition.dy + menuHeight > screenSize.height;
    final bool wouldOverflowTop = tapPosition.dy < 0;
    final bool wouldOverflowRight =
        tapPosition.dx + menuWidth > screenSize.width;
    final bool wouldOverflowLeft = tapPosition.dx < 0;

    double menuY = tapPosition.dy;
    if (wouldOverflowBottom) {
      menuY = tapPosition.dy - menuHeight;
    } else if (wouldOverflowTop) {
      menuY = 0;
    }

    double menuX = tapPosition.dx;
    if (wouldOverflowRight) {
      menuX = screenSize.width - menuWidth;
    } else if (wouldOverflowLeft) {
      menuX = 0;
    }

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              onClose();
              onOutsideTap?.call();
            },
            child: Container(color: Colors.transparent),
          ),
        ),
        Positioned(
          left: menuX,
          top: menuY,
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            elevation: 8,
            child: IntrinsicWidth(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withAlpha(26),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children:
                      items
                          .map((item) => _buildMenuItem(context, item))
                          .toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(BuildContext context, ContextMenuItem item) {
    return Material(
      color: Colors.transparent,
      child: Listener(
        onPointerDown: (event) {
          if (event.buttons == kMiddleMouseButton && item.onMiddleClick != null) {
            onClose();
            try {
              item.onMiddleClick!();
            } catch (e) {
              // Silently handle errors
            }
          }
        },
        child: InkWell(
          onTap: () {
            onClose();
            try {
              item.onTap();
            } catch (e) {
              // Silently handle errors
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16, 
              vertical: item.customWidget != null ? 8 : 12,
            ),
            child: item.customWidget ?? Row(
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: item.iconColor ?? Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(item.label),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ContextMenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onMiddleClick;
  final Color? iconColor;
  final Widget? customWidget;

  const ContextMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.onMiddleClick,
    this.iconColor,
    this.customWidget,
  });
}

class ContextMenuOverlay {
  static void show({
    required BuildContext context,
    required Offset tapPosition,
    required List<ContextMenuItem> items,
    VoidCallback? onOutsideTap,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    bool isClosed = false;

    void closeMenu() {
      if (!isClosed) {
        isClosed = true;
        try {
          overlayEntry.remove();
        } catch (e) {
          // Silently handle errors
        }
      }
    }

    overlayEntry = OverlayEntry(
      builder:
          (context) => ContextMenu(
            tapPosition: tapPosition,
            items: items,
            onClose: closeMenu,
            onOutsideTap: onOutsideTap,
          ),
    );

    try {
      overlay.insert(overlayEntry);
    } catch (e) {
      // Silently handle errors
    }
  }
}
