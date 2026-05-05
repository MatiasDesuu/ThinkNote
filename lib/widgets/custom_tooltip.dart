import 'dart:async';
import 'package:flutter/material.dart';

class TooltipSessionManager {
  static bool _isRecent = false;
  static Timer? _resetTimer;

  static bool get isRecent => _isRecent;

  static void markActive() {
    _isRecent = true;
    _resetTimer?.cancel();
  }

  static void markInactive() {
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(milliseconds: 300), () {
      _isRecent = false;
    });
  }
}

class CustomTooltip extends StatefulWidget {
  final Widget Function(BuildContext context, bool isHovering) builder;
  final String message;
  final Duration waitDuration;

  const CustomTooltip({
    super.key,
    required this.builder,
    required this.message,
    this.waitDuration = const Duration(milliseconds: 500),
  });

  @override
  State<CustomTooltip> createState() => _CustomTooltipState();
}

class _CustomTooltipState extends State<CustomTooltip> {
  bool _isHovering = false;
  Timer? _activationTimer;

  void _handleEnter() {
    setState(() {
      _isHovering = true;
    });

    if (TooltipSessionManager.isRecent) {
      TooltipSessionManager.markActive();
    } else {
      _activationTimer?.cancel();
      _activationTimer = Timer(widget.waitDuration, () {
        TooltipSessionManager.markActive();
      });
    }
  }

  void _handleExit() {
    setState(() {
      _isHovering = false;
    });
    _activationTimer?.cancel();
    TooltipSessionManager.markInactive();
  }

  @override
  void dispose() {
    _activationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isRapidFire = TooltipSessionManager.isRecent;

    return MouseRegion(
      onEnter: (_) => _handleEnter(),
      onExit: (_) => _handleExit(),
      child: Builder(
        builder: (context) {
          final child = widget.builder(context, _isHovering);
          if (_isHovering) {
            return Tooltip(
              message: widget.message,
              waitDuration: isRapidFire ? Duration.zero : widget.waitDuration,
              textStyle: TextStyle(color: colorScheme.onSurface),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh.withAlpha(255),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(40),
                    blurRadius: 8,
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
              child: child,
            );
          }
          return child;
        },
      ),
    );
  }
}

class MouseRegionHoverItem extends StatefulWidget {
  final Widget Function(BuildContext context, bool isHovering) builder;

  const MouseRegionHoverItem({super.key, required this.builder});

  @override
  State<MouseRegionHoverItem> createState() => _MouseRegionHoverItemState();
}

class _MouseRegionHoverItemState extends State<MouseRegionHoverItem> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: widget.builder(context, _isHovering),
    );
  }
}
