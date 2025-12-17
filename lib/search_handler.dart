// search_handler.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'widgets/custom_dialog.dart';

class SearchHandler {
  final Directory rootDir;
  final BuildContext context;

  SearchHandler({required this.rootDir, required this.context});

  Future<List<FileSystemEntity>> search(String query) async {
    final results = <FileSystemEntity>[];
    await _searchDirectory(rootDir, query.toLowerCase(), results);
    return _processResults(results);
  }

  Future<void> _searchDirectory(
    Directory dir,
    String query,
    List<FileSystemEntity> results,
  ) async {
    try {
      final entities = await dir.list().toList();

      for (final entity in entities) {
        if (entity is Directory) {
          if (_matchesQuery(entity, query)) {
            results.add(entity);
          }
          await _searchDirectory(entity, query, results);
        } else if (entity is File && entity.path.endsWith('.md')) {
          if (_matchesQuery(entity, query)) {
            results.add(entity);
          }
        }
      }
    } catch (e) {
      print('Error searching directory: $e');
    }
  }

  bool _matchesQuery(FileSystemEntity entity, String query) {
    final name = p.basename(entity.path);
    final cleanName = name.replaceFirst(RegExp(r'^\d+_'), '');
    return cleanName.toLowerCase().contains(query);
  }

  List<FileSystemEntity> _processResults(List<FileSystemEntity> results) {
    // Separate directories and files
    final directories = results.whereType<Directory>().toList();
    final files = results.whereType<File>().toList();

    // Sort alphabetically
    directories.sort((a, b) => _cleanName(a).compareTo(_cleanName(b)));
    files.sort((a, b) => _cleanName(a).compareTo(_cleanName(b)));

    return [...directories, ...files];
  }

  String _cleanName(FileSystemEntity entity) {
    return p.basename(entity.path).replaceFirst(RegExp(r'^\d+_'), '');
  }

  static void showSearchDialog({
    required BuildContext context,
    required Directory rootDir,
    required Function(File) onFileSelected,
    required Function(Directory) onDirectorySelected,
    Directory? storageDir,
  }) {
    final searchController = TextEditingController();
    final FocusNode focusNode = FocusNode();
    ValueNotifier<List<FileSystemEntity>> results = ValueNotifier([]);

    showDialog(
      context: context,
      builder:
          (context) => CustomDialog(
            title: 'Search Files',
            icon: Icons.search_rounded,
            width: 500,
            height: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: searchController,
                  focusNode: focusNode,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Type to search...',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onSubmitted: (value) {
                    if (results.value.isNotEmpty) {
                      Navigator.pop(context);
                      final item = results.value.first;
                      if (item is File) {
                        onFileSelected(item);
                      } else if (item is Directory) {
                        onDirectorySelected(item);
                      }
                    }
                  },
                  onChanged: (value) async {
                    // If storageDir exists and is a valid directory, use it as search root
                    // to prioritize results from the Storage folder
                    final searchRoot =
                        (storageDir != null && storageDir.existsSync())
                            ? storageDir
                            : rootDir;

                    results.value = await SearchHandler(
                      rootDir: searchRoot,
                      context: context,
                    ).search(value);
                  },
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ValueListenableBuilder<List<FileSystemEntity>>(
                    valueListenable: results,
                    builder:
                        (context, items, _) => ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return ListTile(
                              leading: Icon(
                                item is Directory
                                    ? Icons.folder_rounded
                                    : Icons.description_outlined,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              title: Text(_displayName(item)),
                              onTap: () {
                                Navigator.pop(context);
                                if (item is File) {
                                  onFileSelected(item);
                                } else if (item is Directory) {
                                  onDirectorySelected(item);
                                }
                              },
                            );
                          },
                        ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  static String _displayName(FileSystemEntity item) {
    final name = p.basename(item.path);
    return name.replaceFirst(RegExp(r'^\d+_'), '').replaceAll('.md', '');
  }
}
