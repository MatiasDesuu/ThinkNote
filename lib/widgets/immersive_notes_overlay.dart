import 'package:flutter/material.dart';

class ImmersiveNotesOverlay extends StatefulWidget {
  final Widget child;
  final Widget? overlayPanel;
  final bool isImmersiveMode;
  final VoidCallback onExpand;
  final VoidCallback onCollapse;
  final void Function(bool isHovering)? onHoverStateChanged;
  final double leftOffset;
  final double rightOffset;
  final double panelLeftOffset;
  final double panelRightOffset;
  final double triggerWidth;
  final bool useRightEdge;

  const ImmersiveNotesOverlay({
    super.key,
    required this.child,
    this.overlayPanel,
    required this.isImmersiveMode,
    required this.onExpand,
    required this.onCollapse,
    this.onHoverStateChanged,
    this.leftOffset = 0,
    this.rightOffset = 0,
    this.panelLeftOffset = 0,
    this.panelRightOffset = 0,
    this.triggerWidth = 10,
    this.useRightEdge = false,
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
          left: widget.useRightEdge ? null : widget.leftOffset,
          right: widget.useRightEdge ? widget.rightOffset : null,
          top: 0,
          bottom: 0,
          child: MouseRegion(
            opaque: false,
            hitTestBehavior: HitTestBehavior.translucent,
            onExit: (_) => _handleExit(),
            child: widget.useRightEdge
                ? Stack(
                    children: [
                      SizedBox(
                        width: widget.triggerWidth,
                      ),
                      if (widget.overlayPanel != null)
                        Padding(
                          padding: EdgeInsets.only(
                            right: widget.panelRightOffset,
                          ),
                          child: widget.overlayPanel!,
                        ),
                      Positioned(
                        top: 0,
                        bottom: 0,
                        right: 0,
                        child: MouseRegion(
                          onEnter: (_) => _handleEnter(),
                          child: Container(
                            color: Colors.transparent,
                            width: widget.triggerWidth,
                          ),
                        ),
                      ),
                    ],
                  )
                : Stack(
                    children: [
                      SizedBox(
                        width: widget.triggerWidth,
                      ),
                      if (widget.overlayPanel != null)
                        Padding(
                          padding: EdgeInsets.only(left: widget.panelLeftOffset),
                          child: widget.overlayPanel!,
                        ),
                      Positioned(
                        top: 0,
                        bottom: 0,
                        left: 0,
                        child: MouseRegion(
                          onEnter: (_) => _handleEnter(),
                          child: Container(
                            color: Colors.transparent,
                            width: widget.triggerWidth,
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
}
