import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sharing_intent/flutter_sharing_intent.dart';
import 'package:flutter_sharing_intent/model/sharing_file.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html;
import 'dart:convert';
import '../../database/database_service.dart';
import '../../database/models/bookmark.dart';
import '../../database/sync_service.dart';
import '../screens/bookmarks_screen.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/confirmation_dialogue.dart';

class BookmarkSharingHandler {
  static late GlobalKey<NavigatorState> _navigatorKey;

  static void initSharingListener(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;

    final sharingIntent = FlutterSharingIntent.instance;

    sharingIntent.getInitialSharing().then((List<SharedFile>? value) async {
      if (value != null &&
          value.isNotEmpty &&
          navigatorKey.currentContext != null) {
        _processSharedUrl(value.first.value);
      }
    });

    sharingIntent.getMediaStream().listen((List<SharedFile> value) async {
      if (value.isNotEmpty && navigatorKey.currentContext != null) {
        _processSharedUrl(value.first.value);
      }
    });
  }

  static void _processSharedUrl(String? value) {
    if (value == null || value.isEmpty) {
      print('Error: Empty or null URL');
      return;
    }

    String cleanUrl = value;

    if (value.contains('google.com/search')) {
      try {
        final uri = Uri.parse(value);
        final queryParams = uri.queryParameters;

        if (queryParams.containsKey('url')) {
          cleanUrl = queryParams['url']!;
        } else if (queryParams.containsKey('q')) {
          cleanUrl =
              'https://www.google.com/search?q=${Uri.encodeComponent(queryParams['q']!)}';
        }
      } catch (e) {
        print('Error: Error processing Google URL: $e');
      }
    }

    try {
      final uri = Uri.parse(cleanUrl);
      if (uri.scheme.isNotEmpty && uri.host.isNotEmpty) {
        _showAddLinkDialog(cleanUrl);
      } else {
        print('Error: Invalid URL: empty scheme or host');
      }
    } catch (e) {
      print('Error: Error validating URL: $e');
    }
  }

