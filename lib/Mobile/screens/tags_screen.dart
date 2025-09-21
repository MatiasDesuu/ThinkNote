import 'package:flutter/material.dart';
import '../../database/database_service.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/confirmation_dialogue.dart';

class TagsScreen extends StatefulWidget {
  const TagsScreen({super.key});

  @override
  State<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends State<TagsScreen> {
  final TextEditingController _newTagController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _databaseService = DatabaseService();
  List<String> _tags = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  @override
  void dispose() {
    _newTagController.dispose();
    super.dispose();
  }

  Future<void> _loadTags() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final tags = await _databaseService.taskService.getAllTags();
      if (mounted) {
        setState(() {
          _tags = tags;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        CustomSnackbar.show(
          context: context,
          message: 'Error loading tags: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  Future<void> _addNewTag() async {
    if (!_formKey.currentState!.validate()) return;

    final newTag = _newTagController.text.trim();
    if (newTag.isEmpty) return;

    if (_tags.contains(newTag)) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'This tag already exists',
          type: CustomSnackbarType.error,
        );
      }
      return;
    }

    try {
      await _databaseService.taskService.addTag(newTag);
      _newTagController.clear();
      await _loadTags();
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error adding tag: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  Future<void> _deleteTag(String tag) async {
    try {
      await _databaseService.taskService.deleteTag(tag);
      await _loadTags();
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error deleting tag: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  void _showAddTagDialog() {
    _newTagController.clear();
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final bottomPadding = MediaQuery.of(context).padding.bottom;
        final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
        final colorScheme = Theme.of(context).colorScheme;

        return Padding(
          padding: EdgeInsets.only(
            bottom: keyboardHeight + bottomPadding,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _newTagController,
                  decoration: InputDecoration(
                    labelText: 'Tag name',
                    hintText: 'Enter the tag name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withAlpha(
                      76,
                    ),
                    prefixIcon: Icon(
                      Icons.label_rounded,
                      color: colorScheme.primary,
                    ),
                  ),
                  validator:
                      (value) => value?.isEmpty ?? true ? 'Required' : null,
                  autofocus: true,
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.only(bottom: bottomPadding),
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        await _addNewTag();
                        if (context.mounted) {
                          Navigator.pop(context, true);
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
                      'Add',
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
    ).then((result) {
      if (result == true && mounted) {
        _loadTags();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, bool? result) {
        if (!didPop) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text('Tags'),
          actions: [
            IconButton(
              icon: Icon(Icons.new_label_rounded, color: colorScheme.primary),
              onPressed: _showAddTagDialog,
            ),
          ],
        ),
        body:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _tags.isEmpty
                ? Center(
                  child: Text(
                    'No tags created yet',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                )
                : ListView.builder(
                  itemCount: _tags.length,
                  itemBuilder: (context, index) {
                    final tag = _tags[index];
                    return Dismissible(
                      key: Key(tag),
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
                          title: 'Delete Tag',
                          message:
                              'Are you sure you want to delete this tag?\n$tag',
                          confirmText: 'Delete',
                          confirmColor: colorScheme.error,
                        );
                        return result ?? false;
                      },
                      onDismissed: (_) {
                        _deleteTag(tag);
                      },
                      child: ListTile(
                        leading: Icon(
                          Icons.label_rounded,
                          color: colorScheme.primary,
                        ),
                        title: Text(tag),
                      ),
                    );
                  },
                ),
      ),
    );
  }
}
