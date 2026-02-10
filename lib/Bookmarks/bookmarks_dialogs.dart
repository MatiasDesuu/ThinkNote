import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html;
import '../database/models/bookmark.dart';
import '../database/models/bookmark_tag.dart';
import 'bookmarks_handler.dart';
import 'bookmarks_tags_handler.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/custom_tooltip.dart';
import '../widgets/confirmation_dialogue.dart';

class BookmarksDialogs {
  static Future<void> showAddBookmarkDialog({
    required BuildContext context,
    required LinksHandlerDB linksHandler,
    required VoidCallback onSuccess,
  }) async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final urlController = TextEditingController();
    final descController = TextEditingController();
    final tagsController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) {
        bool isFetchingTitle = false;
        bool isTitleEdited = false;

        return StatefulBuilder(
          builder: (context, setState) {
            String getDefaultTitle(String url) {
              try {
                final uri = Uri.parse(url);
                return uri.host.replaceAll('www.', '');
              } catch (e) {
                return 'New Bookmark';
              }
            }

            Future<String?> getRedditTitle(String url) async {
              try {
                final uri = Uri.parse(url);
                if (!uri.path.contains('/comments/')) return null;

                final pathSegments = uri.pathSegments;
                final postIdIndex = pathSegments.indexOf('comments');
                if (postIdIndex == -1 ||
                    postIdIndex + 1 >= pathSegments.length) {
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

            Future<void> fetchWebTitle(String url) async {
              if (url.isEmpty) return;

              final uri = Uri.tryParse(url);
              if (uri == null || !uri.isAbsolute) return;

              setState(() => isFetchingTitle = true);

              try {
                final response = await http
                    .get(uri)
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
                      pageTitle = await getRedditTitle(url);
                    }
                    if (pageTitle == null || pageTitle.isEmpty) {
                      pageTitle = document.querySelector('title')?.text;
                    }
                  }

                  if (pageTitle != null &&
                      pageTitle.isNotEmpty &&
                      !isTitleEdited) {
                    titleController.text = pageTitle;
                  }
                }
              } catch (e) {
                if (!isTitleEdited) {
                  titleController.text = getDefaultTitle(url);
                }
              } finally {
                setState(() => isFetchingTitle = false);
              }
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 500,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
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
                              Icon(
                                Icons.bookmark_rounded,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'New Bookmark',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const Spacer(),
                              IconButton(
                                icon: Icon(
                                  Icons.close_rounded,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
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
                          child: Column(
                            children: [
                              TextFormField(
                                controller: urlController,
                                decoration: InputDecoration(
                                  labelText: 'URL*',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  filled: true,
                                  fillColor: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withAlpha(76),
                                  prefixIcon: const Icon(Icons.link_rounded),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      Icons.search_rounded,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                    onPressed:
                                        () => fetchWebTitle(urlController.text),
                                  ),
                                ),
                                validator: (value) {
                                  if (value?.isEmpty ?? true) return 'Required';
                                  if (!Uri.parse(value!).isAbsolute) {
                                    return 'Invalid URL';
                                  }
                                  return null;
                                },
                                onChanged: (value) async {
                                  if (titleController.text.isEmpty ||
                                      !isTitleEdited) {
                                    await fetchWebTitle(value);
                                  }
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: titleController,
                                decoration: InputDecoration(
                                  labelText: 'Title*',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  filled: true,
                                  fillColor: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withAlpha(76),
                                  prefixIcon: const Icon(Icons.title_rounded),
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
                                validator:
                                    (value) =>
                                        value?.isEmpty ?? true
                                            ? 'Required'
                                            : null,
                                onChanged: (value) {
                                  if (value.isNotEmpty) {
                                    setState(() => isTitleEdited = true);
                                  }
                                },
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
                                  fillColor: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withAlpha(76),
                                  prefixIcon: const Icon(
                                    Icons.description_rounded,
                                  ),
                                ),
                                maxLines: 1,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: tagsController,
                                decoration: InputDecoration(
                                  labelText: 'Tags (comma separated)',
                                  hintText: 'e.g.: work, research, personal',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  filled: true,
                                  fillColor: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withAlpha(76),
                                  prefixIcon: const Icon(Icons.tag_rounded),
                                ),
                              ),
                            ],
                          ),
                        ),
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
                                  onPressed: () async {
                                    if (formKey.currentState!.validate()) {
                                      await linksHandler.addBookmark(
                                        title: titleController.text,
                                        url: urlController.text,
                                        description: descController.text,
                                        tags:
                                            tagsController.text
                                                .split(',')
                                                .map((e) => e.trim())
                                                .where((e) => e.isNotEmpty)
                                                .toList(),
                                      );
                                      onSuccess();
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                      }
                                    }
                                  },
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
                                  child: const Text(
                                    'Save Link',
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
          },
        );
      },
    );
  }

  static Future<void> showEditBookmarkDialog({
    required BuildContext context,
    required LinksHandlerDB linksHandler,
    required Bookmark bookmark,
    required VoidCallback onSuccess,
  }) async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: bookmark.title);
    final urlController = TextEditingController(text: bookmark.url);
    final descController = TextEditingController(text: bookmark.description);
    String tagsText = bookmark.tags.join(', ');
    final tagsController = TextEditingController(text: tagsText);

    return showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 500,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
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
                            Icon(
                              Icons.edit_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Edit Bookmark',
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
                        child: Column(
                          children: [
                            TextFormField(
                              controller: titleController,
                              decoration: InputDecoration(
                                labelText: 'Title*',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                filled: true,
                                fillColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withAlpha(76),
                                prefixIcon: const Icon(Icons.title_rounded),
                              ),
                              validator:
                                  (value) =>
                                      value?.isEmpty ?? true
                                          ? 'Required'
                                          : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: urlController,
                              decoration: InputDecoration(
                                labelText: 'URL*',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                filled: true,
                                fillColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withAlpha(76),
                                prefixIcon: const Icon(Icons.link_rounded),
                              ),
                              validator: (value) {
                                if (value?.isEmpty ?? true) return 'Required';
                                if (!Uri.parse(value!).isAbsolute) {
                                  return 'Invalid URL';
                                }
                                return null;
                              },
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
                                fillColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withAlpha(76),
                                prefixIcon: const Icon(
                                  Icons.description_rounded,
                                ),
                              ),
                              maxLines: 1,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: tagsController,
                              decoration: InputDecoration(
                                labelText: 'Tags (comma separated)',
                                hintText: 'e.g.: work, research, personal',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                filled: true,
                                fillColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withAlpha(76),
                                prefixIcon: const Icon(Icons.tag_rounded),
                              ),
                            ),
                          ],
                        ),
                      ),
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
                                onPressed: () async {
                                  if (formKey.currentState!.validate()) {
                                    await linksHandler.updateBookmark(
                                      id: bookmark.id!,
                                      newTitle: titleController.text,
                                      newUrl: urlController.text,
                                      newDescription: descController.text,
                                      newTags:
                                          tagsController.text
                                              .split(',')
                                              .map((e) => e.trim())
                                              .where((e) => e.isNotEmpty)
                                              .toList(),
                                    );
                                    onSuccess();
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                    }
                                  }
                                },
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
                                child: const Text(
                                  'Save Changes',
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
          ),
    );
  }

  static Future<void> showManageTagsDialog({
    required BuildContext context,
    required TagsHandlerDB tagsHandler,
  }) async {
    await tagsHandler.loadPatterns();

    return showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 500,
                  height: 400,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.label_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Predefined Tags',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const Spacer(),
                            IconButton(
                              icon: Icon(
                                Icons.new_label_rounded,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              onPressed: () async {
                                await showAddTagMappingDialog(
                                  context: context,
                                  tagsHandler: tagsHandler,
                                );
                                await tagsHandler.loadPatterns();
                                setState(() {});
                              },
                            ),
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
                      Expanded(
                        child: FutureBuilder<List<TagUrlPattern>>(
                          future: Future.value(tagsHandler.allPatterns),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final patterns = snapshot.data ?? [];

                            return patterns.isEmpty
                                ? Center(
                                  child: Text(
                                    'No predefined tags',
                                    style: TextStyle(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                )
                                : ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  itemCount: patterns.length,
                                  itemBuilder: (context, index) {
                                    final pattern = patterns[index];
                                    return CustomTooltip(
                                      message:
                                          'URL: ${pattern.urlPattern}\nTag: ${pattern.tag}',
                                      builder: (context, isHovering) {
                                        return Card(
                                          margin: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          color:
                                              Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              onTap: () {},
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 8,
                                                    ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.label_rounded,
                                                      color:
                                                          Theme.of(
                                                            context,
                                                          ).colorScheme.primary,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            pattern.urlPattern,
                                                            style: Theme.of(
                                                                  context,
                                                                )
                                                                .textTheme
                                                                .bodyMedium
                                                                ?.copyWith(
                                                                  color:
                                                                      Theme.of(
                                                                        context,
                                                                      ).colorScheme.onSurface,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                          Row(
                                                            children: [
                                                              Icon(
                                                                Icons
                                                                    .arrow_forward_rounded,
                                                                size: 12,
                                                                color:
                                                                    Theme.of(
                                                                          context,
                                                                        )
                                                                        .colorScheme
                                                                        .onSurfaceVariant,
                                                              ),
                                                              const SizedBox(
                                                                width: 4,
                                                              ),
                                                              Text(
                                                                pattern.tag,
                                                                style: Theme.of(
                                                                      context,
                                                                    )
                                                                    .textTheme
                                                                    .bodySmall
                                                                    ?.copyWith(
                                                                      color:
                                                                          Theme.of(
                                                                            context,
                                                                          ).colorScheme.primary,
                                                                      fontSize:
                                                                          11,
                                                                    ),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Opacity(
                                                      opacity:
                                                          isHovering
                                                              ? 1.0
                                                              : 0.0,
                                                      child: IgnorePointer(
                                                        ignoring: !isHovering,
                                                        child: MouseRegion(
                                                          cursor:
                                                              SystemMouseCursors
                                                                  .click,
                                                          child: GestureDetector(
                                                            onTap: () async {
                                                              final confirmed = await showDeleteConfirmationDialog(
                                                                context:
                                                                    context,
                                                                title:
                                                                    'Delete Tag Mapping',
                                                                message:
                                                                    'Are you sure you want to delete this tag mapping?\n\nURL Pattern: ${pattern.urlPattern}\nTag: ${pattern.tag}',
                                                                confirmText:
                                                                    'Delete',
                                                                confirmColor:
                                                                    Theme.of(
                                                                          context,
                                                                        )
                                                                        .colorScheme
                                                                        .error,
                                                              );

                                                              if (confirmed ==
                                                                  true) {
                                                                await tagsHandler
                                                                    .removeTagMapping(
                                                                      pattern
                                                                          .urlPattern,
                                                                      pattern
                                                                          .tag,
                                                                    );
                                                                setState(() {});
                                                              }
                                                            },
                                                            child: Container(
                                                              padding:
                                                                  const EdgeInsets.all(
                                                                    4,
                                                                  ),
                                                              decoration: BoxDecoration(
                                                                color: Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .error
                                                                    .withAlpha(
                                                                      20,
                                                                    ),
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      6,
                                                                    ),
                                                              ),
                                                              child: Icon(
                                                                Icons
                                                                    .close_rounded,
                                                                size: 14,
                                                                color:
                                                                    Theme.of(
                                                                          context,
                                                                        )
                                                                        .colorScheme
                                                                        .error,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
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
                                  },
                                );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Future<void> showAddTagMappingDialog({
    required BuildContext context,
    required TagsHandlerDB tagsHandler,
  }) async {
    final urlController = TextEditingController();
    final tagController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog(
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
                            Icon(
                              Icons.label_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'New Predefined Tag',
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
                        child: Column(
                          children: [
                            TextFormField(
                              controller: urlController,
                              decoration: InputDecoration(
                                labelText: 'URL Pattern*',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                filled: true,
                                fillColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withAlpha(76),
                                prefixIcon: const Icon(Icons.link_rounded),
                              ),
                              validator:
                                  (value) =>
                                      value?.isEmpty ?? true
                                          ? 'Required'
                                          : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: tagController,
                              decoration: InputDecoration(
                                labelText: 'Tag*',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                filled: true,
                                fillColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withAlpha(76),
                                prefixIcon: const Icon(Icons.tag_rounded),
                              ),
                              validator:
                                  (value) =>
                                      value?.isEmpty ?? true
                                          ? 'Required'
                                          : null,
                            ),
                          ],
                        ),
                      ),
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
                                onPressed: () async {
                                  if (formKey.currentState!.validate()) {
                                    try {
                                      await tagsHandler.addTagMapping(
                                        urlController.text.trim(),
                                        tagController.text.trim(),
                                      );
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        String errorMessage =
                                            'Error adding pattern';

                                        if (e.toString().contains(
                                          'already exists',
                                        )) {
                                          errorMessage =
                                              'A tag pattern with this URL and tag already exists.';
                                        } else if (e.toString().contains(
                                          'UNIQUE constraint failed',
                                        )) {
                                          errorMessage =
                                              'A tag pattern with this URL and tag already exists.';
                                        } else {
                                          errorMessage =
                                              'Error adding pattern: ${e.toString()}';
                                        }

                                        CustomSnackbar.show(
                                          context: context,
                                          message: errorMessage,
                                          type: CustomSnackbarType.error,
                                        );
                                      }
                                    }
                                  }
                                },
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
                                child: const Text(
                                  'Save',
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
          ),
    );
  }
}
