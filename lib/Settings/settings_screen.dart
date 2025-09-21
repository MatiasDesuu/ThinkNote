import 'dart:io';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'editor_settings_panel.dart';
import 'personalization_settings_panel.dart';
import 'storage_settings_panel.dart';
import 'sync_settings_panel.dart';
import 'shortcuts_settings_panel.dart';
import 'help_formats_panel.dart';
import '../widgets/resizable_icon_sidebar.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onThemeUpdated;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
  const SettingsScreen({super.key, this.onThemeUpdated});
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedIndex = 0;
  final FocusNode _appFocusNode = FocusNode();

  final List<Map<String, dynamic>> _menuOptions = [
    {'icon': Icons.edit_rounded, 'text': 'Editor'},
    {'icon': Icons.palette_rounded, 'text': 'Customization'},
    {'icon': Icons.folder_rounded, 'text': 'Storage'},
    {'icon': Icons.sync_rounded, 'text': 'Sync'},
    {'icon': Icons.keyboard_rounded, 'text': 'Shortcuts'},
    {'icon': Icons.help_outline_rounded, 'text': 'Help'},
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return (Platform.isWindows || Platform.isLinux)
        ? Scaffold(
          body: Stack(
            children: [
              // Main content
              Row(
                children: [
                  // Left sidebar with navigation buttons
                  ResizableIconSidebar(
                    rootDir: null,
                    onOpenNote: null,
                    onOpenFolder: null,
                    onNotebookSelected: null,
                    onNoteSelected: null,
                    onBack: () => Navigator.of(context).pop(),
                    onDirectorySet: null,
                    onThemeUpdated: widget.onThemeUpdated,
                    onFavoriteRemoved: null,
                    onNavigateToMain: null,
                    onClose: null,
                    onCreateNewNote: null,
                    onCreateNewNotebook: null,
                    onCreateNewTodo: null,
                    onShowManageTags: null,
                    onCreateThink: null,
                    onOpenSettings: null,
                    onOpenTrash: null,
                    onOpenFavorites: null,
                    showBackButton: true,
                    isWorkflowsScreen: false,
                    isTasksScreen: false,
                    isThinksScreen: false,
                    isSettingsScreen: true,
                    isBookmarksScreen: false,
                    appFocusNode: _appFocusNode,
                  ),

                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: colorScheme.surfaceContainerHighest,
                  ),

                  // Central panel with options (resizable)
                  Container(
                    width: 240,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Text(
                                'Settings',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            children:
                                _menuOptions
                                    .asMap()
                                    .entries
                                    .map(
                                      (entry) => _buildMenuButton(
                                        entry.key,
                                        entry.value['icon'],
                                        entry.value['text'],
                                      ),
                                    )
                                    .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Right content panel
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 24.0,
                        right: 24.0,
                        bottom: 24.0,
                        top: 48.0,
                      ),
                      child: _getSettingsContent(),
                    ),
                  ),
                ],
              ),

              // Window controls in top right corner
              Positioned(
                top: 0,
                right: 0,
                height: 40,
                child: Container(
                  color: colorScheme.surface,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 46,
                        height: 40,
                        child: MinimizeWindowButton(
                          colors: WindowButtonColors(
                            iconNormal: colorScheme.onSurface,
                            mouseOver: colorScheme.surfaceContainerHighest,
                            mouseDown: colorScheme.surfaceContainerHigh,
                            iconMouseOver: colorScheme.onSurface,
                            iconMouseDown: colorScheme.onSurface,
                          ),
                          onPressed: () {
                            appWindow.minimize();
                          },
                        ),
                      ),
                      SizedBox(
                        width: 46,
                        height: 40,
                        child: MaximizeWindowButton(
                          colors: WindowButtonColors(
                            iconNormal: colorScheme.onSurface,
                            mouseOver: colorScheme.surfaceContainerHighest,
                            mouseDown: colorScheme.surfaceContainerHigh,
                            iconMouseOver: colorScheme.onSurface,
                            iconMouseDown: colorScheme.onSurface,
                          ),
                          onPressed: () {
                            appWindow.maximizeOrRestore();
                          },
                        ),
                      ),
                      SizedBox(
                        width: 46,
                        height: 40,
                        child: CloseWindowButton(
                          colors: WindowButtonColors(
                            iconNormal: colorScheme.onSurface,
                            mouseOver: colorScheme.error,
                            mouseDown: colorScheme.error.withAlpha(128),
                            iconMouseOver: colorScheme.onError,
                            iconMouseDown: colorScheme.onError,
                          ),
                          onPressed: () {
                            appWindow.close();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Title drag area - correctly placed
              Positioned(
                top: 0,
                left: 60, // Width of left sidebar
                right: 138, // Width of control buttons
                height: 40,
                child: MoveWindow(),
              ),
            ],
          ),
        )
        : Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ),
          body: Row(
            children: [
              Container(
                width: 240,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        children:
                            _menuOptions
                                .asMap()
                                .entries
                                .map(
                                  (entry) => _buildMenuButton(
                                    entry.key,
                                    entry.value['icon'],
                                    entry.value['text'],
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _getSettingsContent(),
                ),
              ),
            ],
          ),
        );
  }

  Widget _buildMenuButton(int index, IconData icon, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Material(
        color:
            isSelected
                ? colorScheme.surfaceContainerHighest
                : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _selectedIndex = index),
          child: SizedBox(
            height: 48,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Icon(
                    icon,
                    color:
                        isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      text,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color:
                            isSelected
                                ? colorScheme.primary
                                : colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _getSettingsContent() {
    switch (_selectedIndex) {
      case 0:
        return const EditorSettingsPanel();
      case 1:
        return PersonalizationSettingsPanel(
          onThemeUpdated: widget.onThemeUpdated,
        );
      case 2:
        return StorageSettingsPanel();
      case 3:
        return const SyncSettingsPanel();
      case 4:
        return const ShortcutsSettingsPanel();
      case 5:
        return const HelpFormatsPanel();
      default:
        return const Center(child: Text('Select an option'));
    }
  }

  @override
  void dispose() {
    _appFocusNode.dispose();
    super.dispose();
  }
}
