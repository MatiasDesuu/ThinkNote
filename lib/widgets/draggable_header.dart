import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

class DraggableHeader extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final double height;
  final EdgeInsets padding;
  final TextStyle? titleStyle;
  final Color? backgroundColor;
  final double trailingExclusionWidth;

  const DraggableHeader({
    super.key,
    this.title,
    this.trailing,
    this.height = 48,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.titleStyle,
    this.backgroundColor,
    this.trailingExclusionWidth = 48,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTitleStyle =
        titleStyle ??
        TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );

    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: trailing != null ? trailingExclusionWidth : 0,
          height: height,
          child: MoveWindow(),
        ),

        Container(
          height: height,
          padding: padding,
          color: backgroundColor,
          child: Center(
            child: Row(
              children: [
                if (title != null && title!.isNotEmpty)
                  Text(title!, style: effectiveTitleStyle),
                if (title != null && title!.isNotEmpty) const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class DraggableArea extends StatelessWidget {
  final double height;
  final double? width;
  final EdgeInsets? margin;
  final EdgeInsets? padding;

  const DraggableArea({
    super.key,
    this.height = 40,
    this.width,
    this.margin,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      margin: margin,
      padding: padding,
      color: Colors.transparent,
      child: MoveWindow(),
    );
  }
}
