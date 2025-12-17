import 'package:flutter/material.dart';

class CustomDialog extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final List<Widget>? headerActions;
  final Widget? bottomBar;
  final double width;
  final double? height;

  const CustomDialog({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.headerActions,
    this.bottomBar,
    this.width = 500,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(icon, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    if (headerActions != null) ...headerActions!,
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Body
              Flexible(child: child),
              // Bottom Bar
              if (bottomBar != null) bottomBar!,
            ],
          ),
        ),
      ),
    );
  }
}
