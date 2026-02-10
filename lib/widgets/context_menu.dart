import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

class ContextMenu extends StatefulWidget {
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
  State<ContextMenu> createState() => _ContextMenuState();
}

class _ContextMenuState extends State<ContextMenu> {
  final GlobalKey _menuKey = GlobalKey();
  double? _menuWidth;
  double? _menuHeight;
  bool _isPositioned = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureMenu();
    });
  }

  void _measureMenu() {
    final RenderBox? renderBox =
        _menuKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && mounted) {
      setState(() {
        _menuWidth = renderBox.size.width;
        _menuHeight = renderBox.size.height;
        _isPositioned = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    final double menuWidth = _menuWidth ?? 200.0;
    final double menuHeight = _menuHeight ?? (widget.items.length * 48.0);

    final bool wouldOverflowBottom =
        widget.tapPosition.dy + menuHeight > screenSize.height;
    final bool wouldOverflowRight =
        widget.tapPosition.dx + menuWidth > screenSize.width;

    double menuY = widget.tapPosition.dy;
    if (wouldOverflowBottom) {
      menuY = (widget.tapPosition.dy - menuHeight).clamp(
        0.0,
        screenSize.height - menuHeight,
      );
    }

    double menuX = widget.tapPosition.dx;
    if (wouldOverflowRight) {
      menuX = (screenSize.width - menuWidth - 8).clamp(0.0, screenSize.width);
    }

    menuX = menuX.clamp(8.0, screenSize.width - 8);
    menuY = menuY.clamp(8.0, screenSize.height - 8);

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              widget.onClose();
              widget.onOutsideTap?.call();
            },
            child: Container(color: Colors.transparent),
          ),
        ),
        Positioned(
          left: menuX,
          top: menuY,
          child: Opacity(
            opacity: _isPositioned ? 1.0 : 0.0,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: screenSize.width - 16,
                maxHeight: screenSize.height - 16,
              ),
              child: Material(
                key: _menuKey,
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                elevation: 8,
                child: IntrinsicWidth(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withAlpha(26),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children:
                          widget.items
                              .map((item) => _buildMenuItem(context, item))
                              .toList(),
                    ),
                  ),
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
          if (event.buttons == kMiddleMouseButton &&
              item.onMiddleClick != null) {
            widget.onClose();
            try {
              item.onMiddleClick!();
            } catch (e) {
              // Ignore errors when executing onMiddleClick
            }
          }
        },
        child: InkWell(
          onTap: () {
            widget.onClose();
            try {
              item.onTap();
            } catch (e) {
              // Ignore errors when executing onTap
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: item.customWidget != null ? 8 : 12,
            ),
            child:
                item.customWidget ??
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.icon,
                      size: 20,
                      color:
                          item.iconColor ??
                          Theme.of(context).colorScheme.primary,
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
          // Ignore errors when removing overlay
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
      // Ignore errors when inserting overlay
    }
  }
}
