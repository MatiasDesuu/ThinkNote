import 'package:flutter/material.dart';
import '../../database/models/notebook.dart';
import '../../database/models/notebook_icons.dart';
import '../../database/repositories/notebook_repository.dart';
import '../../database/database_helper.dart';

class NotebookSelectorScreen extends StatefulWidget {
  final Notebook? currentNotebook;
  final Function(Notebook) onNotebookSelected;

  const NotebookSelectorScreen({
    super.key,
    this.currentNotebook,
    required this.onNotebookSelected,
  });

  @override
  State<NotebookSelectorScreen> createState() => _NotebookSelectorScreenState();
}

class _NotebookSelectorScreenState extends State<NotebookSelectorScreen>
    with TickerProviderStateMixin {
  Notebook? _selectedNotebook;
  List<Notebook> _allNotebooks = [];
  Map<int, List<Notebook>> _notebookStructure = {};
  final Set<int> _expandedNotebooks = {};
  final Map<int, AnimationController> _animationControllers = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedNotebook = widget.currentNotebook;
    _loadNotebooks();
  }

  @override
  void dispose() {
    for (final controller in _animationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadNotebooks() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final dbHelper = DatabaseHelper();
      final notebookRepository = NotebookRepository(dbHelper);

      // Cargar todos los notebooks
      final allNotebooks = await notebookRepository.getAllNotebooks();

      // Crear estructura padre-hijo
      final Map<int, List<Notebook>> structure = {};

      // Obtener notebooks raíz
      final rootNotebooks =
          allNotebooks.where((n) => n.parentId == null).toList();

      // Construir estructura recursivamente
      for (final notebook in rootNotebooks) {
        await _buildNotebookStructure(notebook, allNotebooks, structure);
      }

      if (mounted) {
        setState(() {
          _allNotebooks = allNotebooks;
          _notebookStructure = structure;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading notebooks: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error loading notebooks: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _buildNotebookStructure(
    Notebook parent,
    List<Notebook> allNotebooks,
    Map<int, List<Notebook>> structure,
  ) async {
    if (parent.id == null) return;

    // Obtener hijos directos
    final children =
        allNotebooks.where((n) => n.parentId == parent.id).toList();
    structure[parent.id!] = children;

    // Recursivamente construir estructura para cada hijo
    for (final child in children) {
      await _buildNotebookStructure(child, allNotebooks, structure);
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

  void _toggleExpansion(int notebookId) {
    final controller = _getAnimationController(notebookId);

    if (_expandedNotebooks.contains(notebookId)) {
      controller.reverse().then((_) {
        if (mounted) {
          setState(() {
            _expandedNotebooks.remove(notebookId);
          });
        }
      });
    } else {
      setState(() {
        _expandedNotebooks.add(notebookId);
      });
      controller.forward();
    }
  }

  Widget _buildNotebookNode(Notebook notebook, int level) {
    final children =
        notebook.id != null ? _notebookStructure[notebook.id!] ?? [] : [];
    final isExpanded =
        notebook.id != null && _expandedNotebooks.contains(notebook.id);
    final hasChildren = children.isNotEmpty;
    final isSelected = _selectedNotebook?.id == notebook.id;
    final isCurrentNotebook = notebook.id == widget.currentNotebook?.id;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap:
                isCurrentNotebook
                    ? null
                    : () {
                      setState(() {
                        _selectedNotebook = notebook;
                      });
                    },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),

              decoration: BoxDecoration(
                color:
                    isSelected
                        ? colorScheme.primaryContainer
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  SizedBox(width: level * 24), // Indentación por nivel
                  if (hasChildren)
                    IconButton(
                      icon: AnimatedRotation(
                        turns: isExpanded ? 0.25 : 0.0,
                        duration: const Duration(milliseconds: 100),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: colorScheme.primary,
                        ),
                      ),
                      onPressed: () => _toggleExpansion(notebook.id!),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      padding: EdgeInsets.zero,
                    )
                  else
                    SizedBox(width: 32), // Espacio para alineación
                  Icon(
                    notebook.iconId != null
                        ? (NotebookIconsRepository.getIconById(
                              notebook.iconId!,
                            )?.icon ??
                            Icons.folder_rounded)
                        : Icons.folder_rounded,
                    size: 28,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(
                    width: 24,
                  ), // Padding consistente con trash_screen
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          notebook.name,
                          style: TextStyle(
                            color:
                                isCurrentNotebook
                                    ? colorScheme.onSurfaceVariant
                                    : colorScheme.onSurface,
                            fontWeight:
                                isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (hasChildren)
                          Text(
                            '${children.length} ${children.length == 1 ? 'subnotebook' : 'subnotebooks'}',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isCurrentNotebook)
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Current',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      onPressed: null,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      padding: EdgeInsets.zero,
                    ),

                  if (isSelected)
                    IconButton(
                      icon: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                      onPressed: null,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
          ),
        ),
        if (notebook.id != null && isExpanded && hasChildren)
          SizeTransition(
            sizeFactor: _getAnimationController(notebook.id!),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:
                  children
                      .map((child) => _buildNotebookNode(child, level + 1))
                      .toList(),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Obtener notebooks raíz
    final rootNotebooks =
        _allNotebooks.where((n) => n.parentId == null).toList();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Select Notebook',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            onPressed:
                _selectedNotebook != null
                    ? () {
                      widget.onNotebookSelected(_selectedNotebook!);
                      Navigator.pop(context);
                    }
                    : null,
            icon: Icon(
              Icons.drive_file_move_rounded,
              color:
                  _selectedNotebook != null
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadNotebooks,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
              : rootNotebooks.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.folder_open_rounded,
                      size: 48,
                      color: colorScheme.primary.withAlpha(128),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No notebooks available',
                      style: TextStyle(
                        color: colorScheme.onSurface.withAlpha(128),
                      ),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                itemCount: rootNotebooks.length,
                itemBuilder: (context, index) {
                  final notebook = rootNotebooks[index];
                  return _buildNotebookNode(notebook, 0);
                },
              ),
    );
  }
}
