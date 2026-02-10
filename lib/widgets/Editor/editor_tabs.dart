import 'dart:async';
import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import '../../database/models/editor_tab.dart';
import '../../services/immersive_mode_service.dart';
import '../context_menu.dart';

enum TabDisplayMode {
  full, // Show full title + close button
  compact, // Show truncated title + close button
  minimal, // Show truncated title only
  icon, // Show only icon
}

class EditorTabs extends StatefulWidget {
  final List<EditorTab> tabs;
  final EditorTab? activeTab;
  final Function(EditorTab) onTabSelected;
  final Function(EditorTab) onTabClosed;
  final Function(EditorTab)? onTabTogglePin;
  final VoidCallback? onNewTab;
  final Function(int, int)? onTabReorder;
  final Function(EditorTab)? onOpenNotebook;

  const EditorTabs({
    super.key,
    required this.tabs,
    this.activeTab,
    required this.onTabSelected,
    required this.onTabClosed,
    this.onNewTab,
    this.onTabReorder,
    this.onTabTogglePin,
    this.onOpenNotebook,
  });

  @override
  State<EditorTabs> createState() => EditorTabsState();
}

class EditorTabsState extends State<EditorTabs> {
  final FocusNode _tabsFocusNode = FocusNode();

  int? _dragTargetIndex;
  bool _dragTargetIsLeft = false;
  bool _isDragging = false;

  final Map<int, Rect> _elementBounds = {};

  double? _currentVisualLineX;

  int? _hoveredTabIndex;

  final Map<String, bool> _isExpanded = {}; // true = expanded (full width)
  final Map<String, bool> _isClosing =
      {}; // true = currently animating close (shrinking)
  final Set<String> _suppressNextOpen =
      {}; // keys for which next open animation should be skipped
  bool _suppressNextUpdateAnimations = false;
  bool _skipAnimationsThisBuild = false;
  bool _initialPopulation =
      true; // true until we handle the first non-empty tabs population
  final Set<String> _noAnimateKeys = {};
  static const Duration _kTabAnimDuration = Duration(milliseconds: 100);

