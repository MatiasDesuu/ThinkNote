import 'package:flutter/material.dart';
import 'dart:async';
import '../database/models/note.dart';
import '../database/models/notebook.dart';
import '../database/models/notebook_icons.dart';
import '../database/database_helper.dart';
import '../database/repositories/note_repository.dart';
import '../database/repositories/notebook_repository.dart';
import 'custom_snackbar.dart';

class SearchScreenDesktop extends StatefulWidget {
  final Function(Note)? onNoteSelected;
  final Function(Notebook)? onNotebookSelected;
  final Function(Note, String, bool)? onNoteSelectedWithSearch;

  const SearchScreenDesktop({
    super.key,
    this.onNoteSelected,
    this.onNotebookSelected,
    this.onNoteSelectedWithSearch,
  });

  @override
  State<SearchScreenDesktop> createState() => _SearchScreenDesktopState();
}

class _SearchScreenDesktopState extends State<SearchScreenDesktop> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  late NoteRepository _noteRepository;
  late NotebookRepository _notebookRepository;
  final FocusNode _searchFocusNode = FocusNode();
  bool _isAdvancedSearchEnabled = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _initializeRepositories();

    // Auto-focus on search field when dialog opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  Future<void> _initializeRepositories() async {
    final dbHelper = DatabaseHelper();
    await dbHelper.database;
    _noteRepository = NoteRepository(dbHelper);
    _notebookRepository = NotebookRepository(dbHelper);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    try {
      List<Note> notes;
      if (_isAdvancedSearchEnabled) {
        // Advanced search: search in both title and content
        notes = await _noteRepository.searchNotes(query);
      } else {
        // Basic search: search only in title
        notes = await _noteRepository.searchNotesByTitle(query);
      }

      final notebooks = await _notebookRepository.searchNotebooks(query);

      if (mounted) {
        setState(() {
          _searchResults = [...notebooks, ...notes];
        });
      }
    } catch (e) {
      debugPrint('Error performing search: $e');
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error performing search: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  void _onSearchChanged() {
    // Buscar inmediatamente sin debounce
    _performSearch(_searchController.text);
  }

  void _handleItemTap(dynamic item) {
    if (item is Note) {
      if (_isAdvancedSearchEnabled &&
          _searchController.text.isNotEmpty &&
          widget.onNoteSelectedWithSearch != null) {
        try {
          // Pass search information when advanced search is enabled
          widget.onNoteSelectedWithSearch!(
            item,
            _searchController.text,
            _isAdvancedSearchEnabled,
          );
        } catch (e) {
          // Fallback to regular callback
          widget.onNoteSelected?.call(item);
        }
      } else {
        // Use regular callback for basic search or when no search info needed
        widget.onNoteSelected?.call(item);
      }
      Navigator.of(context).pop();
    } else if (item is Notebook) {
      widget.onNotebookSelected?.call(item);
      Navigator.of(context).pop();
    }
  }

  void _toggleAdvancedSearch() {
    setState(() {
      _isAdvancedSearchEnabled = !_isAdvancedSearchEnabled;
    });
    // Re-perform search with new setting
    if (_searchController.text.isNotEmpty) {
      _performSearch(_searchController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final hasResults = _searchResults.isNotEmpty;

    // Calcular dimensiones dinámicas
    final dialogWidth =
        screenSize.width * 0.6 > 600 ? 600.0 : screenSize.width * 0.6;
    final dialogHeight =
        hasResults
            ? (screenSize.height * 0.7 > 500 ? 500.0 : screenSize.height * 0.7)
            : 80.0; // Solo search field

    return Stack(
      children: [
        // Overlay para cerrar al hacer clic fuera
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(color: Colors.black.withAlpha(77)),
          ),
        ),
        // Posicionar el diálogo en la parte superior
        Positioned(
          top: 20,
          left: (screenSize.width - dialogWidth) / 2,
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                width: dialogWidth,
                height: dialogHeight,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(51),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Search field with close button at the top
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              autofocus: true,
                              decoration: InputDecoration(
                                hintText: 'Search notebooks and notes...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                filled: true,
                                fillColor: colorScheme.surfaceContainerHighest
                                    .withAlpha(76),
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  color: colorScheme.primary,
                                ),
                                suffixIcon:
                                    _searchController.text.isNotEmpty
                                        ? IconButton(
                                          icon: Icon(
                                            Icons.clear_all_rounded,
                                            color: colorScheme.onSurface,
                                          ),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() {
                                              _searchResults = [];
                                            });
                                          },
                                        )
                                        : null,
                              ),
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 16,
                              ),
                              onSubmitted: (value) {
                                if (_searchResults.isNotEmpty) {
                                  _handleItemTap(_searchResults.first);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Advanced search toggle button
                          Tooltip(
                            message:
                                _isAdvancedSearchEnabled
                                    ? 'Disable advanced search (title only)'
                                    : 'Enable advanced search (title + content)',
                            child: IconButton(
                              icon: Icon(
                                _isAdvancedSearchEnabled
                                    ? Icons.insights_rounded
                                    : Icons.insights_outlined,
                                color:
                                    _isAdvancedSearchEnabled
                                        ? colorScheme.primary
                                        : colorScheme.onSurface,
                              ),
                              onPressed: _toggleAdvancedSearch,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: colorScheme.onSurface,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                    // Results only when they exist
                    if (hasResults)
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 8,
                          ),
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            return _buildSearchResultItem(
                              _searchResults[index],
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResultItem(dynamic item) {
    final colorScheme = Theme.of(context).colorScheme;
    final isNotebook = item is Notebook;
    final hasContent = isNotebook ? false : (item.content.isNotEmpty);

    // Obtener el icono apropiado
    IconData iconData;
    if (isNotebook) {
      // Para notebooks, usar el icono personalizado o el por defecto
      iconData =
          item.iconId != null
              ? NotebookIconsRepository.getIconById(item.iconId!)?.icon ??
                  Icons.folder_rounded
              : Icons.folder_rounded;
    } else {
      // Para notas, usar el icono de descripción
      iconData = Icons.description_outlined;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleItemTap(item),
          borderRadius: BorderRadius.circular(8),
          hoverColor: colorScheme.surfaceContainerHigh,
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Icon(iconData, color: colorScheme.primary, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isNotebook ? item.name : item.title,
                        style: TextStyle(
                          fontSize: 16,
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (hasContent && !isNotebook)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child:
                              _isAdvancedSearchEnabled
                                  ? _buildContentPreview(
                                    item.content,
                                    _searchController.text,
                                  )
                                  : Text(
                                    item.content,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colorScheme.onSurface.withAlpha(
                                        153,
                                      ),
                                      fontSize: 14,
                                    ),
                                  ),
                        ),
                    ],
                  ),
                ),
                if (item.isFavorite)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.favorite_rounded,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentPreview(String content, String searchQuery) {
    if (searchQuery.isEmpty) {
      return Text(
        content,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
          fontSize: 14,
        ),
      );
    }

    // Find the word in the content (case-insensitive)
    final lowerContent = content.toLowerCase();
    final lowerQuery = searchQuery.toLowerCase();
    final queryIndex = lowerContent.indexOf(lowerQuery);

    if (queryIndex == -1) {
      return Text(
        content.length > 100 ? '...${content.substring(0, 100)}...' : content,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
          fontSize: 14,
        ),
      );
    }

    // Extract context around the word
    const contextLength = 50;
    final start = (queryIndex - contextLength).clamp(0, content.length);
    final end = (queryIndex + searchQuery.length + contextLength).clamp(
      0,
      content.length,
    );

    String contextText = content.substring(start, end);

    // Clean up the context: remove line breaks and extra spaces
    contextText =
        contextText
            .replaceAll('\n', ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

    // Add ellipsis
    if (start > 0) contextText = '...$contextText';
    if (end < content.length) contextText = '$contextText...';

    // Find the word in the context
    final lowerContext = contextText.toLowerCase();
    final contextQueryIndex = lowerContext.indexOf(lowerQuery);

    if (contextQueryIndex == -1) {
      return Text(
        contextText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
          fontSize: 14,
        ),
      );
    }

    // Extract the actual word from the context (preserving original case)
    final actualWord = contextText.substring(
      contextQueryIndex,
      contextQueryIndex + searchQuery.length,
    );
    final beforeMatch = contextText.substring(0, contextQueryIndex);
    final afterMatch = contextText.substring(
      contextQueryIndex + searchQuery.length,
    );

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
          fontSize: 14,
        ),
        children: [
          TextSpan(text: beforeMatch),
          TextSpan(
            text: actualWord,
            style: TextStyle(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withAlpha(76),
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(text: afterMatch),
        ],
      ),
    );
  }
}
