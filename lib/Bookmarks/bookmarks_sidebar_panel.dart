import 'package:flutter/material.dart';
import 'bookmarks_handler.dart';
import '../database/models/bookmark.dart';

class BookmarksSidebarPanel extends StatelessWidget {
  final double width;
  final int totalBookmarks;
  final List<String> tags;
  final String? selectedTag;
  final bool isOldestFirst;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onTagSelected;
  final VoidCallback onSortToggle;
  final Function(DragUpdateDetails) onDragUpdate;
  final VoidCallback onDragEnd;
  final TextEditingController searchController;
  final Function(Bookmark, String)? onBookmarkDropped;

  const BookmarksSidebarPanel({
    super.key,
    required this.width,
    required this.totalBookmarks,
    required this.tags,
    required this.selectedTag,
    required this.isOldestFirst,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onTagSelected,
    required this.onSortToggle,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.searchController,
    this.onBookmarkDropped,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (searchController.text != searchQuery) {
      searchController.text = searchQuery;

      searchController.selection = TextSelection.fromPosition(
        TextPosition(offset: searchController.text.length),
      );
    }

    return Container(
      width: width,
      decoration: BoxDecoration(color: colorScheme.surfaceContainerLow),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.bookmarks_rounded,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Bookmarks',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      totalBookmarks.toString(),
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    filled: true,
                    fillColor: colorScheme.surface,
                    suffixIcon:
                        searchQuery.isNotEmpty
                            ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                onSearchChanged('');
                              },
                            )
                            : null,
                  ),
                  onChanged: onSearchChanged,
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: onSortToggle,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.sort_rounded,
                            size: 18,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isOldestFirst ? 'Oldest first' : 'Newest first',
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            isOldestFirst
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            size: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const Divider(height: 1),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  'TAGS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 1.0,
                  ),
                ),
              ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  children: [
                    _buildTagItem(
                      context: context,
                      label: 'All Bookmarks',
                      isSelected: selectedTag == null,
                      onTap: () => onTagSelected(null),
                      icon: Icons.all_inclusive_rounded,
                    ),
                    _buildTagItem(
                      context: context,
                      label: 'Untagged',
                      isSelected: selectedTag == LinksHandlerDB.untaggedTag,
                      onTap: () => onTagSelected(LinksHandlerDB.untaggedTag),
                      icon:
                          selectedTag == LinksHandlerDB.untaggedTag
                              ? Icons.label_off_rounded
                              : Icons.label_off_outlined,
                    ),
                    ...tags.map(
                      (tag) => _buildTagItem(
                        context: context,
                        label: tag,
                        isSelected: selectedTag == tag,
                        onTap: () => onTagSelected(tag),
                        icon:
                            tag == LinksHandlerDB.hiddenTag
                                ? (selectedTag == tag
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_off_rounded)
                                : (selectedTag == tag
                                    ? Icons.label_rounded
                                    : Icons.label_outline_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              child: GestureDetector(
                onHorizontalDragUpdate: onDragUpdate,
                onHorizontalDragEnd: (_) => onDragEnd(),
                child: Container(width: 5, color: Colors.transparent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagItem({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return DragTarget<Bookmark>(
      onWillAcceptWithDetails: (details) {
        return label != 'All Bookmarks';
      },
      onAcceptWithDetails: (details) {
        onBookmarkDropped?.call(details.data, label);
      },
      builder: (context, candidateData, rejectedData) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Material(
            color:
                candidateData.isNotEmpty
                    ? colorScheme.primary.withAlpha(40)
                    : (isSelected
                        ? colorScheme.surfaceContainerHighest
                        : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color:
                          isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                          color:
                              isSelected
                                  ? colorScheme.primary
                                  : colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
  }
}