  @override
  void initState() {
    super.initState();

    _tabsFocusNode.addListener(() {
      if (_tabsFocusNode.hasFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _ensureActiveTabVisible();
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.tabs.isNotEmpty) {
        setState(() {
          _skipAnimationsThisBuild = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabsFocusNode.dispose();
    super.dispose();
  }

  void requestFocus() {
    if (mounted && _tabsFocusNode.canRequestFocus) {
      FocusScope.of(context).requestFocus(_tabsFocusNode);
    }
  }

  @override
  void didUpdateWidget(EditorTabs oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.activeTab != oldWidget.activeTab && widget.activeTab != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureActiveTabVisible();
      });
    }

    if (_initialPopulation &&
        oldWidget.tabs.isEmpty &&
        widget.tabs.isNotEmpty) {
      _skipAnimationsThisBuild = true;
      _initialPopulation = false;

      for (final tab in widget.tabs) {
        final k = _tabKey(tab);
        _isExpanded[k] = true;
        _isClosing.remove(k);
      }

      return;
    }

    if (_suppressNextUpdateAnimations) {
      _skipAnimationsThisBuild = true;
      _suppressNextUpdateAnimations = false;
      for (final tab in widget.tabs) {
        final k = _tabKey(tab);
        _isExpanded[k] = true;
        _isClosing.remove(k);
      }

      return;
    }

    final oldKeys = oldWidget.tabs.map((t) => _tabKey(t)).toSet();

    for (final tab in widget.tabs) {
      final key = _tabKey(tab);
      if (!oldKeys.contains(key)) {
        _isExpanded[key] = false;
        _isClosing[key] = false;

        if (_initialPopulation) {
          _isExpanded[key] = true;
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;

            Future.delayed(const Duration(milliseconds: 20), () {
              if (!mounted) return;
              setState(() {
                _isExpanded[key] = true;
              });
            });
          });
        }
      }
    }

    final minLen =
        widget.tabs.length < oldWidget.tabs.length
            ? widget.tabs.length
            : oldWidget.tabs.length;
    for (int i = 0; i < minLen; i++) {
      final oldTab = oldWidget.tabs[i];
      final newTab = widget.tabs[i];
      final key = _tabKey(newTab);

      final wasEmpty = oldTab.note == null;
      final isNowWithNote = newTab.note != null;

      if (wasEmpty && isNowWithNote) {
        final noteId = newTab.note?.id;
        if (noteId != null && _suppressNextOpen.remove('note-$noteId')) {
          _isExpanded[key] = true;
        } else {
          if (_initialPopulation) {
            _isExpanded[key] = true;
          } else {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _isExpanded[key] = false;
              });
              Future.delayed(const Duration(milliseconds: 20), () {
                if (!mounted) return;
                setState(() {
                  _isExpanded[key] = true;
                });
              });
            });
          }
        }
      }
    }
  }

  void suppressNextUpdateAnimations() {
    _suppressNextUpdateAnimations = true;
  }

  void suppressNextOpenAnimationForNoteId(int noteId) {
    final key = 'note-$noteId';
    _suppressNextOpen.add(key);
  }

  void _ensureActiveTabVisible() {}

  void _handleTabSelection(EditorTab tab) {
    widget.onTabSelected(tab);
  }

  void _updateDragTargetFromGlobalPosition(Offset globalPosition) {
    for (int i = 0; i < widget.tabs.length; i++) {
      final bounds = _elementBounds[i];
      if (bounds != null && bounds.contains(globalPosition)) {
        final localX = globalPosition.dx - bounds.left;
        final isLeft = localX < bounds.width / 2;

        final visualLineX = isLeft ? bounds.left : bounds.right;

        bool sameVisualLine = false;
        if (_currentVisualLineX != null) {
          sameVisualLine = (visualLineX - _currentVisualLineX!).abs() < 5.0;
        }

        if (!sameVisualLine) {
          setState(() {
            _dragTargetIndex = i;
            _dragTargetIsLeft = isLeft;
            _currentVisualLineX = visualLineX;
          });
        } else {
          _dragTargetIndex = i;
          _dragTargetIsLeft = isLeft;
          _currentVisualLineX = visualLineX;
        }
        return;
      }
    }

    if (_dragTargetIndex != null) {
      setState(() {
        _dragTargetIndex = null;
        _currentVisualLineX = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tabs.isEmpty) {
      return const SizedBox.shrink();
    }

    final isImmersiveMode = ImmersiveModeService().isImmersiveMode;

    final availableWidth = MediaQuery.of(context).size.width;
    final tabsCount = widget.tabs.length;

    final minTabWidth = 120.0;
    final maxTabWidth = 200.0;
    final newTabButtonWidth = 40.0; // Approximate width of new tab button

    final windowControlsWidth = isImmersiveMode ? 138.0 : 0.0;
    final effectiveAvailableWidth = availableWidth - windowControlsWidth;

    final availableForTabs = effectiveAvailableWidth - newTabButtonWidth;
    final double pinnedRatio = 0.7;
    final double unpinnedRatio = 1.0;
    final int pinnedCount = widget.tabs.where((t) => t.isPinned).length;
    final int unpinnedCount = tabsCount - pinnedCount;
    final double totalWeight =
        pinnedCount * pinnedRatio + unpinnedCount * unpinnedRatio;
    final unit = totalWeight > 0 ? (availableForTabs / totalWeight) : 0.0;
    final rawPinnedWidth = unit * pinnedRatio;
    final rawUnpinnedWidth = unit * unpinnedRatio;

    final minPinnedWidth = 80.0;
    final maxPinnedWidth = 140.0;
    final minUnpinnedWidth = minTabWidth;
    final maxUnpinnedWidth = maxTabWidth;

    final actualTabWidth = (availableForTabs / tabsCount).clamp(
      minTabWidth,
      maxTabWidth,
    );

    TabDisplayMode displayMode;
    if (actualTabWidth >= 180) {
      displayMode = TabDisplayMode.full; // Show full title + close button
    } else if (actualTabWidth >= 140) {
      displayMode =
          TabDisplayMode.compact; // Show truncated title + close button
    } else if (actualTabWidth >= 100) {
      displayMode = TabDisplayMode.minimal; // Show truncated title only
    } else {
      displayMode = TabDisplayMode.icon; // Show only icon
    }

    for (final tab in widget.tabs) {
      final key = _tabKey(tab);
      _isExpanded.putIfAbsent(key, () => true);
      _isClosing.putIfAbsent(key, () => false);
    }

    return SizedBox(
      height: 40,
      child: Stack(
        children: [
          Container(
            height: 40,
            color: Theme.of(context).colorScheme.surfaceContainerLow,
          ),

          if (!isImmersiveMode)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 40,
              child: MoveWindow(),
            )
          else
            Positioned(
              top: 0,
              left: 0,
              right: 138, // Width of window controls (3 * 46)
              height: 40,
              child: MoveWindow(),
            ),

          Padding(
            padding: EdgeInsets.only(right: isImmersiveMode ? 138.0 : 0.0),
            child: Container(
              height: 40,
              padding: EdgeInsets.zero,
              child: Stack(
                children: [
                  SizedBox(
                    width: effectiveAvailableWidth,
                    child: Focus(
                      focusNode: _tabsFocusNode,
                      child: Listener(
                        onPointerMove:
                            _isDragging
                                ? (event) {
                                  _updateDragTargetFromGlobalPosition(
                                    event.position,
                                  );
                                }
                                : null,
                        child: Row(
                          children: [
                            ...widget.tabs.asMap().entries.map((entry) {
                              final index = entry.key;
                              final tab = entry.value;
                              final isActive = widget.activeTab == tab;

                              final computedWidth =
                                  tab.isPinned
                                      ? rawPinnedWidth.clamp(
                                        minPinnedWidth,
                                        maxPinnedWidth,
                                      )
                                      : rawUnpinnedWidth.clamp(
                                        minUnpinnedWidth,
                                        maxUnpinnedWidth,
                                      );

                              final tabKey = _tabKey(tab);
                              final isClosing = _isClosing[tabKey] ?? false;
                              final isExpanded = _isExpanded[tabKey] ?? true;
                              final targetWidth =
                                  isClosing
                                      ? 0.0
                                      : (isExpanded ? computedWidth : 0.0);

                              final animDuration =
                                  (_skipAnimationsThisBuild ||
                                          _noAnimateKeys.contains(tabKey))
                                      ? Duration.zero
                                      : _kTabAnimDuration;

                              if (_skipAnimationsThisBuild) {
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (mounted) {
                                    setState(() {
                                      _skipAnimationsThisBuild = false;
                                    });
                                  }
                                });
                              }

                              return Flexible(
                                key: ValueKey(tabKey),
                                child: AnimatedContainer(
                                  width: targetWidth,
                                  duration: animDuration,
                                  curve: Curves.easeInOut,
                                  child:
                                      isClosing
                                          ? Opacity(
                                            opacity: 0.0,
                                            child: SizedBox.shrink(),
                                          )
                                          : _buildDraggableTab(
                                            context,
                                            tab,
                                            isActive,
                                            index,
                                            displayMode,
                                            computedWidth,
                                          ),
                                ),
                              );
                            }),

                            if (widget.onNewTab != null)
                              Container(
                                margin: const EdgeInsets.only(left: 4),
                                decoration: BoxDecoration(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outlineVariant.withAlpha(50),
                                    width: 1,
                                  ),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  child: InkWell(
                                    mouseCursor: SystemMouseCursors.basic,
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: widget.onNewTab,
                                    onHover: (isHovered) {},
                                    child: Container(
                                      height: 30,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.add_rounded,
                                          size: 16,
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _tabKey(EditorTab tab) {
    if (tab.note != null) return 'note-${tab.note!.id}';
    if (tab.tabId != null) return 'tab-${tab.tabId}';
    return 'hash-${tab.hashCode}';
  }

  void _requestCloseTab(EditorTab tab) {
    final key = _tabKey(tab);
    if (_isClosing[key] == true) return; // already closing

    setState(() {
      _isClosing[key] = true;
    });

    Timer(_kTabAnimDuration + const Duration(milliseconds: 20), () {
      if (mounted) {
        setState(() {
          _isClosing.remove(key);
          _isExpanded.remove(key);
        });
      }

      if (widget.activeTab == tab) {
        final idx = widget.tabs.indexOf(tab);
        EditorTab? nextTab;

        if (idx != -1) {
          if (idx < widget.tabs.length - 1) {
            nextTab = widget.tabs[idx + 1];
          } else if (idx > 0) {
            nextTab = widget.tabs[idx - 1];
          }
        }

        if (nextTab != null) {
          widget.onTabSelected(nextTab);
        }
      }

      widget.onTabClosed(tab);
    });
  }

  void requestCloseTab(EditorTab tab) {
    _requestCloseTab(tab);
  }

  Widget _buildDraggableTab(
    BuildContext context,
    EditorTab tab,
    bool isActive,
    int index,
    TabDisplayMode displayMode,
    double tabWidth,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) {
        return details.data != index;
      },
      onLeave: (data) {
        if (_dragTargetIndex == index) {
          setState(() {
            _dragTargetIndex = null;
            _currentVisualLineX = null;
          });
        }
      },
      onAcceptWithDetails: (details) {
        if (widget.onTabReorder != null) {
          final draggedIndex = details.data;
          int targetIndex = index;

          if (_dragTargetIndex == index) {
            if (draggedIndex < index) {
              targetIndex = _dragTargetIsLeft ? index : index + 1;
            } else {
              targetIndex = _dragTargetIsLeft ? index : index + 1;
            }
          } else {
            if (draggedIndex < index) {
              targetIndex = index;
            } else {
              targetIndex = index;
            }
          }

          targetIndex = targetIndex.clamp(0, widget.tabs.length);

          widget.onTabReorder!(draggedIndex, targetIndex);
        }

        setState(() {
          _dragTargetIndex = null;
          _currentVisualLineX = null;
        });
      },
      builder: (context, candidateData, rejectedData) {
        final isTarget = _dragTargetIndex == index && _isDragging;

        return LayoutBuilder(
          builder: (context, constraints) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final RenderBox renderBox =
                  context.findRenderObject() as RenderBox;
              final position = renderBox.localToGlobal(Offset.zero);
              final size = renderBox.size;
              _elementBounds[index] = Rect.fromLTWH(
                position.dx,
                position.dy,
                size.width,
                size.height,
              );
            });

            return Row(
              children: [
                Container(
                  width: isTarget && _dragTargetIsLeft ? 4 : 0,
                  margin: EdgeInsets.symmetric(
                    vertical: isTarget && _dragTargetIsLeft ? 8 : 0,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isTarget && _dragTargetIsLeft
                            ? colorScheme.primary.withAlpha(60)
                            : Colors.transparent,
                    borderRadius:
                        isTarget && _dragTargetIsLeft
                            ? BorderRadius.circular(2)
                            : null,
                  ),
                ),

                Expanded(
                  child: _buildTabItem(
                    tab,
                    isActive,
                    index,
                    displayMode,
                    tabWidth,
                  ),
                ),

                Container(
                  width: isTarget && !_dragTargetIsLeft ? 4 : 0,
                  margin: EdgeInsets.symmetric(
                    vertical: isTarget && !_dragTargetIsLeft ? 8 : 0,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isTarget && !_dragTargetIsLeft
                            ? colorScheme.primary.withAlpha(80)
                            : Colors.transparent,
                    borderRadius:
                        isTarget && !_dragTargetIsLeft
                            ? BorderRadius.circular(2)
                            : null,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTabItem(
    EditorTab tab,
    bool isActive,
    int index,
    TabDisplayMode displayMode,
    double tabWidth,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Draggable<int>(
      data: index,
      onDragStarted: () {
        setState(() {
          _isDragging = true;
        });
      },
      onDragEnd: (details) {
        setState(() {
          _isDragging = false;
          _dragTargetIndex = null;
          _currentVisualLineX = null;
          _elementBounds.clear(); // Clear bounds when drag ends
        });
      },
      feedback: Opacity(
        opacity: 0.9,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: BoxConstraints(minWidth: tabWidth, maxWidth: tabWidth),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outline, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(51),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (displayMode != TabDisplayMode.icon)
                  Flexible(
                    child: Text(
                      tab.displayTitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else
                  Icon(
                    Icons.description_outlined,
                    size: 16,
                    color: colorScheme.onSurface,
                  ),

                if (tab.isPinned && displayMode != TabDisplayMode.icon)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    child: Icon(
                      Icons.push_pin_rounded,
                      size: 14,
                      color: colorScheme.primary,
                    ),
                  ),
                if (tab.isDirty &&
                    (displayMode == TabDisplayMode.full ||
                        displayMode == TabDisplayMode.compact))
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(left: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      childWhenDragging: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        constraints: BoxConstraints(minWidth: tabWidth, maxWidth: tabWidth),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outline.withAlpha(50),
            width: 1,
            style: BorderStyle.solid,
          ),
        ),
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              if (displayMode != TabDisplayMode.icon)
                Expanded(
                  child: Text(
                    tab.displayTitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant.withAlpha(100),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                Expanded(
                  child: Center(
                    child: Icon(
                      Icons.description_outlined,
                      size: 16,
                      color: colorScheme.onSurfaceVariant.withAlpha(100),
                    ),
                  ),
                ),

              if (tab.isPinned && displayMode != TabDisplayMode.icon)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.push_pin_rounded,
                    size: 14,
                    color: colorScheme.onSurfaceVariant.withAlpha(140),
                  ),
                ),
            ],
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        constraints: BoxConstraints(minWidth: tabWidth, maxWidth: tabWidth),
        decoration: BoxDecoration(
          color:
              isActive
                  ? colorScheme.surfaceContainerHighest
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outlineVariant.withAlpha(50),
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: Listener(
            onPointerDown: (event) {
              if (event.buttons == 4 && !tab.isPinned) {
                _requestCloseTab(tab);
              }
            },
            child: InkWell(
              mouseCursor: SystemMouseCursors.basic,
              borderRadius: BorderRadius.circular(12),
              onTap: () => _handleTabSelection(tab),
              onSecondaryTapDown:
                  (details) =>
                      _showTabContextMenu(context, details.globalPosition, tab),
              onHover: (isHovered) {
                setState(() {
                  if (isHovered) {
                    _hoveredTabIndex = index;
                  } else if (_hoveredTabIndex == index) {
                    _hoveredTabIndex = null;
                  }
                });
              },
              child: Container(
                height: 30,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    if (displayMode != TabDisplayMode.icon)
                      Expanded(
                        child: Text(
                          tab.displayTitle,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                isActive ? FontWeight.w600 : FontWeight.normal,
                            color:
                                isActive
                                    ? colorScheme.onSurface
                                    : colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      )
                    else
                      Expanded(
                        child: Center(
                          child: Icon(
                            Icons.description_outlined,
                            size: 16,
                            color:
                                isActive
                                    ? colorScheme.onPrimaryContainer
                                    : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),

                    if (tab.isPinned && displayMode != TabDisplayMode.icon)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        child: Icon(
                          Icons.push_pin_rounded,
                          size: 14,
                          color:
                              isActive
                                  ? colorScheme.onSurface.withAlpha(200)
                                  : colorScheme.onSurfaceVariant,
                        ),
                      ),

                    if (tab.isDirty &&
                        (displayMode == TabDisplayMode.full ||
                            displayMode == TabDisplayMode.compact))
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(left: 6),
                        decoration: BoxDecoration(
                          color:
                              isActive
                                  ? colorScheme.primary
                                  : colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),

                    if (((displayMode == TabDisplayMode.full ||
                                displayMode == TabDisplayMode.compact) ||
                            (displayMode == TabDisplayMode.minimal &&
                                (isActive || _hoveredTabIndex == index))) &&
                        !tab.isPinned) ...[
                      const SizedBox(width: 8),
                      Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          mouseCursor: SystemMouseCursors.basic,
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _requestCloseTab(tab),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color:
                                  isActive
                                      ? colorScheme.onSurfaceVariant.withAlpha(
                                        150,
                                      )
                                      : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showTabContextMenu(
    BuildContext context,
    Offset position,
    EditorTab tab,
  ) {
    final items = [
      ContextMenuItem(
        icon: tab.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
        label: tab.isPinned ? 'Unpin Tab' : 'Pin Tab',
        onTap: () {
          if (widget.onTabTogglePin != null) {
            widget.onTabTogglePin!(tab);
          }
        },
      ),
      if (tab.note != null && widget.onOpenNotebook != null)
        ContextMenuItem(
          icon: Icons.folder_open_rounded,
          label: 'Locate in Notebook',
          onTap: () {
            widget.onOpenNotebook!(tab);
          },
        ),
      ContextMenuItem(
        icon: Icons.close_rounded,
        label: 'Close Tab',
        onTap: () => _requestCloseTab(tab),
      ),
      ContextMenuItem(
        icon: Icons.close_fullscreen_rounded,
        label: 'Close Other Tabs',
        onTap: () {
          final keepKey = _tabKey(tab);
          _noAnimateKeys.add(keepKey);

          Timer(_kTabAnimDuration + const Duration(milliseconds: 80), () {
            if (mounted) {
              setState(() {
                _noAnimateKeys.remove(keepKey);
              });
            }
          });

          for (final otherTab in widget.tabs) {
            if (otherTab != tab) {
              _requestCloseTab(otherTab);
            }
          }
        },
      ),
      ContextMenuItem(
        icon: Icons.close_outlined,
        label: 'Close All Tabs',
        onTap: () {
          for (final otherTab in widget.tabs) {
            _requestCloseTab(otherTab);
          }
        },
      ),
    ];

    ContextMenuOverlay.show(
      context: context,
      tapPosition: position,
      items: items,
    );
  }
}
