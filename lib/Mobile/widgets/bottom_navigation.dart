import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class BottomNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      destinations: [
        NavigationDestination(
          icon: Icon(Symbols.home_rounded, color: colorScheme.onSurfaceVariant),
          selectedIcon: Icon(Symbols.home_rounded, color: colorScheme.primary),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(
            Symbols.search_rounded,
            color: colorScheme.onSurfaceVariant,
          ),
          selectedIcon: Icon(
            Symbols.search_rounded,
            color: colorScheme.primary,
          ),
          label: 'Search',
        ),
        NavigationDestination(
          icon: Icon(Symbols.task_rounded, color: colorScheme.onSurfaceVariant),
          selectedIcon: Icon(Symbols.task_rounded, color: colorScheme.primary),
          label: 'Tasks',
        ),
        NavigationDestination(
          icon: Icon(
            Symbols.bookmark_rounded,
            color: colorScheme.onSurfaceVariant,
          ),
          selectedIcon: Icon(
            Symbols.bookmark_rounded,
            color: colorScheme.primary,
          ),
          label: 'Bookmarks',
        ),
      ],
    );
  }
}
