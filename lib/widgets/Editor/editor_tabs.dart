import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import '../../database/models/editor_tab.dart';
import '../context_menu.dart';

enum TabDisplayMode { full, compact, minimal, icon }

class EditorTabs extends StatefulWidget {
  final List<EditorTab> tabs;
  final EditorTab? activeTab;
  final bool isCalendarPanelExpanded;
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
    required this.isCalendarPanelExpanded,
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

class EditorTabsState extends State<EditorTabs> with TickerProviderStateMixin {
  final FocusNode _tabsFocusNode = FocusNode();

  static const double _kPinnedEmojiOnlyTabWidth = 44.0;
  static const double _kTabBarHeight = 40.0;
  static const Duration _kTabTransitionDuration = Duration(milliseconds: 180);
  static const Duration _kHoverAnimDuration = Duration(milliseconds: 120);
  static const Curve _kTabCurve = Curves.easeOutCubic;
  static const Curve _kTabReverseCurve = Curves.easeInCubic;

  bool _isDragging = false;
  String? _draggingTabKey;
  int? _lastLiveReorderFrom;
  int? _lastLiveReorderTo;

  final Map<int, Rect> _elementBounds = {};
  final Set<int> _hoveredTabIndices = {};

  // Track per-tab close button hover
  final Set<int> _closeHoveredIndices = {};

  final Map<String, bool> _isExpanded = {};
  final Map<String, bool> _isClosing = {};
  final List<String> _mruTabKeys = [];
  final Set<String> _suppressNextOpen = {};
  bool _suppressNextUpdateAnimations = false;
  bool _skipAnimationsThisBuild = false;
  bool _initialPopulation = true;
  final Set<String> _noAnimateKeys = {};

