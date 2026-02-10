import 'package:flutter/material.dart';

class CustomTooltip extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegionHoverItem(
      builder: (context, isHovering) {
        final child = builder(context, isHovering);
        if (isHovering) {
          return Tooltip(
            message: message,
            waitDuration: waitDuration,
            textStyle: TextStyle(color: colorScheme.onSurface),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh.withAlpha(255),
              borderRadius: BorderRadius.circular(8),
            ),
            child: child,
          );
        }
        return child;
      },
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
