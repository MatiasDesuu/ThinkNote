import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../database/models/notebook.dart';
import '../database/models/note.dart';
import '../database/models/notebook_icons.dart';
import '../database/repositories/notebook_repository.dart';
import '../database/repositories/note_repository.dart';
import '../database/database_helper.dart';
import '../database/database_service.dart';
import '../Settings/editor_settings_panel.dart';
import 'custom_snackbar.dart';
import 'context_menu.dart';
import 'icon_selector_dialog.dart';

const double kChevronWidth = 40.0;
const double kIndentPerLevel = 4.0;
const String _expandedNotebooksKey = 'expanded_notebooks';
const Duration _loadTimeout = Duration(seconds: 10);

class DatabaseSidebar extends StatefulWidget {
  final Notebook? selectedNotebook;
  final Function(Notebook) onNotebookSelected;
  final VoidCallback? onTrashUpdated;
  final VoidCallback? onExpansionChanged;
  final Function(Notebook)? onNotebookDeleted;

  const DatabaseSidebar({
    super.key,
    this.selectedNotebook,
    required this.onNotebookSelected,
    this.onTrashUpdated,
    this.onExpansionChanged,
    this.onNotebookDeleted,
  });

  @override
  State<DatabaseSidebar> createState() => DatabaseSidebarState();
}

