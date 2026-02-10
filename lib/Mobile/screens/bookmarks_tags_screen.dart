import 'package:flutter/material.dart';
import '../../database/models/bookmark_tag.dart';
import '../../database/bookmark_service.dart';
import '../../database/database_helper.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/confirmation_dialogue.dart';

class TagsHandler {
  static final TagsHandler _instance = TagsHandler._internal();
  factory TagsHandler() => _instance;
  TagsHandler._internal();

  final BookmarkService _bookmarkService = BookmarkService(DatabaseHelper());
  List<TagUrlPattern> _urlPatterns = [];

  Future<void> loadPatterns() async {
    try {
      _urlPatterns = await _bookmarkService.getAllTagUrlPatterns();
    } catch (e) {
      print('Error loading URL patterns: $e');
      _urlPatterns = [];
    }
  }

  List<TagUrlPattern> get allPatterns => _urlPatterns;

  Future<List<String>> getTagsForUrl(String url) async {
    return await _bookmarkService.getTagsForUrl(url);
  }

  Future<void> addTagMapping(String urlPattern, String tag) async {
    await _bookmarkService.createTagUrlPattern(urlPattern, tag);
    await loadPatterns();
  }

  Future<void> removeTagMapping(int patternId) async {
    await _bookmarkService.deleteTagUrlPattern(patternId);
    await loadPatterns();
  }
}

class TagsScreen extends StatefulWidget {
  const TagsScreen({super.key});

  @override
  TagsScreenState createState() => TagsScreenState();
}

class TagsScreenState extends State<TagsScreen> {
  final TextEditingController _urlPatternController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  final TagsHandler _handler = TagsHandler();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPatterns();
  }

  Future<void> _loadPatterns() async {
    try {
      await _handler.loadPatterns();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error loading patterns: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addPattern(String urlPattern, String tag) async {
    try {
      await _handler.addTagMapping(urlPattern, tag);
      await _loadPatterns();
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Error adding pattern';

        if (e.toString().contains('already exists')) {
          errorMessage = 'A tag pattern with this URL and tag already exists.';
        } else if (e.toString().contains('UNIQUE constraint failed')) {
          errorMessage = 'A tag pattern with this URL and tag already exists.';
        } else {
          errorMessage = 'Error adding pattern: ${e.toString()}';
        }

        CustomSnackbar.show(
          context: context,
          message: errorMessage,
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  Future<void> _removePattern(int patternId) async {
    try {
      await _handler.removeTagMapping(patternId);
      await _loadPatterns();
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error removing pattern: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  void _showAddPatternDialog() {
    final formKey = GlobalKey<FormState>();
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext dialogContext) {
        final bottomPadding = MediaQuery.of(dialogContext).padding.bottom;
        final keyboardHeight = MediaQuery.of(dialogContext).viewInsets.bottom;

        return Padding(
          padding: EdgeInsets.only(
            bottom: keyboardHeight + bottomPadding,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _urlPatternController,
                        decoration: InputDecoration(
                          labelText: 'URL pattern*',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest
                              .withAlpha(76),
                          prefixIcon: Icon(
                            Icons.link_rounded,
                            color: colorScheme.primary,
                          ),
                        ),
                        validator: (value) {
                          if (value?.isEmpty ?? true) return 'Required';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _tagController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: 'Tag*',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest
                              .withAlpha(76),
                          prefixIcon: Icon(
                            Icons.label_rounded,
                            color: colorScheme.primary,
                          ),
                        ),
                        validator: (value) {
                          if (value?.isEmpty ?? true) return 'Required';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.only(bottom: bottomPadding),
                  child: ElevatedButton(
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        await _addPattern(
                          _urlPatternController.text,
                          _tagController.text,
                        );
                        _urlPatternController.clear();
                        _tagController.clear();
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Save',
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final patterns = _handler.allPatterns;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, bool? result) {
        if (!didPop) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 40.0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text('Bookmark tags'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_rounded),
              onPressed: _showAddPatternDialog,
            ),
          ],
        ),
        body:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : patterns.isEmpty
                ? Center(
                  child: Text(
                    'No tags patterns configured',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                )
                : ListView.builder(
                  itemCount: patterns.length,
                  itemBuilder: (context, index) {
                    final pattern = patterns[index];
                    return Dismissible(
                      key: Key('${pattern.id}_${pattern.urlPattern}'),
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
                      confirmDismiss: (direction) async {
                        final result = await showDeleteConfirmationDialog(
                          context: context,
                          title: 'Delete Pattern',
                          message:
                              'Are you sure you want to delete this pattern?\n\nURL Pattern: ${pattern.urlPattern}\nTag: ${pattern.tag}',
                          confirmText: 'Delete',
                          confirmColor: colorScheme.error,
                        );
                        return result ?? false;
                      },
                      onDismissed: (_) {
                        if (pattern.id != null) {
                          _removePattern(pattern.id!);
                        }
                      },
                      child: ListTile(
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                pattern.urlPattern,
                                style: TextStyle(color: colorScheme.onSurface),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                color: colorScheme.primary,
                              ),
                            ),

                            Expanded(
                              child: Text(
                                pattern.tag,
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
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
}
