import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/tags_service.dart';

/// A panel that displays all available tags as clickable chips
/// Similar to the Favorite Notebooks panel in the calendar
class TagsPanel extends StatefulWidget {
  final Function(String tag)? onTagSelected;
  final String? selectedTag;

  const TagsPanel({super.key, this.onTagSelected, this.selectedTag});

  @override
  State<TagsPanel> createState() => _TagsPanelState();
}

class _TagsPanelState extends State<TagsPanel> {
  final TagsService _tagsService = TagsService();
  Map<String, int> _tags = {};
  bool _isLoading = true;
  bool _isExpanded = false;
  late StreamSubscription<Map<String, int>> _tagsSubscription;
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _initializeTags();
    _loadExpandedState();
  }

  @override
  void dispose() {
    _tagsSubscription.cancel();
    super.dispose();
  }

  Future<void> _initializeTags() async {
    await _tagsService.initialize();
    _tagsSubscription = _tagsService.tagsStream.listen((tags) {
      if (mounted) {
        setState(() {
          _tags = tags;
          _isLoading = false;
        });
      }
    });

    // Load initial tags
    final tags = await _tagsService.getAllTags();
    if (mounted) {
      setState(() {
        _tags = tags;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadExpandedState() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _isExpanded = _prefs.getBool('tags_panel_expanded') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_tags.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sort tags by count (descending) then alphabetically
    final sortedTags =
        _tags.entries.toList()..sort((a, b) {
          final countCompare = b.value.compareTo(a.value);
          if (countCompare != 0) return countCompare;
          return a.key.compareTo(b.key);
        });

    return Container(
      padding: const EdgeInsets.only(top: 16, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () async {
              setState(() {
                _isExpanded = !_isExpanded;
              });
              await _prefs.setBool('tags_panel_expanded', _isExpanded);
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Symbols.tag_rounded, size: 20, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Tags',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_tags.length}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: SingleChildScrollView(
                      child: SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              sortedTags.map((entry) {
                                final tag = entry.key;
                                final count = entry.value;
                                final isSelected = widget.selectedTag == tag;

                                return Material(
                                  color:
                                      isSelected
                                          ? colorScheme.primaryContainer
                                          : colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                  child: InkWell(
                                    onTap: () => widget.onTagSelected?.call(tag),
                                    borderRadius: BorderRadius.circular(8),
                                    hoverColor: colorScheme.primary.withAlpha(20),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Symbols.tag_rounded,
                                            size: 16,
                                            color:
                                                isSelected
                                                    ? colorScheme.onPrimaryContainer
                                                    : colorScheme.primary,
                                          ),
                                          Flexible(
                                            child: Text(
                                              tag,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodyMedium?.copyWith(
                                                color:
                                                    isSelected
                                                        ? colorScheme
                                                            .onPrimaryContainer
                                                        : colorScheme.onSurface,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  isSelected
                                                      ? colorScheme.onPrimaryContainer
                                                          .withAlpha(51)
                                                      : colorScheme.primary.withAlpha(
                                                        26,
                                                      ),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              count.toString(),
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall?.copyWith(
                                                color:
                                                    isSelected
                                                        ? colorScheme
                                                            .onPrimaryContainer
                                                        : colorScheme.primary,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