class DatabaseSidebarState extends State<DatabaseSidebar>
    with TickerProviderStateMixin {
  late final NotebookRepository _notebookRepository;
  final Map<int, List<Notebook>> _childNotebooks = {};
  final Set<int> _expandedNotebooks = {};
  final Map<int, AnimationController> _animationControllers = {};
  List<Notebook> _notebooks = [];
  bool _isLoading = true;
  String? _errorMessage;
  late StreamSubscription<void> _databaseChangeSubscription;
  bool _showNotebookIcons = true;
  StreamSubscription<bool>? _showNotebookIconsSubscription;

  bool get areAllNotebooksExpanded {
    bool checkNotebookRecursively(Notebook notebook) {
      if (notebook.id != null &&
          _childNotebooks[notebook.id!]?.isNotEmpty == true) {
        if (!_expandedNotebooks.contains(notebook.id)) {
          return false;
        }
        // Verificar recursivamente los notebooks hijos
        for (final child in _childNotebooks[notebook.id!]!) {
          if (!checkNotebookRecursively(child)) {
            return false;
          }
        }
      }
      return true;
    }

    // Verificar todos los notebooks raíz
    for (final notebook in _notebooks) {
      if (!checkNotebookRecursively(notebook)) {
        return false;
      }
    }
    return true;
  }

  Widget buildTrailingButton() {
    return IconButton(
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return ScaleTransition(
            scale: animation,
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: Icon(
          areAllNotebooksExpanded
              ? Icons.unfold_less_rounded
              : Icons.unfold_more_rounded,
          size: 16,
          key: ValueKey<bool>(areAllNotebooksExpanded),
        ),
      ),
      onPressed: toggleAllNotebooks,
    );
  }

  Future<void> toggleAllNotebooks() async {
    final shouldExpand = !areAllNotebooksExpanded;
    final Set<int> newExpandedState = {};

    void toggleNotebookRecursively(Notebook notebook) {
      if (notebook.id != null &&
          _childNotebooks[notebook.id!]?.isNotEmpty == true) {
        if (shouldExpand) {
          newExpandedState.add(notebook.id!);
          _getAnimationController(notebook.id!).value = 1.0;
        } else {
          _getAnimationController(notebook.id!).value = 0.0;
        }

        // Procesar recursivamente los notebooks hijos
        for (final child in _childNotebooks[notebook.id!]!) {
          toggleNotebookRecursively(child);
        }
      }
    }

    // Procesar todos los notebooks raíz en una sola pasada
    for (final notebook in _notebooks) {
      toggleNotebookRecursively(notebook);
    }

    // Actualizar el estado una sola vez
    setState(() {
      _expandedNotebooks.clear();
      if (shouldExpand) {
        _expandedNotebooks.addAll(newExpandedState);
      }
    });

    // Guardar el estado una sola vez al final
    await _saveExpandedState();
    widget.onExpansionChanged?.call();
  }

  @override
  void initState() {
    super.initState();
    _initializeRepositories();
    _loadIconSettings();
    _setupIconSettingsListener();
    _databaseChangeSubscription = DatabaseService().onDatabaseChanged.listen((
      _,
    ) {
      _loadData();
    });
  }

  @override
  void didUpdateWidget(DatabaseSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedNotebook?.id != oldWidget.selectedNotebook?.id) {
      if (widget.selectedNotebook?.id != null) {
        handleNotebookSelection(widget.selectedNotebook);
      }
    }
  }

  Future<void> handleNotebookSelection(Notebook? notebook) async {
    if (notebook?.id == null) return;

    // Expandir todas las carpetas padre
    Notebook? currentParent = notebook;
    while (currentParent?.parentId != null) {
      currentParent = _findParentNotebook(currentParent!.parentId, _notebooks);
      if (currentParent != null) {
        await forceExpandNotebook(currentParent);
      }
    }
  }

  @override
  void dispose() {
    _databaseChangeSubscription.cancel();
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

      // Función recursiva para cargar la estructura completa
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

            // Cargar recursivamente todos los hijos
            for (final child in children) {
              await loadNotebookStructure(child);
            }
          } catch (e) {
            print('Error loading notebook structure for ${notebook.id}: $e');
          }
        }
      }

      // Cargar la estructura completa para todos los notebooks raíz
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

  Future<void> loadNotebookChildren(Notebook notebook) async {
    if (notebook.id == null) return;

    try {
      final controller = _getAnimationController(notebook.id!);
      final isCurrentlyExpanded = _expandedNotebooks.contains(notebook.id);

      setState(() {
        if (isCurrentlyExpanded) {
          _expandedNotebooks.remove(notebook.id);
        } else {
          _expandedNotebooks.add(notebook.id!);
        }
      });
      await _saveExpandedState();

      if (isCurrentlyExpanded) {
        await controller.reverse();
      } else {
        await controller.forward();
      }
    } catch (e) {
      print('Error loading notebook children: $e');
    }
  }

  Future<void> forceExpandNotebook(Notebook notebook) async {
    if (notebook.id == null) return;

    try {
      final controller = _getAnimationController(notebook.id!);

      if (!_expandedNotebooks.contains(notebook.id)) {
        if (!mounted) return;

        setState(() {
          _expandedNotebooks.add(notebook.id!);
        });
        await _saveExpandedState();
        await controller.forward();
      }
    } catch (e) {
      print('Error forcing notebook expansion: $e');
    }
  }

  Notebook? _findParentNotebook(int? parentId, List<Notebook> notebooks) {
    for (final notebook in notebooks) {
      if (notebook.id == parentId) return notebook;
      final children = _childNotebooks[notebook.id!];
      if (children != null && children.isNotEmpty) {
        final found = _findParentNotebook(parentId, children);
        if (found != null) return found;
      }
    }
    return null;
  }

  void _showRenameDialog(Notebook notebook) {
    final TextEditingController controller = TextEditingController(
      text: notebook.name,
    );

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 400,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
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
                          Icon(
                            Icons.edit_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Rename Notebook',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
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
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: TextFormField(
                        controller: controller,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: 'Notebook name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest.withAlpha(76),
                          prefixIcon: const Icon(Icons.title_rounded),
                        ),
                        onFieldSubmitted:
                            (_) => _handleRename(notebook, controller.text),
                      ),
                    ),
                    // Botones
                    Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                backgroundColor:
                                    Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHigh,
                                foregroundColor:
                                    Theme.of(context).colorScheme.onSurface,
                                minimumSize: const Size(0, 44),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.primary,
                                foregroundColor:
                                    Theme.of(context).colorScheme.onPrimary,
                                minimumSize: const Size(0, 44),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed:
                                  () =>
                                      _handleRename(notebook, controller.text),
                              child: const Text(
                                'Rename',
                                style: TextStyle(
                                  fontSize: 15,
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
  }

  Future<void> _handleRename(Notebook notebook, String newName) async {
    if (newName.trim().isEmpty) return;

    try {
      await _notebookRepository.updateNotebook(
        notebook.copyWith(name: newName.trim()),
      );

      if (mounted) {
        Navigator.pop(context);
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

  Future<void> _showIconSelectorDialog(Notebook notebook) async {
    final selectedIconId = await showDialog<int>(
      context: context,
      builder:
          (context) => IconSelectorDialog(
            currentIconId: notebook.iconId,
            notebookName: notebook.name,
          ),
    );

    if (selectedIconId != null && mounted) {
      await _handleIconChange(notebook, selectedIconId);
    }
  }

  Future<void> _handleIconChange(Notebook notebook, int iconId) async {
    try {
      await _notebookRepository.updateNotebook(
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

  void _showContextMenu(
    BuildContext context,
    Offset tapPosition,
    Notebook notebook,
  ) {
    ContextMenuOverlay.show(
      context: context,
      tapPosition: tapPosition,
      items: [
        ContextMenuItem(
          icon: Icons.edit_rounded,
          label: 'Rename Notebook',
          onTap: () => _showRenameDialog(notebook),
        ),
        ContextMenuItem(
          icon: Icons.palette_rounded,
          label: 'Change Icon',
          onTap: () => _showIconSelectorDialog(notebook),
        ),
        ContextMenuItem(
          icon:
              notebook.isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
          label:
              notebook.isFavorite
                  ? 'Remove from Favorites'
                  : 'Add to Favorites',
          onTap: () async {
            await _notebookRepository.updateNotebook(
              notebook.copyWith(isFavorite: !notebook.isFavorite),
            );
            if (mounted) {
              await _loadData();
            }
          },
        ),
        ContextMenuItem(
          icon: Icons.delete_rounded,
          label: 'Move to Trash',
          iconColor: Theme.of(context).colorScheme.error,
          onTap: () async {
            await _notebookRepository.softDeleteNotebook(notebook.id!);
            if (mounted) {
              widget.onNotebookDeleted?.call(notebook);
              await _loadData();
              widget.onTrashUpdated?.call();
            }
          },
        ),
      ],
    );
  }

  Future<void> _handleChevronClick(Notebook notebook) async {
    if (notebook.id == null) return;

    final children = _childNotebooks[notebook.id!] ?? [];
    if (children.isEmpty) return; // No expandir si no hay hijos

    final controller = _getAnimationController(notebook.id!);
    final isCurrentlyExpanded = _expandedNotebooks.contains(notebook.id);

    setState(() {
      if (isCurrentlyExpanded) {
        _expandedNotebooks.remove(notebook.id);
      } else {
        _expandedNotebooks.add(notebook.id!);
      }
    });
    await _saveExpandedState();

    if (isCurrentlyExpanded) {
      await controller.reverse();
    } else {
      await controller.forward();
    }
  }

  Future<void> _reorderNotebooks(int? parentId) async {
    final repo = NotebookRepository(DatabaseHelper());
    final notebooks = await repo.getNotebooksByParentId(parentId);

    // Ordenar los notebooks por su orderIndex actual
    notebooks.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    // Actualizar el orderIndex de cada notebook
    for (int i = 0; i < notebooks.length; i++) {
      if (notebooks[i].orderIndex != i) {
        await repo.updateNotebook(notebooks[i].copyWith(orderIndex: i));
      }
    }
  }

  Future<void> _moveNotebook(
    Notebook draggedNotebook,
    Notebook targetNotebook,
    bool isBefore,
  ) async {
    final repo = NotebookRepository(DatabaseHelper());

    // Verificar si el movimiento crearía una referencia circular
    bool wouldCreateCircularReference(Notebook notebook, int? targetParentId) {
      if (targetParentId == null) return false;
      if (notebook.id == targetParentId) return true;

      // Obtener el notebook objetivo
      final targetNotebook = _findParentNotebook(targetParentId, _notebooks);
      if (targetNotebook == null) return false;

      // Verificar si el notebook objetivo es un hijo del notebook arrastrado
      Notebook? current = targetNotebook;
      while (current?.parentId != null) {
        if (current?.parentId == notebook.id) return true;
        current = _findParentNotebook(current!.parentId, _notebooks);
      }
      return false;
    }

    // Si el movimiento crearía una referencia circular, no permitirlo
    if (wouldCreateCircularReference(draggedNotebook, targetNotebook.id)) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Cannot move a notebook inside its own subnotebooks',
          type: CustomSnackbarType.error,
        );
      }
      return;
    }

    // Obtener todos los notebooks hijos del notebook arrastrado
    List<Notebook> getAllChildren(Notebook parent) {
      List<Notebook> children = [];
      final directChildren = _childNotebooks[parent.id!] ?? [];
      children.addAll(directChildren);
      for (final child in directChildren) {
        children.addAll(getAllChildren(child));
      }
      return children;
    }

    final allChildren =
        draggedNotebook.id != null ? getAllChildren(draggedNotebook) : [];

    // Si estamos moviendo dentro de otro notebook
    if (!isBefore && targetNotebook.id != null) {
      // Obtener los notebooks hijos del notebook objetivo
      final targetChildren = await repo.getNotebooksByParentId(
        targetNotebook.id,
      );

      // Actualizar el notebook arrastrado
      await repo.updateNotebook(
        draggedNotebook.copyWith(
          parentId: targetNotebook.id,
          orderIndex: targetChildren.length,
        ),
      );

      // Actualizar el parentId de todos los hijos del notebook arrastrado
      for (final child in allChildren) {
        if (child.id != null) {
          await repo.updateNotebook(child);
        }
      }

      await _reorderNotebooks(targetNotebook.id);

      if (mounted) {
        await _loadData();
        // Solo expandimos el notebook objetivo cuando movemos dentro de él
        setState(() {
          _expandedNotebooks.add(targetNotebook.id!);
        });
        final controller = _getAnimationController(targetNotebook.id!);
        controller.forward();
      }
    } else {
      // Obtener todos los notebooks del mismo nivel
      final siblings = await repo.getNotebooksByParentId(
        targetNotebook.parentId,
      );

      // Ordenar los notebooks por su orderIndex actual
      siblings.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

      // Encontrar el índice del notebook objetivo
      final targetIndex = siblings.indexWhere((n) => n.id == targetNotebook.id);
      if (targetIndex == -1) return;

      // Calcular el nuevo orderIndex
      final newOrderIndex = isBefore ? targetIndex : targetIndex + 1;

      // Actualizar el orderIndex de todos los notebooks afectados
      for (final notebook in siblings) {
        if (notebook.id == draggedNotebook.id) continue;

        int newIndex = notebook.orderIndex;
        if (notebook.orderIndex >= newOrderIndex) {
          newIndex++;
        }

        await repo.updateNotebook(notebook.copyWith(orderIndex: newIndex));
      }

      // Actualizar el notebook arrastrado
      await repo.updateNotebook(
        draggedNotebook.copyWith(
          parentId: targetNotebook.parentId,
          orderIndex: newOrderIndex,
        ),
      );

      // Reordenar todos los notebooks para asegurar consistencia
      await _reorderNotebooks(targetNotebook.parentId);

      if (mounted) {
        await _loadData();
        // No expandimos ningún notebook cuando solo reordenamos
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Indicador de inserción antes del notebook
        DragTarget<Map<String, dynamic>>(
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
              await _moveNotebook(draggedNotebook, notebook, true);
              if (mounted) {
                await _loadData();
              }
            }
          },
          builder: (context, candidateData, rejectedData) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: candidateData.isNotEmpty ? 8 : 2,
              margin: EdgeInsets.symmetric(
                horizontal: candidateData.isNotEmpty ? 8 : 0,
              ),
              decoration: BoxDecoration(
                color:
                    candidateData.isNotEmpty
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                borderRadius:
                    candidateData.isNotEmpty ? BorderRadius.circular(4) : null,
                boxShadow:
                    candidateData.isNotEmpty
                        ? [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withAlpha(76),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                        : null,
              ),
            );
          },
        ),
        DragTarget<Map<String, dynamic>>(
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
              await _moveNotebook(draggedNotebook, notebook, false);
              if (mounted) {
                await _loadData();
              }
            }
          },
          builder: (context, candidateData, rejectedData) {
            return Draggable<Map<String, dynamic>>(
              data: {'type': 'notebook', 'notebook': notebook},
              feedback: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(51),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_showNotebookIcons) ...[
                        Icon(
                          (notebook.iconId != null
                                      ? NotebookIconsRepository.getIconById(
                                        notebook.iconId!,
                                      )
                                      : null)
                                  ?.icon ??
                              NotebookIconsRepository.getDefaultIcon().icon,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        notebook.name,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              child: GestureDetector(
                onSecondaryTapDown: (details) {
                  if (notebook.id != null) {
                    _showContextMenu(context, details.globalPosition, notebook);
                  }
                },
                child: _notebookRow(notebook, level),
              ),
            );
          },
        ),
        if (notebook.id != null)
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
                // Indicador de inserción al final de los hijos
                DragTarget<Map<String, dynamic>>(
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
                      await _moveNotebook(draggedNotebook, notebook, false);
                      if (mounted) {
                        await _loadData();
                      }
                    }
                  },
                  builder: (context, candidateData, rejectedData) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      height: candidateData.isNotEmpty ? 8 : 2,
                      margin: EdgeInsets.symmetric(
                        horizontal: candidateData.isNotEmpty ? 8 : 0,
                      ),
                      decoration: BoxDecoration(
                        color:
                            candidateData.isNotEmpty
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                        borderRadius:
                            candidateData.isNotEmpty
                                ? BorderRadius.circular(4)
                                : null,
                        boxShadow:
                            candidateData.isNotEmpty
                                ? [
                                  BoxShadow(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary.withAlpha(76),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                                : null,
                      ),
                    );
                  },
                ),
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

    final notebookIcon =
        notebook.iconId != null
            ? NotebookIconsRepository.getIconById(notebook.iconId!)
            : null;
    final defaultIcon = NotebookIconsRepository.getDefaultIcon();
    final iconToShow = notebookIcon ?? defaultIcon;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: DragTarget<Map<String, dynamic>>(
          onWillAcceptWithDetails: (details) {
            final data = details.data;
            // Aceptar tanto notebooks como notas
            return (data['type'] == 'notebook' &&
                    data['notebook'].id != notebook.id) ||
                (data['type'] == 'note' && notebook.id != null);
          },
          onAcceptWithDetails: (details) async {
            final data = details.data;
            if (data['type'] == 'notebook') {
              final draggedNotebook = data['notebook'] as Notebook;
              await _moveNotebook(draggedNotebook, notebook, false);
              if (mounted) {
                await _loadData();
              }
            } else if (data['type'] == 'note' && notebook.id != null) {
              final isMultiDrag = data['isMultiDrag'] as bool;
              final selectedNotes = data['selectedNotes'] as List<dynamic>;
              final noteRepo = NoteRepository(DatabaseHelper());

              try {
                // Get the last orderIndex in the target notebook
                final notesInTarget = await noteRepo.getNotesByNotebookId(
                  notebook.id!,
                );
                var nextOrder =
                    notesInTarget.isEmpty ? 0 : notesInTarget.length;

                // Move all selected notes
                for (final noteData in selectedNotes) {
                  final note = noteData as Note;
                  await noteRepo.updateNote(
                    note.copyWith(
                      notebookId: notebook.id,
                      orderIndex: nextOrder++,
                      updatedAt: DateTime.now(),
                    ),
                  );
                }

                if (mounted) {
                  CustomSnackbar.show(
                    context: context,
                    message:
                        isMultiDrag
                            ? '${selectedNotes.length} notes moved successfully'
                            : 'Note moved successfully',
                    type: CustomSnackbarType.success,
                  );
                }
              } catch (e) {
                print('Error moving notes: $e');
                if (mounted) {
                  CustomSnackbar.show(
                    context: context,
                    message: 'Error moving notes',
                    type: CustomSnackbarType.error,
                  );
                }
              }
            }
          },
          builder: (context, candidateData, rejectedData) {
            return InkWell(
              onTap: () {
                widget.onNotebookSelected(notebook);
              },
              borderRadius: BorderRadius.circular(4),
              hoverColor: Theme.of(context).colorScheme.surfaceContainerHigh,
              child: Container(
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? Theme.of(context).colorScheme.surfaceContainerHigh
                          : candidateData.isNotEmpty
                          ? Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withAlpha(76)
                          : Colors.transparent,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(width: kIndentPerLevel * level),
                    SizedBox(
                      width: kChevronWidth,
                      child:
                          hasContent
                              ? MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: () => _handleChevronClick(notebook),
                                  child: AnimatedRotation(
                                    turns: isExpanded ? 0.25 : 0.0,
                                    duration: const Duration(milliseconds: 200),
                                    child: Icon(
                                      Icons.chevron_right_rounded,
                                      size: 20,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                              )
                              : const SizedBox(width: kChevronWidth),
                    ),
                    SizedBox(
                      height: 24,
                      child:
                          _showNotebookIcons
                              ? Icon(
                                iconToShow.icon,
                                color: Theme.of(context).colorScheme.primary,
                              )
                              : null,
                    ),
                    if (_showNotebookIcons) const SizedBox(width: 8),
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
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 32,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_notebooks.isEmpty) {
      return const Center(child: Text('No notebooks available'));
    }

    return SizedBox.expand(
      child: DragTarget<Map<String, dynamic>>(
        onWillAcceptWithDetails: (details) {
          final data = details.data;
          if (data['type'] == 'notebook') {
            final dragged = data['notebook'] as Notebook;
            return dragged.parentId != null;
          }
          return false;
        },
        onAcceptWithDetails: (details) async {
          final data = details.data;
          if (data['type'] == 'notebook') {
            final draggedNotebook = data['notebook'] as Notebook;
            final repo = NotebookRepository(DatabaseHelper());

            try {
              // Mover a la raíz
              final updatedNotebook = Notebook(
                id: draggedNotebook.id,
                name: draggedNotebook.name,
                parentId: null,
                createdAt: draggedNotebook.createdAt,
                orderIndex: _notebooks.length,
                isFavorite: draggedNotebook.isFavorite,
                deletedAt: draggedNotebook.deletedAt,
                iconId: draggedNotebook.iconId,
              );

              await repo.updateNotebook(updatedNotebook);
              await _reorderNotebooks(null);

              if (mounted) {
                await _loadData();
              }
            } catch (e) {
              print('Error updating notebook: $e');
            }
          }
        },
        builder: (context, candidateData, rejectedData) {
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    widget.onNotebookSelected(
                      Notebook(
                        id: null,
                        name: '',
                        parentId: null,
                        createdAt: DateTime.now(),
                        orderIndex: 0,
                      ),
                    );
                  },
                  child: Container(
                    color:
                        candidateData.isNotEmpty
                            ? Theme.of(
                              context,
                            ).colorScheme.primaryContainer.withAlpha(76)
                            : Colors.transparent,
                  ),
                ),
              ),
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ..._notebooks.asMap().entries.map((entry) {
                      final index = entry.key;
                      final notebook = entry.value;
                      return _buildNotebookNode(
                        notebook,
                        isLast: index == _notebooks.length - 1,
                      );
                    }),
                    // Indicador de inserción al final de la lista raíz
                    DragTarget<Map<String, dynamic>>(
                      onWillAcceptWithDetails: (details) {
                        final data = details.data;
                        if (data['type'] == 'notebook') {
                          final dragged = data['notebook'] as Notebook;
                          return dragged.parentId == null;
                        }
                        return false;
                      },
                      onAcceptWithDetails: (details) async {
                        final data = details.data;
                        if (data['type'] == 'notebook') {
                          final draggedNotebook = data['notebook'] as Notebook;
                          final repo = NotebookRepository(DatabaseHelper());

                          // Mover a la raíz al final
                          final updatedNotebook = Notebook(
                            id: draggedNotebook.id,
                            name: draggedNotebook.name,
                            parentId: null,
                            createdAt: draggedNotebook.createdAt,
                            orderIndex: _notebooks.length,
                            isFavorite: draggedNotebook.isFavorite,
                            deletedAt: draggedNotebook.deletedAt,
                            iconId: draggedNotebook.iconId,
                          );

                          await repo.updateNotebook(updatedNotebook);
                          await _reorderNotebooks(null);

                          if (mounted) {
                            await _loadData();
                          }
                        }
                      },
                      builder: (context, candidateData, rejectedData) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          height: candidateData.isNotEmpty ? 8 : 2,
                          margin: EdgeInsets.symmetric(
                            horizontal: candidateData.isNotEmpty ? 8 : 0,
                          ),
                          decoration: BoxDecoration(
                            color:
                                candidateData.isNotEmpty
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                            borderRadius:
                                candidateData.isNotEmpty
                                    ? BorderRadius.circular(4)
                                    : null,
                            boxShadow:
                                candidateData.isNotEmpty
                                    ? [
                                      BoxShadow(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary.withAlpha(76),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                    : null,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void reloadSidebar() {
    _loadData();
  }
}
