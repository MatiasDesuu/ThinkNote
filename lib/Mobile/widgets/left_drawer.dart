import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'dart:async';
import '../../database/models/notebook.dart';
import '../../database/models/notebook_icons.dart';
import '../../database/repositories/notebook_repository.dart';
import '../../database/database_helper.dart';
import '../../Settings/editor_settings_panel.dart';
import '../screens/trash_screen.dart';
import '../screens/icon_selector_screen.dart';
import '../screens/notes_tags_screen.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/confirmation_dialogue.dart';

const double kChevronWidth = 40.0;
const double kIndentPerLevel = 4.0;
const String _expandedNotebooksKey = 'expanded_notebooks';
const Duration _loadTimeout = Duration(seconds: 10);

class MobileDrawer extends StatefulWidget {
  final VoidCallback onNavigateBack;
  final VoidCallback onCreateNewNotebook;
  final Function(Notebook)? onNotebookSelected;
  final Function(String tag)? onTagSelected;
  final Notebook? selectedNotebook;
  final GlobalKey<ScaffoldState> scaffoldKey;

  const MobileDrawer({
    super.key,
    required this.onNavigateBack,
    required this.onCreateNewNotebook,
    this.onNotebookSelected,
    this.onTagSelected,
    this.selectedNotebook,
    required this.scaffoldKey,
  });

  @override
  State<MobileDrawer> createState() => _MobileDrawerState();
}

