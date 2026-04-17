import 'package:flutter/material.dart';

class ImmersiveNotesOverlay extends StatefulWidget {
  final Widget child;
  final Widget? overlayPanel;
  final bool isImmersiveMode;
  final VoidCallback onExpand;
  final VoidCallback onCollapse;
  final void Function(bool isHovering)? onHoverStateChanged;

  const ImmersiveNotesOverlay({
    super.key,
    required this.child,
    this.overlayPanel,
    required this.isImmersiveMode,
    required this.onExpand,
    required this.onCollapse,
    this.onHoverStateChanged,
  });

  @override
  State<ImmersiveNotesOverlay> createState() => _ImmersiveNotesOverlayState();
}

class _ImmersiveNotesOverlayState extends State<ImmersiveNotesOverlay> {
  bool _isHovering = false;

  void _handleEnter() {
    if (widget.isImmersiveMode) {
      if (!_isHovering) {
        setState(() => _isHovering = true);
        widget.onHoverStateChanged?.call(true);
        widget.onExpand();
      }
    }
  }

  void _handleExit() {
    if (widget.isImmersiveMode) {
      if (_isHovering) {
        setState(() => _isHovering = false);
        widget.onHoverStateChanged?.call(false);
        widget.onCollapse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isImmersiveMode) {
      return widget.child;
    }

    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: MouseRegion(
            onEnter: (_) => _handleEnter(),
            onExit: (_) => _handleExit(),
            child: Stack(
              children: [
                Container(
                  color: Colors.transparent,
                  width: 20,
                ),
                if (widget.overlayPanel != null) widget.overlayPanel!,
              ],
            ),
          ),
        ),
      ],
    );
  }
}