  static void _showAddLinkDialog(String url) async {
    final context = _navigatorKey.currentContext;
    if (context == null) {
      print('Error: Context not available');
      return;
    }
    if (!context.mounted) {
      print('Error: Context not mounted');
      return;
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final tagsController = TextEditingController();
    bool isFetchingTitle = true;
    bool isSaving = false;

    final autoTags = await DatabaseService().bookmarkService.getTagsForUrl(url);

    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => Theme(
            data: theme.copyWith(
              colorScheme: colorScheme,
              dialogTheme: theme.dialogTheme.copyWith(
                backgroundColor: colorScheme.surfaceContainer,
              ),
            ),
            child: StatefulBuilder(
              builder: (context, setState) {
                final bottomPadding = MediaQuery.of(context).padding.bottom;
                final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

                return Padding(
                  padding: EdgeInsets.only(
                    bottom: keyboardHeight + bottomPadding,
                    left: 16,
                    right: 16,
                    top: 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: colorScheme.onSurface.withAlpha(50),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextFormField(
                              controller: titleController,
                              decoration: InputDecoration(
                                labelText: 'Title',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                filled: true,
                                fillColor: colorScheme.surfaceContainerHighest
                                    .withAlpha(76),
                                prefixIcon: Icon(
                                  Icons.title_rounded,
                                  color: colorScheme.primary,
                                ),
                                suffixIcon:
                                    isFetchingTitle
                                        ? const Padding(
                                          padding: EdgeInsets.all(12.0),
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                        : null,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: descController,
                              decoration: InputDecoration(
                                labelText: 'Description',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                filled: true,
                                fillColor: colorScheme.surfaceContainerHighest
                                    .withAlpha(76),
                                prefixIcon: Icon(
                                  Icons.description_rounded,
                                  color: colorScheme.primary,
                                ),
                              ),
                              maxLines: 1,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: tagsController,
                              decoration: InputDecoration(
                                labelText: 'Additional tags',
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
                                hintText: 'Separated by commas',
                              ),
                            ),
                            if (autoTags.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                child: Wrap(
                                  spacing: 8,
                                  alignment: WrapAlignment.start,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      'Detected tags:',
                                      style: TextStyle(
                                        color: colorScheme.onSurface.withAlpha(
                                          150,
                                        ),
                                      ),
                                    ),
                                    ...autoTags.map(
                                      (tag) => Chip(
                                        label: Text(tag),
                                        backgroundColor:
                                            colorScheme.primaryContainer,
                                        labelStyle: TextStyle(
                                          color: colorScheme.onPrimaryContainer,
                                        ),
                                        side: BorderSide.none,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.only(bottom: bottomPadding),
                        child: ElevatedButton(
                          onPressed:
                              isSaving
                                  ? null
                                  : () async {
                                    setState(() {
                                      isSaving = true;
                                    });
                                    await _saveBookmark(
                                      context,
                                      setState,
                                      titleController.text,
                                      url,
                                      descController.text,
                                      [
                                        ...autoTags,
                                        ...tagsController.text
                                            .split(',')
                                            .map((e) => e.trim())
                                            .where((e) => e.isNotEmpty),
                                      ],
                                    );
                                  },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child:
                              isSaving
                                  ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colorScheme.onPrimary,
                                    ),
                                  )
                                  : const Text(
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
                );
              },
            ),
          ),
    );

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final document = html.parse(response.body);
        final ogTitle =
            document
                .querySelector('meta[property="og:title"]')
                ?.attributes['content'];
        String? pageTitle;

        if (ogTitle != null && ogTitle.isNotEmpty) {
          pageTitle = ogTitle;
        } else {
          if (url.contains('reddit.com')) {
            pageTitle = await _getRedditTitle(url);
          }
          if (pageTitle == null || pageTitle.isEmpty) {
            pageTitle = document.querySelector('title')?.text;
          }
        }

        if (pageTitle != null && pageTitle.isNotEmpty) {
          titleController.text = pageTitle;
        } else {
          print('Error: No title found, using default value');
          titleController.text = _getDefaultTitle(url);
        }
      }
    } catch (e) {
      print('Error: Error getting title: $e');
      titleController.text = _getDefaultTitle(url);
    } finally {
      if (context.mounted) {
        (context as Element).markNeedsBuild();
        isFetchingTitle = false;
      }
    }
  }

  static String _getDefaultTitle(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceAll('www.', '');
    } catch (e) {
      return 'New bookmark';
    }
  }

  static Future<String?> _getRedditTitle(String url) async {
    try {
      final uri = Uri.parse(url);
      if (!uri.path.contains('/comments/')) return null;

      final pathSegments = uri.pathSegments;
      final postIdIndex = pathSegments.indexOf('comments');
      if (postIdIndex == -1 || postIdIndex + 1 >= pathSegments.length) {
        return null;
      }

      final postId = pathSegments[postIdIndex + 1];
      final apiUrl = 'https://www.reddit.com/comments/$postId.json';

      final response = await http
          .get(Uri.parse(apiUrl))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData is List && jsonData.isNotEmpty) {
          final postData = jsonData[0]['data']['children'][0]['data'];
          return postData['title'];
        }
      }
    } catch (e) {
      print('Error getting Reddit title: $e');
    }
    return null;
  }

  static Future<void> _saveBookmark(
    BuildContext context,
    StateSetter setState,
    String title,
    String url,
    String description,
    List<String> tags,
  ) async {
    try {
      String normalizedUrl = url;
      if (url.contains('google.com/search')) {
        try {
          final uri = Uri.parse(url);
          final queryParams = uri.queryParameters;
          if (queryParams.containsKey('q')) {
            normalizedUrl = 'google_search:${queryParams['q']}';
          }
        } catch (e) {
          print('Error: Error normalizing Google URL: $e');
        }
      }

      final existingBookmark = await DatabaseService().bookmarkService
          .getBookmarkByUrl(normalizedUrl);

      if (existingBookmark != null) {
        print('Error: Existing bookmark found');
        if (!context.mounted) return;
        final shouldOverwrite = await showDeleteConfirmationDialog(
          context: context,
          title: 'Duplicated link',
          message: 'This URL already exists. Do you want to overwrite it?',
          confirmText: 'Overwrite',
          confirmColor: Theme.of(context).colorScheme.error,
        );

        if (!context.mounted) return;
        if (shouldOverwrite != true) {
          print('Error: User canceled overwrite');
          Navigator.of(context, rootNavigator: true).pop();
          return;
        }

        await DatabaseService().bookmarkService.updateBookmark(
          Bookmark(
            id: existingBookmark.id,
            title: title.isEmpty ? _getDefaultTitle(url) : title,
            url: url,
            description: description,
            timestamp: DateTime.now().toIso8601String(),
            hidden: false,
          ),
        );

        await DatabaseService().bookmarkService.updateBookmarkTags(
          existingBookmark.id!,
          tags,
        );
      } else {
        final bookmarkId = await DatabaseService().bookmarkService
            .createBookmark(
              Bookmark(
                title: title.isEmpty ? _getDefaultTitle(url) : title,
                url: url,
                description: description,
                timestamp: DateTime.now().toIso8601String(),
                hidden: false,
                tagIds: [],
              ),
            );

        await DatabaseService().bookmarkService.updateBookmarkTags(
          bookmarkId,
          tags,
        );
      }

      if (BookmarksScreenState.currentState != null) {
        await BookmarksScreenState.currentState!.loadData();
      }

      try {
        final syncService = SyncService();

        final settings = await syncService.getSettings();
        if (settings['enabled'] == true) {
          await syncService.forceSync();
        }
      } catch (e) {
        print('Error during sync: $e');
      }

      await Future.delayed(const Duration(milliseconds: 200));

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();

        await Future.delayed(const Duration(milliseconds: 100));

        SystemNavigator.pop();
      }
    } catch (e) {
      print('Error: Error saving bookmark: $e');
      if (context.mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error saving bookmark: ${e.toString()}',
          type: CustomSnackbarType.error,
        );

        await Future.delayed(const Duration(milliseconds: 1500));

        Navigator.of(context, rootNavigator: true).pop();
        await Future.delayed(const Duration(milliseconds: 100));
        SystemNavigator.pop();
      }
    }
  }
}