class _MobileDrawerState extends State<MobileDrawer>
    with TickerProviderStateMixin {
  late final NotebookRepository _notebookRepository;
  final Map<int, List<Notebook>> _childNotebooks = {};
  final Set<int> _expandedNotebooks = {};
  final Map<int, AnimationController> _animationControllers = {};
  List<Notebook> _notebooks = [];
  bool _isLoading = true;
  String? _errorMessage;
  final bool _isReorderingMode = false;
  bool _showNotebookIcons = true;
  StreamSubscription<bool>? _showNotebookIconsSubscription;

  @override
  void initState() {
    super.initState();
    _initializeRepositories();
    _loadIconSettings();
    _setupIconSettingsListener();
  }

  @override
  void dispose() {
    _showNotebookIconsSubscription?.cancel();
    for (final controller in _animationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadIconSettings() async {
    final showIcons = await EditorSettings.getShowNotebookIcons();
    if (mounted) {
      setState(() {
        _showNotebookIcons = showIcons;
      });
    }
  }

  void _setupIconSettingsListener() {
    _showNotebookIconsSubscription?.cancel();
    _showNotebookIconsSubscription = EditorSettingsEvents
        .showNotebookIconsStream
        .listen((show) {
          if (mounted) {
            setState(() {
              _showNotebookIcons = show;
            });
          }
        });
  }

  @override
  void didUpdateWidget(MobileDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selectedNotebook = widget.selectedNotebook;
    if (selectedNotebook != oldWidget.selectedNotebook &&
        selectedNotebook != null &&
        selectedNotebook.id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (_isLoading) {
          await _loadData();
        }
      });
    }
  }

  Future<void> _saveExpandedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _expandedNotebooksKey,
        _expandedNotebooks.map((id) => id.toString()).toList(),
      );
    } catch (e) {
      print('Error saving expanded state: $e');
    }
  }

  Future<void> _loadExpandedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expandedList = prefs.getStringList(_expandedNotebooksKey) ?? [];
      if (!mounted) return;

      setState(() {
        _expandedNotebooks.clear();
        _expandedNotebooks.addAll(expandedList.map((id) => int.parse(id)));

        for (final id in _expandedNotebooks) {
          final controller = _getAnimationController(id);
          controller.value = 1.0;
        }
      });
    } catch (e) {
      print('Error loading expanded state: $e');
    }
  }

  AnimationController _getAnimationController(int notebookId) {
    if (!_animationControllers.containsKey(notebookId)) {
      _animationControllers[notebookId] = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 200),
      );
    }
    return _animationControllers[notebookId]!;
  }

  Future<void> _initializeRepositories() async {
    try {
      final dbHelper = DatabaseHelper();
      await dbHelper.database;
      _notebookRepository = NotebookRepository(dbHelper);
      await _loadExpandedState();
      await _loadData();
    } catch (e) {
      print('Error initializing repositories: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error initializing database';
        });
      }
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final notebooks = await _notebookRepository
          .getNotebooksByParentId(null)
          .timeout(
            _loadTimeout,
            onTimeout: () {
              throw TimeoutException('Loading notebooks timed out');
            },
          );

      _childNotebooks.clear();

      Future<void> loadNotebookStructure(Notebook notebook) async {
        if (notebook.id != null) {
          try {
            final children = await _notebookRepository
                .getNotebooksByParentId(notebook.id)
                .timeout(
                  _loadTimeout,
                  onTimeout: () {
                    throw TimeoutException(
                      'Loading notebook children timed out',
                    );
                  },
                );

            _childNotebooks[notebook.id!] = children;

            for (final child in children) {
              await loadNotebookStructure(child);
            }
          } catch (e) {
            print('Error loading notebook structure for ${notebook.id}: $e');
          }
        }
      }

      for (final notebook in notebooks) {
        await loadNotebookStructure(notebook);
      }

      if (!mounted) return;

      setState(() {
        _notebooks = notebooks;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading notebooks: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error loading data: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _handleChevronClick(Notebook notebook) async {
    if (notebook.id == null) return;

    final children = _childNotebooks[notebook.id!] ?? [];
    if (children.isEmpty) return;

    final controller = _getAnimationController(notebook.id!);
    final isCurrentlyExpanded = _expandedNotebooks.contains(notebook.id);

    if (isCurrentlyExpanded) {
      await controller.reverse();
      if (mounted) {
        setState(() {
          _expandedNotebooks.remove(notebook.id);
        });
        await _saveExpandedState();
      }
    } else {
      if (mounted) {
        setState(() {
          _expandedNotebooks.add(notebook.id!);
        });
        await _saveExpandedState();
      }
      await controller.forward();
    }
  }

  Future<void> _reorderNotebooks(int? parentId) async {
    final repo = NotebookRepository(DatabaseHelper());
    final notebooks = await repo.getNotebooksByParentId(parentId);
    for (int i = 0; i < notebooks.length; i++) {
      if (notebooks[i].orderIndex != i) {
        await repo.updateNotebook(notebooks[i].copyWith(orderIndex: i));
      }
    }
  }

  Widget _buildNotebookNode(
    Notebook notebook, {
    int level = 0,
    bool isLast = false,
  }) {
    final children =
        notebook.id != null ? _childNotebooks[notebook.id!] ?? [] : [];
    final controller =
        notebook.id != null ? _getAnimationController(notebook.id!) : null;
    final isExpanded =
        notebook.id != null && _expandedNotebooks.contains(notebook.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _isReorderingMode
            ? DragTarget<Map<String, dynamic>>(
              onWillAcceptWithDetails: (details) {
                final data = details.data;
                if (data['type'] == 'notebook') {
                  final dragged = data['notebook'] as Notebook;
                  return dragged.id != notebook.id;
                }
                return false;
              },
              onAcceptWithDetails: (details) async {
                final data = details.data;
                if (data['type'] == 'notebook') {
                  final draggedNotebook = data['notebook'] as Notebook;
                  final repo = NotebookRepository(DatabaseHelper());
                  await repo.updateNotebook(
                    draggedNotebook.copyWith(
                      parentId: notebook.id,
                      orderIndex: children.length,
                    ),
                  );
                  await _reorderNotebooks(notebook.id);
                  if (mounted) {
                    await _loadData();
                    setState(() {
                      _expandedNotebooks.add(notebook.id!);
                    });
                    final controller = _getAnimationController(notebook.id!);
                    controller.forward();
                  }
                }
              },
              builder: (context, candidateData, rejectedData) {
                return Draggable<Map<String, dynamic>>(
                  data: {'type': 'notebook', 'notebook': notebook},
                  feedback: Material(
                    color: Colors.transparent,
                    child: SizedBox(
                      width: 220,
                      child: Opacity(
                        opacity: 0.7,
                        child: _notebookRow(notebook, level),
                      ),
                    ),
                  ),
                  child: _notebookRow(notebook, level),
                );
              },
            )
            : _notebookRow(notebook, level),
        if (notebook.id != null && isExpanded)
          SizeTransition(
            sizeFactor: controller!,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...children.asMap().entries.map((entry) {
                  final index = entry.key;
                  final child = entry.value;
                  return _buildNotebookNode(
                    child,
                    level: level + 1,
                    isLast: index == children.length - 1,
                  );
                }),
              ],
            ),
          ),
      ],
    );
  }

  Widget _notebookRow(Notebook notebook, int level) {
    final children =
        notebook.id != null ? _childNotebooks[notebook.id!] ?? [] : [];
    final isExpanded =
        notebook.id != null && _expandedNotebooks.contains(notebook.id);
    final hasContent = children.isNotEmpty;
    final isSelected = widget.selectedNotebook?.id == notebook.id;
    final colorScheme = Theme.of(context).colorScheme;

    final notebookIcon =
        notebook.iconId != null
            ? NotebookIconsRepository.getIconById(notebook.iconId!)
            : null;
    final defaultIcon = NotebookIconsRepository.getDefaultIcon();
    final iconToShow = notebookIcon ?? defaultIcon;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap:
            _isReorderingMode
                ? null
                : () {
                  widget.onNotebookSelected?.call(notebook);
                  Navigator.pop(context);
                },
        onLongPress:
            _isReorderingMode
                ? null
                : () {
                  if (notebook.id != null) {
                    _showContextMenu(notebook);
                  }
                },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          color:
              isSelected
                  ? colorScheme.surfaceContainerHigh
                  : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: kIndentPerLevel * level),
              SizedBox(
                width: kChevronWidth,
                child: IconButton(
                  icon: AnimatedRotation(
                    turns: isExpanded ? 0.25 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color:
                          hasContent
                              ? colorScheme.primary
                              : colorScheme.onSurface.withAlpha(97),
                    ),
                  ),
                  onPressed:
                      hasContent ? () => _handleChevronClick(notebook) : null,
                  splashRadius: 16,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
              if (_showNotebookIcons) ...[
                Icon(iconToShow.icon, color: colorScheme.primary),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  notebook.name,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_showNotebookIcons && notebook.isFavorite)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.favorite_rounded,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> createNewNotebook() async {
    try {
      final name = await _promptForName('Notebook Name', 'Name');
      if (name == null || name.trim().isEmpty) return;

      final notebooks = await _notebookRepository.getNotebooksByParentId(
        widget.selectedNotebook?.id,
      );
      final lastOrderIndex = notebooks.isEmpty ? 0 : notebooks.length;

      final newNotebook = Notebook(
        name: name.trim(),
        parentId: widget.selectedNotebook?.id,
        createdAt: DateTime.now(),
        orderIndex: lastOrderIndex,
        iconId: NotebookIconsRepository.getDefaultIcon().id,
      );

      final notebookId = await _notebookRepository.createNotebook(newNotebook);
      final createdNotebook = await _notebookRepository.getNotebook(notebookId);

      if (createdNotebook != null) {
        widget.onNotebookSelected?.call(createdNotebook);
        await _loadData();
      }
    } catch (e) {
      debugPrint('Error creating notebook: $e');
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error creating notebook: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  Future<String?> _promptForName(
    String title,
    String label, {
    String? initialValue,
  }) async {
    final nameController = TextEditingController(text: initialValue);
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      barrierDismissible: true,
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final FocusNode focusNode = FocusNode();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (focusNode.canRequestFocus) {
              focusNode.requestFocus();
            }
          });
        });

        return Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 400,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded, color: colorScheme.primary),
                          const SizedBox(width: 12),
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: colorScheme.onSurface,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: nameController,
                            focusNode: focusNode,
                            autofocus: true,
                            decoration: InputDecoration(
                              labelText: label,
                              border: const OutlineInputBorder(),
                              prefixIcon: Icon(
                                Icons.title_rounded,
                                color: colorScheme.primary,
                              ),
                            ),
                            onFieldSubmitted: (value) {
                              if (formKey.currentState!.validate()) {
                                Navigator.of(context).pop(value);
                              }
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                if (formKey.currentState!.validate()) {
                                  Navigator.of(
                                    context,
                                  ).pop(nameController.text);
                                }
                              },
                              child: const Text(
                                'Accept',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    return result;
  }

  void _showContextMenu(Notebook notebook) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      builder:
          (context) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom,
            ),
            child: Container(
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha(50),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _showRenameDialog(notebook);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_rounded,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            const Text('Rename Notebook'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _showIconSelector(notebook);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.folder_rounded,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            const Text('Change Icon'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        Navigator.pop(context);
                        final dbHelper = DatabaseHelper();
                        final notebookRepository = NotebookRepository(dbHelper);
                        final updatedNotebook = notebook.copyWith(
                          isFavorite: !notebook.isFavorite,
                        );
                        await notebookRepository.updateNotebook(
                          updatedNotebook,
                        );
                        if (mounted) {
                          await _loadData();
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              notebook.isFavorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              notebook.isFavorite
                                  ? 'Remove from Favorites'
                                  : 'Add to Favorites',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        Navigator.pop(context);
                        final colorScheme = Theme.of(context).colorScheme;
                        final confirmed = await showDeleteConfirmationDialog(
                          context: context,
                          title: 'Move to Trash',
                          message:
                              'Are you sure you want to move this notebook to trash?\n${notebook.name}',
                          confirmText: 'Move to Trash',
                          confirmColor: colorScheme.error,
                        );

                        if (confirmed == true) {
                          final dbHelper = DatabaseHelper();
                          final notebookRepository = NotebookRepository(
                            dbHelper,
                          );
                          await notebookRepository.softDeleteNotebook(
                            notebook.id!,
                          );
                          if (mounted) {
                            await _loadData();
                          }
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_rounded,
                              size: 20,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            const Text('Move to Trash'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _showRenameDialog(Notebook notebook) {
    final TextEditingController controller = TextEditingController(
      text: notebook.name,
    );

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final colorScheme = Theme.of(context).colorScheme;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 400,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(Icons.edit_rounded, color: colorScheme.primary),
                        const SizedBox(width: 12),
                        Text(
                          'Rename Notebook',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: colorScheme.onSurface,
                          ),
                          onPressed: () => Navigator.of(dialogContext).pop(),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: controller,
                          autofocus: true,
                          decoration: InputDecoration(
                            labelText: 'Notebook name',
                            border: const OutlineInputBorder(),
                            prefixIcon: Icon(
                              Icons.title_rounded,
                              color: colorScheme.primary,
                            ),
                          ),
                          onFieldSubmitted: (value) {
                            if (value.isNotEmpty) {
                              Navigator.of(dialogContext).pop();
                              _handleRename(notebook, value);
                            }
                          },
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              if (controller.text.isNotEmpty) {
                                Navigator.of(dialogContext).pop();
                                _handleRename(notebook, controller.text);
                              }
                            },
                            child: const Text(
                              'Rename',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleRename(Notebook notebook, String newName) async {
    if (newName.trim().isEmpty) return;

    try {
      final dbHelper = DatabaseHelper();
      final notebookRepository = NotebookRepository(dbHelper);
      await notebookRepository.updateNotebook(
        notebook.copyWith(name: newName.trim()),
      );

      if (mounted) {
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error renaming: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  Future<void> _handleIconChange(Notebook notebook, int iconId) async {
    try {
      final dbHelper = DatabaseHelper();
      final notebookRepository = NotebookRepository(dbHelper);
      await notebookRepository.updateNotebook(
        notebook.copyWith(iconId: iconId),
      );

      if (mounted) {
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error changing icon: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  void _showIconSelector(Notebook notebook) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => IconSelectorScreen(
              currentIconId: notebook.iconId,
              onIconSelected: (iconId) => _handleIconChange(notebook, iconId),
            ),
      ),
    );
  }

  void _handleOpenTrash() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => TrashScreen(
              onNotebookRestored: (notebook) {
                widget.onNotebookSelected?.call(notebook);
                _loadData();
              },
              onNoteRestored: (note) {
                _loadData();
              },
              onThinkRestored: (think) {
                _loadData();
              },
              onTrashUpdated: () {
                _loadData();
              },
            ),
      ),
    ).then((_) {
      if (mounted) {
        widget.scaffoldKey.currentState?.openDrawer();
      }
    });
  }

  void _handleOpenTags() {
    final navigator = Navigator.of(context);

    navigator.pop();

    navigator.push(
      MaterialPageRoute(
        builder:
            (context) => NotesTagsScreen(onTagSelected: widget.onTagSelected),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Drawer(
      backgroundColor: colorScheme.surfaceContainerLow,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.book_rounded,
                    color: colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Notebooks',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  widget.onNotebookSelected?.call(
                    Notebook(
                      id: null,
                      name: '',
                      parentId: null,
                      createdAt: DateTime.now(),
                      orderIndex: 0,
                      iconId: NotebookIconsRepository.getDefaultIcon().id,
                    ),
                  );
                  Navigator.pop(context);
                },
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _errorMessage != null
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _errorMessage!,
                                style: TextStyle(color: colorScheme.error),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadData,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                        : _notebooks.isEmpty
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.folder_open,
                                size: 48,
                                color: colorScheme.primary.withAlpha(128),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No notebooks in this folder',
                                style: TextStyle(
                                  color: colorScheme.onSurface.withAlpha(128),
                                ),
                              ),
                            ],
                          ),
                        )
                        : ListView.builder(
                          itemCount: _notebooks.length,
                          itemBuilder: (context, index) {
                            final notebook = _notebooks[index];
                            return RepaintBoundary(
                              child: _buildNotebookNode(
                                notebook,
                                isLast: index == _notebooks.length - 1,
                              ),
                            );
                          },
                        ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: colorScheme.outlineVariant,
                    width: 0.5,
                  ),
                ),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.delete_rounded,
                            color: colorScheme.error,
                            size: 28,
                          ),
                          style: IconButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.all(8),
                          ),
                          onPressed: _handleOpenTrash,
                        ),
                        const SizedBox(width: 2),
                        IconButton(
                          icon: Icon(
                            Symbols.tag_rounded,
                            color: colorScheme.primary,
                            size: 28,
                          ),
                          style: IconButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.all(8),
                          ),
                          onPressed: _handleOpenTags,
                        ),
                        const SizedBox(width: 2),
                        IconButton(
                          icon: Icon(
                            Icons.create_new_folder_rounded,
                            color: colorScheme.primary,
                            size: 28,
                          ),
                          style: IconButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.all(8),
                          ),
                          onPressed: createNewNotebook,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