  // Opacity animation controllers for tab open/close
  final Map<String, AnimationController> _opacityControllers = {};
  final Map<String, Animation<double>> _opacityAnimations = {};

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
    for (final ctrl in _opacityControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  AnimationController _getOrCreateOpacityController(String key) {
    if (!_opacityControllers.containsKey(key)) {
      final ctrl = AnimationController(
        vsync: this,
        duration: _kTabTransitionDuration,
        value: 0.0,
      );
      _opacityControllers[key] = ctrl;
      _opacityAnimations[key] = CurvedAnimation(
        parent: ctrl,
        curve: _kTabCurve,
        reverseCurve: _kTabReverseCurve,
      );
    }
    return _opacityControllers[key]!;
  }

  void _setTabFullyVisible(String key) {
    _isExpanded[key] = true;
    _isClosing[key] = false;
    final ctrl = _getOrCreateOpacityController(key);
    ctrl.value = 1.0;
  }

  void _touchMruForTab(EditorTab? tab) {
    if (tab == null) return;
    final key = _tabKey(tab);
    _mruTabKeys.remove(key);
    _mruTabKeys.insert(0, key);
  }

  EditorTab? _pickTabToActivateAfterClose(EditorTab closingTab) {
    final closingKey = _tabKey(closingTab);
    final tabsByKey = {for (final t in widget.tabs) _tabKey(t): t};

    for (final key in _mruTabKeys) {
      if (key == closingKey) continue;
      final candidate = tabsByKey[key];
      if (candidate != null && !(_isClosing[key] ?? false)) {
        return candidate;
      }
    }

    final idx = widget.tabs.indexOf(closingTab);
    if (idx != -1) {
      if (idx < widget.tabs.length - 1) {
        return widget.tabs[idx + 1];
      }
      if (idx > 0) {
        return widget.tabs[idx - 1];
      }
    }

    return null;
  }

  void _animateTabOpen(String key) {
    if (_skipAnimationsThisBuild || _noAnimateKeys.contains(key)) {
      _setTabFullyVisible(key);
      return;
    }

    _isExpanded[key] = false;
    _isClosing[key] = false;

    final ctrl = _getOrCreateOpacityController(key);
    ctrl.stop();
    ctrl.value = 0.0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _isExpanded[key] = true;
      });
      ctrl.forward(from: 0.0);
    });
  }

  void _cleanupAnimationStateForRemovedTabs() {
    final currentKeys = widget.tabs.map((t) => _tabKey(t)).toSet();
    _mruTabKeys.removeWhere((key) => !currentKeys.contains(key));
    final allKnownKeys = {
      ..._isExpanded.keys,
      ..._isClosing.keys,
      ..._opacityControllers.keys,
      ..._opacityAnimations.keys,
    };

    for (final key in allKnownKeys) {
      if (currentKeys.contains(key) || (_isClosing[key] ?? false)) {
        continue;
      }
      _isExpanded.remove(key);
      _isClosing.remove(key);
      _disposeOpacityController(key);
    }
  }

  void _disposeOpacityController(String key) {
    _opacityControllers[key]?.dispose();
    _opacityControllers.remove(key);
    _opacityAnimations.remove(key);
  }

  void requestFocus() {
    if (mounted && _tabsFocusNode.canRequestFocus) {
      FocusScope.of(context).requestFocus(_tabsFocusNode);
    }
  }

  @override
  void didUpdateWidget(EditorTabs oldWidget) {
    super.didUpdateWidget(oldWidget);

    _touchMruForTab(widget.activeTab);

    _cleanupAnimationStateForRemovedTabs();

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
        _setTabFullyVisible(k);
      }

      return;
    }

    final oldKeys = oldWidget.tabs.map((t) => _tabKey(t)).toSet();
    final newKeys = widget.tabs.map((t) => _tabKey(t)).toSet();
    final hasStructuralChange =
        oldWidget.tabs.length != widget.tabs.length ||
        !oldKeys.containsAll(newKeys) ||
        !newKeys.containsAll(oldKeys);

    if (_suppressNextUpdateAnimations) {
      _suppressNextUpdateAnimations = false;
      if (!hasStructuralChange) {
        _skipAnimationsThisBuild = true;
        for (final tab in widget.tabs) {
          final k = _tabKey(tab);
          _setTabFullyVisible(k);
        }

        return;
      }
    }

    for (final tab in widget.tabs) {
      final key = _tabKey(tab);
      if (!oldKeys.contains(key)) {
        if (_initialPopulation) {
          _setTabFullyVisible(key);
        } else {
          _animateTabOpen(key);
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
          _setTabFullyVisible(key);
        } else {
          if (_initialPopulation) {
            _setTabFullyVisible(key);
          } else {
            _animateTabOpen(key);
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

  bool _isEmojiLikeGrapheme(String grapheme) {
    if (grapheme.isEmpty) return false;
    final int firstRune = grapheme.runes.first;

    bool inRange(int start, int end) => firstRune >= start && firstRune <= end;

    return inRange(0x1F1E6, 0x1F1FF) ||
        inRange(0x1F300, 0x1F5FF) ||
        inRange(0x1F600, 0x1F64F) ||
        inRange(0x1F680, 0x1F6FF) ||
        inRange(0x1F700, 0x1F77F) ||
        inRange(0x1F780, 0x1F7FF) ||
        inRange(0x1F800, 0x1F8FF) ||
        inRange(0x1F900, 0x1F9FF) ||
        inRange(0x1FA00, 0x1FAFF) ||
        inRange(0x2600, 0x26FF) ||
        inRange(0x2700, 0x27BF);
  }

  String? _leadingEmojiOrNull(String title) {
    final trimmed = title.trimLeft();
    if (trimmed.isEmpty) return null;

    final firstGrapheme = trimmed.characters.first;
    if (_isEmojiLikeGrapheme(firstGrapheme)) {
      return firstGrapheme;
    }
    return null;
  }

  bool _isPinnedEmojiOnlyTab(EditorTab tab) {
    if (!tab.isPinned) return false;
    return _leadingEmojiOrNull(tab.displayTitle) != null;
  }

  void _handleTabSelection(EditorTab tab) {
    _touchMruForTab(tab);
    widget.onTabSelected(tab);
  }

  void _updateDragTargetFromGlobalPosition(Offset globalPosition) {
    if (!_isDragging ||
        widget.onTabReorder == null ||
        _draggingTabKey == null) {
      return;
    }

    final draggingKey = _draggingTabKey!;
    final draggedIndex = widget.tabs.indexWhere(
      (t) => _tabKey(t) == draggingKey,
    );
    if (draggedIndex == -1) return;

    final tabBounds = _elementBounds.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    if (tabBounds.isEmpty) {
      return;
    }

    final pointerX = globalPosition.dx;
    int targetIndex = widget.tabs.length;
    for (final entry in tabBounds) {
      final centerX = entry.value.left + (entry.value.width / 2);
      if (pointerX < centerX) {
        targetIndex = entry.key;
        break;
      }
    }

    if (targetIndex == draggedIndex || targetIndex == draggedIndex + 1) {
      return;
    }

    if (_lastLiveReorderFrom == draggedIndex &&
        _lastLiveReorderTo == targetIndex) {
      return;
    }

    _lastLiveReorderFrom = draggedIndex;
    _lastLiveReorderTo = targetIndex;
    widget.onTabReorder!(
      draggedIndex,
      targetIndex.clamp(0, widget.tabs.length),
    );
  }

  Widget _buildTitleWithEmoji({
    required String title,
    required String emoji,
    required TextStyle textStyle,
    required Color emojiColor,
  }) {
    final rest = title.trimLeft().substring(emoji.length);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Transform.translate(
          offset: const Offset(0, -1),
          child: Text(
            emoji,
            style: TextStyle(
              fontSize: textStyle.fontSize,
              height: 1.0,
              leadingDistribution: TextLeadingDistribution.even,
              color: emojiColor,
            ),
            strutStyle: const StrutStyle(
              forceStrutHeight: true,
              height: 1.0,
              leading: 0,
            ),
            maxLines: 1,
            overflow: TextOverflow.clip,
            softWrap: false,
          ),
        ),
        if (rest.isNotEmpty) ...[
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              rest,
              style: textStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ),
        ],
      ],
    );
  }

@override
Widget build(BuildContext context) {
  if (widget.tabs.isEmpty) {
    return const SizedBox.shrink();
  }

  final reserveRightSpace = !widget.isCalendarPanelExpanded;

  return LayoutBuilder(
    builder: (context, constraints) {
      final availableWidth = constraints.maxWidth;
      final tabsCount = widget.tabs.length;

      const double minTabWidth = 100.0;
      const double maxTabWidth = 200.0;
      const double newTabButtonWidth = 38.0;

      final windowControlsWidth = reserveRightSpace ? 138.0 : 0.0;
      final effectiveAvailableWidth = availableWidth - windowControlsWidth;

      final availableForTabs = effectiveAvailableWidth - newTabButtonWidth;
      const double pinnedRatio = 0.7;
      const double unpinnedRatio = 1.0;

      const double minPinnedWidth = 80.0;
      const double maxPinnedWidth = 140.0;
      const double minUnpinnedWidth = minTabWidth;
      const double maxUnpinnedWidth = maxTabWidth;

      final tabWidths = _computeTabWidths(
        tabs: widget.tabs,
        availableForTabs: availableForTabs,
        pinnedRatio: pinnedRatio,
        unpinnedRatio: unpinnedRatio,
        fixedEmojiOnlyWidth: _kPinnedEmojiOnlyTabWidth,
        minPinnedWidth: minPinnedWidth,
        maxPinnedWidth: maxPinnedWidth,
        minUnpinnedWidth: minUnpinnedWidth,
        maxUnpinnedWidth: maxUnpinnedWidth,
      );

      final actualTabWidth = tabsCount > 0 ? (availableForTabs / tabsCount) : 0.0;

      TabDisplayMode displayMode;
      if (actualTabWidth >= 180) {
        displayMode = TabDisplayMode.full;
      } else if (actualTabWidth >= 140) {
        displayMode = TabDisplayMode.compact;
      } else if (actualTabWidth >= 100) {
        displayMode = TabDisplayMode.minimal;
      } else {
        displayMode = TabDisplayMode.icon;
      }

      for (final tab in widget.tabs) {
        final key = _tabKey(tab);
        _isExpanded.putIfAbsent(key, () => true);
        _isClosing.putIfAbsent(key, () => false);
        final ctrl = _getOrCreateOpacityController(key);
        if (ctrl.value == 0.0 &&
            (_isExpanded[key] ?? false) &&
            !_isClosing[key]!) {
          ctrl.value = 1.0;
        }
      }

      final colorScheme = Theme.of(context).colorScheme;

      return SizedBox(
        height: _kTabBarHeight,
        child: Stack(
          children: [
            Container(
              height: _kTabBarHeight,
              color: colorScheme.surfaceContainerLow,
            ),

            if (!Platform.isMacOS)
              if (!reserveRightSpace)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: _kTabBarHeight,
                  child: MoveWindow(),
                )
              else
                Positioned(
                  top: 0,
                  left: 0,
                  right: 138,
                  height: _kTabBarHeight,
                  child: MoveWindow(),
                ),

            Padding(
              padding: EdgeInsets.only(right: reserveRightSpace ? 138.0 : 0.0),
              child: SizedBox(
                width: effectiveAvailableWidth,
                height: _kTabBarHeight,
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
                    child: Stack(
                      children: _buildAnimatedTabSlots(
                        context: context,
                        displayMode: displayMode,
                        newTabButtonWidth: newTabButtonWidth,
                        tabWidths: tabWidths,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

  Widget _buildClosingTabPlaceholder(String tabKey) {
    final anim = _opacityAnimations[tabKey];
    if (anim != null) {
      return FadeTransition(opacity: anim, child: const SizedBox.expand());
    }
    return const SizedBox.expand();
  }

  List<Widget> _buildAnimatedTabSlots({
    required BuildContext context,
    required TabDisplayMode displayMode,
    required double newTabButtonWidth,
    required List<double> tabWidths,
  }) {
    final slots = <Widget>[];
    final tabLayouts = <_TabLayoutData>[];
    double currentLeft = 0.0;

    for (final entry in widget.tabs.asMap().entries) {
      final index = entry.key;
      final tab = entry.value;
      final isActive = widget.activeTab == tab;
      final computedWidth = tabWidths[index];

      final tabKey = _tabKey(tab);
      final isClosing = _isClosing[tabKey] ?? false;
      final isExpanded = _isExpanded[tabKey] ?? true;
      final targetWidth = isClosing ? 0.0 : (isExpanded ? computedWidth : 0.0);

      final animDuration =
          (_skipAnimationsThisBuild || _noAnimateKeys.contains(tabKey))
              ? Duration.zero
              : _kTabTransitionDuration;

      if (_skipAnimationsThisBuild) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _skipAnimationsThisBuild = false;
            });
          }
        });
      }

      final nextTab =
          index < widget.tabs.length - 1 ? widget.tabs[index + 1] : null;
      final nextIsActive = nextTab != null && widget.activeTab == nextTab;
      final isHovered = _hoveredTabIndices.contains(index);
      final nextIsHovered =
          index < widget.tabs.length - 1
              ? _hoveredTabIndices.contains(index + 1)
              : false;
      final showRightSeparator =
          !isActive && !nextIsActive && !_isDragging && !isHovered && !nextIsHovered;

      tabLayouts.add(
        _TabLayoutData(
          key: tabKey,
          left: currentLeft,
          width: targetWidth,
          duration: animDuration,
          tab: tab,
          index: index,
          isActive: isActive,
          tabWidth: computedWidth,
          showRightSeparator: showRightSeparator,
          isClosing: isClosing,
        ),
      );

      currentLeft += targetWidth;
    }

    final newTabLeft = currentLeft;

    for (final layout in tabLayouts) {
      slots.add(
        AnimatedPositioned(
          key: ValueKey(layout.key),
          duration: layout.duration,
          curve: _kTabCurve,
          left: layout.left,
          top: 0,
          bottom: 0,
          width: layout.width,
          child:
              layout.isClosing
                  ? _buildClosingTabPlaceholder(layout.key)
                  : _buildDraggableTab(
                    context,
                    layout.tab,
                    layout.isActive,
                    layout.index,
                    displayMode,
                    layout.tabWidth,
                    layout.showRightSeparator,
                  ),
        ),
      );
    }

    if (widget.onNewTab != null) {
      slots.add(
        AnimatedPositioned(
          duration: _kTabTransitionDuration,
          curve: _kTabCurve,
          left: newTabLeft,
          top: 0,
          bottom: 0,
          width: newTabButtonWidth,
          child: _buildNewTabButton(context, Theme.of(context).colorScheme),
        ),
      );
    }

    return slots;
  }

  List<double> _computeTabWidths({
    required List<EditorTab> tabs,
    required double availableForTabs,
    required double pinnedRatio,
    required double unpinnedRatio,
    required double fixedEmojiOnlyWidth,
    required double minPinnedWidth,
    required double maxPinnedWidth,
    required double minUnpinnedWidth,
    required double maxUnpinnedWidth,
  }) {
    final widths = List<double>.filled(tabs.length, 0.0);
    final minWidths = List<double>.filled(tabs.length, 0.0);
    final maxWidths = List<double>.filled(tabs.length, 0.0);
    final weights = List<double>.filled(tabs.length, 0.0);
    final flexIndices = <int>[];

    double fixedTotal = 0.0;
    double flexWeightTotal = 0.0;

    for (int i = 0; i < tabs.length; i++) {
      final tab = tabs[i];
      final isPinnedEmojiOnly = _isPinnedEmojiOnlyTab(tab);

      if (isPinnedEmojiOnly) {
        widths[i] = fixedEmojiOnlyWidth;
        fixedTotal += fixedEmojiOnlyWidth;
        continue;
      }

      final minWidth = tab.isPinned ? minPinnedWidth : minUnpinnedWidth;
      final maxWidth = tab.isPinned ? maxPinnedWidth : maxUnpinnedWidth;
      final weight = tab.isPinned ? pinnedRatio : unpinnedRatio;

      minWidths[i] = minWidth;
      maxWidths[i] = maxWidth;
      weights[i] = weight;
      flexIndices.add(i);
      flexWeightTotal += weight;
    }

    double remainingSpace = availableForTabs - fixedTotal;
    if (remainingSpace < 0) remainingSpace = 0;

    if (flexIndices.isNotEmpty) {
      for (final i in flexIndices) {
        final provisional =
            flexWeightTotal > 0 ? (remainingSpace * weights[i] / flexWeightTotal) : 0.0;
        widths[i] = provisional.clamp(minWidths[i], maxWidths[i]);
      }

      const double epsilon = 0.01;
      double totalWidth = widths.fold(0.0, (sum, width) => sum + width);

      if (totalWidth < availableForTabs - epsilon) {
        double extra = availableForTabs - totalWidth;
        var growable =
            flexIndices.where((i) => widths[i] < maxWidths[i] - epsilon).toList();

        while (extra > epsilon && growable.isNotEmpty) {
          final share = extra / growable.length;
          final nextGrowable = <int>[];

          for (final i in growable) {
            final capacity = maxWidths[i] - widths[i];
            final delta = share < capacity ? share : capacity;
            widths[i] += delta;
            extra -= delta;

            if (widths[i] < maxWidths[i] - epsilon) {
              nextGrowable.add(i);
            }
          }

          if (nextGrowable.length == growable.length) {
            break;
          }

          growable = nextGrowable;
        }
      } else if (totalWidth > availableForTabs + epsilon) {
        double shortage = totalWidth - availableForTabs;
        var shrinkable =
            flexIndices.where((i) => widths[i] > minWidths[i] + epsilon).toList();

        while (shortage > epsilon && shrinkable.isNotEmpty) {
          final share = shortage / shrinkable.length;
          final nextShrinkable = <int>[];

          for (final i in shrinkable) {
            final room = widths[i] - minWidths[i];
            final delta = share < room ? share : room;
            widths[i] -= delta;
            shortage -= delta;

            if (widths[i] > minWidths[i] + epsilon) {
              nextShrinkable.add(i);
            }
          }

          if (nextShrinkable.length == shrinkable.length) {
            break;
          }

          shrinkable = nextShrinkable;
        }
      }
    }

    return widths;
  }

  Widget _buildNewTabButton(BuildContext context, ColorScheme colorScheme) {
    return _HoverButton(
      hoverDuration: _kHoverAnimDuration,
      builder:
          (isHovered) => Container(
            width: 32,
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 3),
            decoration: BoxDecoration(
              color:
                  isHovered
                      ? colorScheme.onSurface.withAlpha(12)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                mouseCursor: SystemMouseCursors.click,
                borderRadius: BorderRadius.circular(6),
                onTap: widget.onNewTab,
                splashColor: colorScheme.primary.withAlpha(20),
                highlightColor: Colors.transparent,
                child: Center(
                  child: AnimatedContainer(
                    duration: _kHoverAnimDuration,
                    child: Icon(
                      Icons.add_rounded,
                      size: 16,
                      color:
                          isHovered
                              ? colorScheme.onSurface.withAlpha(200)
                              : colorScheme.onSurfaceVariant.withAlpha(160),
                    ),
                  ),
                ),
              ),
            ),
          ),
    );
  }

  void _resetDragState() {
    _isDragging = false;
    _draggingTabKey = null;
    _lastLiveReorderFrom = null;
    _lastLiveReorderTo = null;
    _elementBounds.clear();
  }

  String _tabKey(EditorTab tab) {
    if (tab.note != null) return 'note-${tab.note!.id}';
    if (tab.tabId != null) return 'tab-${tab.tabId}';
    return 'hash-${tab.hashCode}';
  }

  void _requestCloseTab(EditorTab tab) {
    final key = _tabKey(tab);
    if (_isClosing[key] == true) return;

    if (widget.activeTab == tab) {
      final nextTab = _pickTabToActivateAfterClose(tab);

      if (nextTab != null) {
        widget.onTabSelected(nextTab);
      }
    }

    final ctrl = _getOrCreateOpacityController(key);

    if (ctrl.value <= 0.0) {
      ctrl.value = 1.0;
    }

    setState(() {
      _isClosing[key] = true;
    });

    ctrl.reverse().then((_) {
      if (!mounted) return;
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
    bool showRightSeparator,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          try {
            final RenderBox renderBox = context.findRenderObject() as RenderBox;
            final position = renderBox.localToGlobal(Offset.zero);
            final size = renderBox.size;
            _elementBounds[index] = Rect.fromLTWH(
              position.dx,
              position.dy,
              size.width,
              size.height,
            );
          } catch (_) {}
        });

        return _buildTabItem(
          tab,
          isActive,
          index,
          displayMode,
          tabWidth,
          showRightSeparator,
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
    bool showRightSeparator,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    final leadingEmoji = _leadingEmojiOrNull(tab.displayTitle);
    final isPinnedEmojiOnly = tab.isPinned && leadingEmoji != null;

    final tabKey = _tabKey(tab);
    final opacityAnim = _opacityAnimations[tabKey];

    Widget tabContent = _HoverBuilder(
      hoverDuration: _kHoverAnimDuration,
      onHoverChanged: (hovered) {
        setState(() {
          if (hovered) {
            _hoveredTabIndices.add(index);
          } else {
            _hoveredTabIndices.remove(index);
          }
        });
      },
      builder: (isHovered) {
        final isCloseHovered = _closeHoveredIndices.contains(index);
        final showClose =
            !isPinnedEmojiOnly && !tab.isPinned && (isActive || isHovered);

        return Draggable<String>(
          data: tabKey,
          axis: Axis.horizontal,
          feedbackOffset: const Offset(0, -3),
          onDragStarted: () {
            setState(() {
              _isDragging = true;
              _draggingTabKey = tabKey;
              _lastLiveReorderFrom = null;
              _lastLiveReorderTo = null;
            });
          },
          onDragEnd: (details) {
            setState(_resetDragState);
          },
          feedback: _buildDragFeedback(
            context,
            tab,
            tabWidth,
            isPinnedEmojiOnly,
            leadingEmoji,
            displayMode,
            colorScheme,
          ),
          childWhenDragging: _buildDragPlaceholder(
            tab,
            tabWidth,
            isPinnedEmojiOnly,
            leadingEmoji,
            displayMode,
            colorScheme,
          ),
          child: _buildTabBody(
            context,
            tab,
            isActive,
            isHovered,
            index,
            displayMode,
            tabWidth,
            isPinnedEmojiOnly,
            leadingEmoji,
            showClose,
            isCloseHovered,
            showRightSeparator,
            colorScheme,
          ),
        );
      },
    );

    if (opacityAnim != null) {
      tabContent = FadeTransition(opacity: opacityAnim, child: tabContent);
    }

    return tabContent;
  }

  Widget _buildTabBody(
    BuildContext context,
    EditorTab tab,
    bool isActive,
    bool isHovered,
    int index,
    TabDisplayMode displayMode,
    double tabWidth,
    bool isPinnedEmojiOnly,
    String? leadingEmoji,
    bool showClose,
    bool isCloseHovered,
    bool showRightSeparator,
    ColorScheme colorScheme,
  ) {
    // Colors
    final activeTabColor = colorScheme.surface;
    final hoverTabColor = colorScheme.onSurface.withAlpha(10);

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Stack(
        children: [
          // Main tab container
          Positioned.fill(
            child: AnimatedContainer(
              duration: _kHoverAnimDuration,
              curve: _kTabCurve,
              decoration: BoxDecoration(
                color:
                    isActive
                        ? activeTabColor
                        : (isHovered ? hoverTabColor : Colors.transparent),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
                // Subtle top border for active tab
                border:
                    isActive
                        ? Border(
                          left: BorderSide(
                            color: colorScheme.outlineVariant.withAlpha(60),
                            width: 1,
                          ),
                          right: BorderSide(
                            color: colorScheme.outlineVariant.withAlpha(60),
                            width: 1,
                          ),
                          top: BorderSide(
                            color: colorScheme.outlineVariant.withAlpha(60),
                            width: 1,
                          ),
                        )
                        : null,
              ),
            ),
          ),

          // Active tab primary indicator (bottom)
          if (isActive)
            Positioned(
              bottom: 0,
              left: 6,
              right: 6,
              child: AnimatedContainer(
                duration: _kTabTransitionDuration,
                curve: _kTabCurve,
                height: 2,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(2),
                    topRight: Radius.circular(2),
                  ),

                ),
              ),
            ),

          // Right separator between inactive tabs
          if (showRightSeparator && !isActive)
            Positioned(
              right: 0,
              top: 8,
              bottom: 8,
              child: Container(
                width: 1,
                color: colorScheme.outline.withAlpha(100),
              ),
            ),

          // Clickable content area
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: Listener(
                onPointerDown: (event) {
                  if (event.buttons == 4 && !tab.isPinned) {
                    _requestCloseTab(tab);
                  }
                },
                child: InkWell(
                  mouseCursor: SystemMouseCursors.basic,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                  splashColor: colorScheme.primary.withAlpha(15),
                  highlightColor: Colors.transparent,
                  onTap: () => _handleTabSelection(tab),
                  onSecondaryTapDown:
                      (details) => _showTabContextMenu(
                        context,
                        details.globalPosition,
                        tab,
                      ),
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: isPinnedEmojiOnly ? 0 : 10,
                      right: isPinnedEmojiOnly ? 0 : (showClose ? 4 : 10),
                    ),
                    child: Row(
                      mainAxisAlignment:
                          isPinnedEmojiOnly
                              ? MainAxisAlignment.center
                              : MainAxisAlignment.start,
                      children: [
                        // Tab title / emoji content
                        if (isPinnedEmojiOnly)
                          Transform.translate(
                            offset: const Offset(0, -1),
                            child: Text(
                              leadingEmoji!,
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.0,
                                leadingDistribution:
                                    TextLeadingDistribution.even,
                                color:
                                    isActive
                                        ? colorScheme.onSurface
                                        : colorScheme.onSurfaceVariant,
                              ),
                              strutStyle: const StrutStyle(
                                forceStrutHeight: true,
                                height: 1.0,
                                leading: 0,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              softWrap: false,
                            ),
                          )
                        else if (displayMode != TabDisplayMode.icon)
                          Expanded(
                            child:
                                leadingEmoji != null
                                    ? _buildTitleWithEmoji(
                                      title: tab.displayTitle,
                                      emoji: leadingEmoji,
                                      textStyle: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight:
                                            isActive
                                                ? FontWeight.w500
                                                : FontWeight.normal,
                                        color:
                                            isActive
                                                ? colorScheme.onSurface
                                                : colorScheme.onSurfaceVariant,
                                      ),
                                      emojiColor:
                                          isActive
                                              ? colorScheme.onSurface
                                              : colorScheme.onSurfaceVariant,
                                    )
                                    : Text(
                                      tab.displayTitle,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight:
                                            isActive
                                                ? FontWeight.w500
                                                : FontWeight.normal,
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
                                size: 15,
                                color:
                                    isActive
                                        ? colorScheme.onSurface
                                        : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),

                        // Pin icon for non-emoji-only pinned tabs
                        if (!isPinnedEmojiOnly &&
                            tab.isPinned &&
                            displayMode != TabDisplayMode.icon)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.push_pin_rounded,
                              size: 12,
                              color:
                                  isActive
                                      ? colorScheme.primary
                                      : colorScheme.onSurfaceVariant.withAlpha(
                                        160,
                                      ),
                            ),
                          ),

                        // Close button or dirty indicator
                        if (showClose)
                          _buildCloseOrDirtyButton(
                            tab,
                            index,
                            isActive,
                            isHovered,
                            colorScheme,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCloseOrDirtyButton(
    EditorTab tab,
    int index,
    bool isActive,
    bool isHovered,
    ColorScheme colorScheme,
  ) {
    final isCloseHovered = _closeHoveredIndices.contains(index);
    // Show dirty dot when: tab is dirty, not hovered on close button
    final showDirtyDot = tab.isDirty && !isCloseHovered;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _closeHoveredIndices.add(index)),
      onExit: (_) => setState(() => _closeHoveredIndices.remove(index)),
      child: GestureDetector(
        onTap: () => _requestCloseTab(tab),
        child: AnimatedContainer(
          duration: _kHoverAnimDuration,
          width: 18,
          height: 18,
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            color:
                isCloseHovered
                    ? colorScheme.onSurface.withAlpha(18)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: _kHoverAnimDuration,
              transitionBuilder: (child, anim) {
                final curved = CurvedAnimation(
                  parent: anim,
                  curve: _kTabCurve,
                  reverseCurve: _kTabReverseCurve,
                );
                return ScaleTransition(
                  scale: curved,
                  child: FadeTransition(opacity: curved, child: child),
                );
              },
              child:
                  showDirtyDot
                      ? Container(
                        key: const ValueKey('dot'),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      )
                      : Icon(
                        key: const ValueKey('x'),
                        Icons.close_rounded,
                        size: 13,
                        color:
                            isCloseHovered
                                ? colorScheme.onSurface.withAlpha(220)
                                : (isActive
                                    ? colorScheme.onSurface.withAlpha(140)
                                    : colorScheme.onSurfaceVariant.withAlpha(
                                      140,
                                    )),
                      ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDragFeedback(
    BuildContext context,
    EditorTab tab,
    double tabWidth,
    bool isPinnedEmojiOnly,
    String? leadingEmoji,
    TabDisplayMode displayMode,
    ColorScheme colorScheme,
  ) {
    return Material(
      elevation: 0,
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(minWidth: tabWidth, maxWidth: tabWidth),
        height: _kTabBarHeight,
        padding: const EdgeInsets.only(top: 3),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
            border: Border(
              top: BorderSide(
                color: colorScheme.outlineVariant.withAlpha(90),
                width: 1,
              ),
              left: BorderSide(
                color: colorScheme.outlineVariant.withAlpha(90),
                width: 1,
              ),
              right: BorderSide(
                color: colorScheme.outlineVariant.withAlpha(90),
                width: 1,
              ),
            ),
          ),
          child: Container(
            padding:
                isPinnedEmojiOnly
                    ? const EdgeInsets.symmetric(horizontal: 0, vertical: 4)
                    : const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isPinnedEmojiOnly)
                  Expanded(
                    child: Center(
                      child: Text(
                        leadingEmoji!,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.0,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  )
                else if (displayMode != TabDisplayMode.icon)
                  Flexible(
                    child:
                        leadingEmoji != null
                            ? _buildTitleWithEmoji(
                              title: tab.displayTitle,
                              emoji: leadingEmoji,
                              textStyle: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurface,
                              ),
                              emojiColor: colorScheme.onSurface,
                            )
                            : Text(
                              tab.displayTitle,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurface,
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
                        size: 15,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDragPlaceholder(
    EditorTab tab,
    double tabWidth,
    bool isPinnedEmojiOnly,
    String? leadingEmoji,
    TabDisplayMode displayMode,
    ColorScheme colorScheme,
  ) {
    return const SizedBox.expand();
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

          Timer(_kTabTransitionDuration + const Duration(milliseconds: 60), () {
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

// ---------------------------------------------------------------------------
// Helper: Hover-aware builder widget
// ---------------------------------------------------------------------------
class _HoverBuilder extends StatefulWidget {
  final Duration hoverDuration;
  final ValueChanged<bool>? onHoverChanged;
  final Widget Function(bool isHovered) builder;

  const _HoverBuilder({
    required this.hoverDuration,
    this.onHoverChanged,
    required this.builder,
  });

  @override
  State<_HoverBuilder> createState() => _HoverBuilderState();
}

class _HoverBuilderState extends State<_HoverBuilder> {
  bool _isHovered = false;

  void _setHovered(bool value) {
    if (_isHovered == value) return;
    setState(() => _isHovered = value);
    widget.onHoverChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: widget.builder(_isHovered),
    );
  }
}

class _TabLayoutData {
  final String key;
  final double left;
  final double width;
  final Duration duration;
  final EditorTab tab;
  final int index;
  final bool isActive;
  final double tabWidth;
  final bool showRightSeparator;
  final bool isClosing;

  const _TabLayoutData({
    required this.key,
    required this.left,
    required this.width,
    required this.duration,
    required this.tab,
    required this.index,
    required this.isActive,
    required this.tabWidth,
    required this.showRightSeparator,
    required this.isClosing,
  });
}

// ---------------------------------------------------------------------------
// Helper: Hover-aware button wrapper
// ---------------------------------------------------------------------------
class _HoverButton extends StatefulWidget {
  final Duration hoverDuration;
  final Widget Function(bool isHovered) builder;

  const _HoverButton({required this.hoverDuration, required this.builder});

  @override
  State<_HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<_HoverButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: widget.builder(_isHovered),
    );
  }
}
