import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:dynamic_color/dynamic_color.dart';

import '../../database/models/think.dart';
import '../../database/models/note.dart';
import '../../database/models/notebook.dart';
import '../../database/services/think_service.dart';
import '../../database/database_helper.dart';
import '../../database/repositories/think_repository.dart';
import '../../database/repositories/notebook_repository.dart';
import '../../database/repositories/note_repository.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/confirmation_dialogue.dart';
import '../widgets/note_editor.dart';
import '../theme_handler.dart';

class ThinksScreen extends StatefulWidget {
  final Function(Note) onThinkSelected;
  final List<Think>? initialThinks;

  const ThinksScreen({
    super.key,
    required this.onThinkSelected,
    this.initialThinks,
  });

  @override
  State<ThinksScreen> createState() => _ThinksScreenState();
}

class _ThinksScreenState extends State<ThinksScreen> {
  List<Think> _thinks = [];
  bool _isLoading = true;
  late ThinkService _thinkService;
  StreamSubscription? _thinkChangesSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.initialThinks != null) {
      _thinks = widget.initialThinks!;
      _isLoading = false;
    }
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      final dbHelper = DatabaseHelper();
      final thinkRepository = ThinkRepository(dbHelper);
      _thinkService = ThinkService(thinkRepository);

      _thinkChangesSubscription = _thinkService.onThinkChanged.listen((_) {
        _loadThinks();
      });

      List<Think> loadedThinks = await _thinkService.getAllThinks();

      if (mounted) {
        setState(() {
          _thinks = loadedThinks;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error in Thinks initialization: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _thinkChangesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadThinks() async {
    try {
      final loadedThinks = await _thinkService.getAllThinks();
      if (mounted) {
        setState(() {
          _thinks = loadedThinks;
        });
      }
    } catch (e) {
      debugPrint('Error in _loadThinks: $e');
    }
  }

  String _formatDate(DateTime dateTime) {
    return DateFormat("dd/MM/yyyy - HH:mm").format(dateTime);
  }

  Future<void> _createNewThink() async {
    try {
      final createdThink = await _thinkService.createThink();
      if (createdThink != null) {
        await _loadThinks();
      }
    } catch (e) {
      debugPrint('Error creating Think: ${e.toString()}');
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error creating Think: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  Future<void> _deleteThink(Think think) async {
    try {
      await _thinkService.deleteThink(think.id!);
      await _loadThinks();
    } catch (e) {
      debugPrint('Error deleting Think: ${e.toString()}');
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error moving Think to trash: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  Future<void> _toggleFavorite(Think think) async {
    try {
      await _thinkService.toggleFavorite(think.id!, !think.isFavorite);
      await _loadThinks();
    } catch (e) {
      debugPrint('Error changing favorite: ${e.toString()}');
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error updating favorite status: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  Future<void> _moveToDrafts(Think think) async {
    try {
      final dbHelper = DatabaseHelper();
      final notebookRepo = NotebookRepository(dbHelper);
      final noteRepo = NoteRepository(dbHelper);

      final rootNotebooks = await notebookRepo.getNotebooksByParentId(null);
      var drafts = rootNotebooks.where((n) => n.name == 'Drafts').firstOrNull;

      if (drafts == null) {
        final newDrafts = Notebook(
          name: 'Drafts',
          parentId: null,
          createdAt: DateTime.now(),
          orderIndex: 0,
        );
        final id = await notebookRepo.createNotebook(newDrafts);
        drafts = await notebookRepo.getNotebook(id);
      }

      if (drafts == null) {
        throw Exception('Could not access Drafts notebook');
      }

      final noteToAdd = Note(
        title: think.title,
        content: think.content,
        notebookId: drafts.id!,
        createdAt: think.createdAt,
        updatedAt: DateTime.now(),
        isFavorite: think.isFavorite,
        tags: think.tags,
      );

      await noteRepo.createNote(noteToAdd);

      await _thinkService.deleteThink(think.id!);

      if (mounted) {
        await _loadThinks();

        CustomSnackbar.show(
          context: context,
          message: 'Think moved to Drafts',
          type: CustomSnackbarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error moving to Drafts: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  void _handleThinkSelected(Think think) async {
    try {
      final themeResults = await Future.wait([
        ThemeManager.getThemeBrightness(),
        ThemeManager.getColorModeEnabled(),
        ThemeManager.getMonochromeEnabled(),
        ThemeManager.getEInkEnabled(),
      ]);

      if (!mounted) return;

      final isDarkMode = themeResults[0];
      final colorMode = themeResults[1];
      final monochromeMode = themeResults[2];
      final einkMode = themeResults[3];

      final editorTitleController = TextEditingController(text: think.title);
      final editorContentController = TextEditingController(
        text: think.content,
      );
      final editorFocusNode = FocusNode();

      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder:
                  (context) => DynamicColorBuilder(
                    builder: (
                      ColorScheme? lightDynamic,
                      ColorScheme? darkDynamic,
                    ) {
                      return Theme(
                        data: ThemeManager.buildTheme(
                          lightDynamic: lightDynamic,
                          darkDynamic: darkDynamic,
                          isDarkMode: isDarkMode,
                          colorModeEnabled: colorMode,
                          monochromeEnabled: monochromeMode,
                          einkEnabled: einkMode,
                        ),
                        child: NoteEditor(
                          selectedThink: think,
                          titleController: editorTitleController,
                          contentController: editorContentController,
                          contentFocusNode: editorFocusNode,
                          isEditing: true,
                          isImmersiveMode: false,
                          onSave: () async {
                            try {
                              final dbHelper = DatabaseHelper();
                              final thinkRepository = ThinkRepository(dbHelper);

                              final updatedThink = Think(
                                id: think.id,
                                title: editorTitleController.text.trim(),
                                content: editorContentController.text,
                                createdAt: think.createdAt,
                                updatedAt: DateTime.now(),
                                isFavorite: think.isFavorite,
                                orderIndex: think.orderIndex,
                                tags: think.tags,
                              );

                              await thinkRepository.updateThink(updatedThink);
                              DatabaseHelper.notifyDatabaseChanged();
                            } catch (e) {
                              debugPrint('Error saving think: $e');
                              if (mounted) {
                                CustomSnackbar.show(
                                  context: context,
                                  message:
                                      'Error saving think: ${e.toString()}',
                                  type: CustomSnackbarType.error,
                                );
                              }
                            }
                          },
                          onToggleEditing: () {},
                          onTitleChanged: () {},
                          onContentChanged: () {},
                          onToggleImmersiveMode: (isImmersive) {},
                        ),
                      );
                    },
                  ),
            ),
          )
          .then((_) {
            _loadThinks();
          });
    } catch (e) {
      debugPrint('Error selecting Think: ${e.toString()}');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, bool? shouldPop) {
        if (!didPop) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 40.0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          title: const Text('Thinks'),
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body:
            _isLoading
                ? const SizedBox.shrink()
                : _thinks.isEmpty
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Symbols.lightbulb_2,
                        size: 48,
                        color: colorScheme.onSurfaceVariant.withAlpha(100),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Thinks created',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant.withAlpha(150),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _createNewThink,
                        icon: const Icon(Icons.add_rounded),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                        ),
                        label: const Text('Create Think'),
                      ),
                    ],
                  ),
                )
                : Stack(
                  children: [
                    ListView.builder(
                      padding: const EdgeInsets.only(top: 4),
                      itemCount: _thinks.length,
                      itemBuilder: (context, index) {
                        final think = _thinks[index];
                        return Dismissible(
                          key: Key(think.id.toString()),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: colorScheme.error,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: Icon(
                              Icons.delete_rounded,
                              color: colorScheme.onError,
                              size: 28,
                            ),
                          ),
                          onUpdate: (details) {
                            if (details.direction ==
                                DismissDirection.endToStart) {
                              HapticFeedback.selectionClick();
                            }
                          },
                          onDismissed: (direction) {
                            HapticFeedback.lightImpact();
                          },
                          confirmDismiss: (direction) async {
                            final colorScheme = Theme.of(context).colorScheme;
                            final result = await showDeleteConfirmationDialog(
                              context: context,
                              title: 'Move to trash',
                              message:
                                  'Are you sure you want to move this Think to the trash?\n${think.title}',
                              confirmText: 'Move to trash',
                              confirmColor: colorScheme.error,
                            );

                            if (result == true) {
                              await _deleteThink(think);
                            }
                            return result ?? false;
                          },
                          child: Container(
                            margin: const EdgeInsets.only(
                              bottom: 4,
                              left: 8,
                              right: 8,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => _handleThinkSelected(think),
                                onLongPress: () {
                                  showModalBottomSheet(
                                    context: context,
                                    backgroundColor: colorScheme.surface,
                                    isScrollControlled: true,
                                    builder:
                                        (context) => Padding(
                                          padding: EdgeInsets.only(
                                            bottom:
                                                MediaQuery.of(
                                                  context,
                                                ).padding.bottom,
                                          ),
                                          child: Container(
                                            decoration: const BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.vertical(
                                                    top: Radius.circular(16),
                                                  ),
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 40,
                                                  height: 4,
                                                  margin:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 8,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: colorScheme.onSurface
                                                        .withAlpha(50),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          2,
                                                        ),
                                                  ),
                                                ),
                                                Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    onTap: () {
                                                      Navigator.pop(context);
                                                      _toggleFavorite(think);
                                                    },
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 16,
                                                            vertical: 12,
                                                          ),
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            think.isFavorite
                                                                ? Icons
                                                                    .favorite_rounded
                                                                : Icons
                                                                    .favorite_border_rounded,
                                                            size: 20,
                                                            color:
                                                                colorScheme
                                                                    .primary,
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Text(
                                                            think.isFavorite
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
                                                    onTap: () {
                                                      Navigator.pop(context);
                                                      _moveToDrafts(think);
                                                    },
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 16,
                                                            vertical: 12,
                                                          ),
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            Icons
                                                                .move_to_inbox_rounded,
                                                            size: 20,
                                                            color:
                                                                colorScheme
                                                                    .primary,
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          const Text(
                                                            'Move to Drafts',
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
                                                      final confirmed =
                                                          await showDeleteConfirmationDialog(
                                                            context: context,
                                                            title:
                                                                'Move to Trash',
                                                            message:
                                                                'Are you sure you want to move this Think to trash?\n${think.title}',
                                                            confirmText:
                                                                'Move to Trash',
                                                            confirmColor:
                                                                colorScheme
                                                                    .error,
                                                          );

                                                      if (confirmed == true) {
                                                        await _deleteThink(
                                                          think,
                                                        );
                                                      }
                                                    },
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 16,
                                                            vertical: 12,
                                                          ),
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            Icons
                                                                .delete_rounded,
                                                            size: 20,
                                                            color:
                                                                colorScheme
                                                                    .error,
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          const Text(
                                                            'Move to Trash',
                                                          ),
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
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Stack(
                                        alignment: Alignment.center,
                                        clipBehavior: Clip.none,
                                        children: [
                                          Icon(
                                            Icons.lightbulb_outline_rounded,
                                            color: colorScheme.primary,
                                            size: 24,
                                          ),
                                          if (think.isFavorite)
                                            Positioned(
                                              right: -4,
                                              bottom: -4,
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  1,
                                                ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      colorScheme
                                                          .surfaceContainerHighest,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  Icons.favorite_rounded,
                                                  size: 12,
                                                  color: colorScheme.primary,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(width: 12),

                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              think.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: colorScheme.onSurface,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.today_rounded,
                                                  size: 14,
                                                  color: colorScheme.primary,
                                                ),
                                                const SizedBox(width: 2),
                                                Text(
                                                  _formatDate(think.updatedAt),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color:
                                                        colorScheme
                                                            .onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    Positioned(
                      bottom: MediaQuery.of(context).viewPadding.bottom + 16,
                      right: 16,
                      child: FloatingActionButton(
                        heroTag: 'newThinkButton',
                        onPressed: _createNewThink,
                        elevation: 4,
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        child: Icon(Icons.add_rounded),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}
