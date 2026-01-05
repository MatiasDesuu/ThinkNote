import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../services/tags_service.dart';
import '../../widgets/custom_snackbar.dart';

class NotesTagsScreen extends StatefulWidget {
  final Function(String tag)? onTagSelected;

  const NotesTagsScreen({super.key, this.onTagSelected});

  @override
  State<NotesTagsScreen> createState() => _NotesTagsScreenState();
}

class _NotesTagsScreenState extends State<NotesTagsScreen> {
  final TagsService _tagsService = TagsService();
  Map<String, int> _tags = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeTags();
  }

  Future<void> _initializeTags() async {
    try {
      await _tagsService.initialize();
      final tags = await _tagsService.getAllTags();
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sortedTags =
        _tags.entries.toList()..sort((a, b) {
          final countCompare = b.value.compareTo(a.value);
          if (countCompare != 0) return countCompare;
          return a.key.compareTo(b.key);
        });

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 40.0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Note Tags'),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _tags.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'No tags found',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: sortedTags.length,
                itemBuilder: (context, index) {
                  final tag = sortedTags[index].key;
                  final count = sortedTags[index].value;

                  return ListTile(
                    leading: Icon(
                      Symbols.tag_rounded,
                      color: colorScheme.primary,
                    ),
                    title: Text(
                      tag,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        count.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                    onTap: () {
                      widget.onTagSelected?.call(tag);
                      if (widget.onTagSelected != null) {
                        Navigator.pop(context);
                      }
                    },
                  );
                },
              ),
    );
  }
}
