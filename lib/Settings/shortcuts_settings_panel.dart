// shortcuts_settings_panel.dart
// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';

class ShortcutsSettingsPanel extends StatelessWidget {
  const ShortcutsSettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      children: [
        const Text(
          'Keyboard Shortcuts',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),

        // Navigation and Editing Section
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.edit_rounded, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Edition',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Keyboard shortcuts for edition operations',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                _buildShortcutItem(
                  context: context,
                  label: 'Create new note',
                  shortcut: 'Ctrl + N',
                ),
                _buildShortcutItem(
                  context: context,
                  label: 'Create new notebook',
                  shortcut: 'Ctrl + Shift + N',
                ),
                _buildShortcutItem(
                  context: context,
                  label: 'Create new todo',
                  shortcut: 'Ctrl + D',
                ),
                _buildShortcutItem(
                  context: context,
                  label: 'Open new tab',
                  shortcut: 'Ctrl + T',
                ),
                _buildShortcutItem(
                  context: context,
                  label: 'Save changes in note',
                  shortcut: 'Ctrl + S',
                ),
                _buildShortcutItem(
                  context: context,
                  label: 'Find in note',
                  shortcut: 'Ctrl + F',
                ),
                _buildShortcutItem(
                  context: context,
                  label: 'Close current tab',
                  shortcut: 'Ctrl + W',
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Synchronization Section
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.sync_rounded, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Synchronization',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Keyboard shortcuts for data synchronization',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                _buildShortcutItem(
                  context: context,
                  label: 'Synchronize with server',
                  shortcut: 'F5',
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Interface Section
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.dashboard_rounded, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Interface',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Keyboard shortcuts for interface control',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                _buildShortcutItem(
                  context: context,
                  label: 'Center editor',
                  shortcut: 'F1',
                ),
                _buildShortcutItem(
                  context: context,
                  label: 'Hide/show Notebooks panel)',
                  shortcut: 'F2',
                ),
                _buildShortcutItem(
                  context: context,
                  label: 'Hide/show Notes panel',
                  shortcut: 'F3',
                ),

                _buildShortcutItem(
                  context: context,
                  label: 'Toggle immersive mode',
                  shortcut: 'F4',
                ),
                _buildShortcutItem(
                  context: context,
                  label: 'Global search',
                  shortcut: 'Ctrl + Shift + S',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShortcutItem({
    required BuildContext context,
    required String label,
    required String shortcut,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: colorScheme.onSurface, fontSize: 15),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                color: colorScheme.outline.withAlpha(51),
                width: 1,
              ),
            ),
            child: Text(
              shortcut,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
