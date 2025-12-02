import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../database/models/subtask.dart';
import '../database/database_service.dart';
import '../widgets/confirmation_dialogue.dart';

/// Simple habits tracker widget.
///
/// Stores completions per subtask in the database table `habit_completions` as
/// rows of (subtask_id, date) where date is an ISO yyyy-MM-dd string.
class HabitsTracker extends StatefulWidget {
  final DatabaseService databaseService;
  final List<Subtask> subtasks;
  final int taskId;
  final bool
  hideControls; // if true, don't render internal week/nav and add row
  final int? weekOffset; // external week offset (parent-controlled)
  final bool
  showEmptyMessage; // whether to show 'No habits' when subtasks empty
  final Map<int, List<String>>? initialCompletions;
  final bool
  allowScroll; // if true, allow scrolling even when hideControls is true

  const HabitsTracker({
    super.key,
    required this.databaseService,
    required this.subtasks,
    required this.taskId,
    this.hideControls = false,
    this.weekOffset,
    this.showEmptyMessage = true,
    this.initialCompletions,
    this.allowScroll = false,
  });

  @override
  State<HabitsTracker> createState() => _HabitsTrackerState();
}

class _HabitsTrackerState extends State<HabitsTracker> {
  Map<String, List<String>> _data =
      {}; // subtaskId -> list of date strings (ISO yyyy-MM-dd)
  late DateTime _now;
  late List<Subtask> _localSubtasks;
  final TextEditingController _editingController = TextEditingController();
  final TextEditingController _newSubtaskController = TextEditingController();
  String? _editingSubtaskId;
  String? _originalEditingText;
  late FocusNode _editingFocusNode;
  int _weekOffset = 0;
  // _isWeekHover removed: desktop uses the same OutlinedButton as mobile
  StreamSubscription<void>? _dbSubscription;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _localSubtasks = List.from(widget.subtasks);
    _editingFocusNode = FocusNode();
    // Seed completions from parent if available for immediate rendering.
    if (widget.initialCompletions != null) {
      _data = {};
      for (final sub in _localSubtasks) {
        final key = sub.id?.toString() ?? '';
        if (sub.id != null) {
          final list = widget.initialCompletions![sub.id!] ?? <String>[];
          _data[key] = List<String>.from(list);
        } else {
          _data[key] = [];
        }
      }
      if (mounted) setState(() {});
      // still load fresh data in background
      _loadData();
    } else {
      _loadData();
    }
    // Listen for external DB changes so the tracker updates immediately.
    try {
      _dbSubscription = widget.databaseService.onDatabaseChanged.listen((
        _,
      ) async {
        await _refreshLocalSubtasks();
        await _loadData();
      });
    } catch (_) {}
    _editingFocusNode.addListener(() {
      if (!_editingFocusNode.hasFocus && _editingSubtaskId != null) {
        // small delay to let button handlers run first
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted &&
              !_editingFocusNode.hasFocus &&
              _editingSubtaskId != null) {
            // restore original text and exit edit mode
            _editingController.text =
                _originalEditingText ?? _editingController.text;
            setState(() => _editingSubtaskId = null);
          }
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant HabitsTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If parent provided a new subtasks list, refresh local copy so UI updates immediately.
    if (oldWidget.subtasks != widget.subtasks) {
      _localSubtasks = List.from(widget.subtasks);
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    // No need to remove the anonymous listener explicitly; just dispose the FocusNode.
    _editingFocusNode.dispose();
    _editingController.dispose();
    _newSubtaskController.dispose();
    _dbSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    // Load completions for all subtasks in a single DB query for instant rendering.
    _data = {};
    try {
      final completionsMap = await widget.databaseService.taskService
          .getHabitCompletionsForTask(widget.taskId);
      // Initialize map entries for known subtasks and fill from results.
      for (final sub in _localSubtasks) {
        final key = sub.id?.toString() ?? '';
        if (sub.id != null) {
          final list = completionsMap[sub.id!] ?? <String>[];
          _data[key] = List<String>.from(list);
        } else {
          _data[key] = [];
        }
      }
    } catch (e) {
      // Fallback: ensure every subtask has an entry
      for (final sub in _localSubtasks) {
        final key = sub.id?.toString() ?? '';
        _data[key] = [];
      }
    }
    if (mounted) setState(() {});
  }

  // Persistence handled by database methods; no local save method required.

  bool _isCompletedOn(String subtaskId, DateTime day) {
    final list = _data[subtaskId];
    if (list == null) return false;
    final iso = DateFormat('yyyy-MM-dd').format(DateUtils.dateOnly(day));
    return list.contains(iso);
  }

  void _toggleCompletion(String subtaskId, DateTime day) async {
    final iso = DateFormat('yyyy-MM-dd').format(DateUtils.dateOnly(day));
    final list = _data[subtaskId] ?? [];
    final wasCompleted = list.contains(iso);
    try {
      final numericId = int.tryParse(subtaskId);
      if (numericId != null) {
        await widget.databaseService.taskService.setHabitCompletion(
          numericId,
          iso,
          !wasCompleted,
        );
        if (wasCompleted) {
          list.remove(iso);
        } else {
          list.add(iso);
        }
        _data[subtaskId] = list;
        if (mounted) setState(() {});
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _refreshLocalSubtasks() async {
    try {
      final subs = await widget.databaseService.taskService.getSubtasksByTaskId(
        widget.taskId,
      );
      if (mounted) {
        setState(() {
          _localSubtasks = subs;
        });
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _addSubtask() async {
    final text = _newSubtaskController.text.trim();
    if (text.isEmpty) return;
    try {
      await widget.databaseService.taskService.createSubtask(
        widget.taskId,
        text,
      );
      _newSubtaskController.clear();
      await _refreshLocalSubtasks();
    } catch (e) {
      // ignore
    }
  }

  Future<void> _deleteSubtask(Subtask sub) async {
    if (sub.id == null) return;
    try {
      final confirmed = await showDeleteConfirmationDialog(
        context: context,
        title: 'Delete Habit',
        message: 'Are you sure you want to delete this habit?\n${sub.text}',
        confirmText: 'Delete',
        confirmColor: Theme.of(context).colorScheme.error,
      );
      if (confirmed != true) return;
      await widget.databaseService.taskService.deleteSubtask(sub.id!);
      await _refreshLocalSubtasks();
    } catch (e) {
      // ignore errors for now
    }
  }

  Future<void> _saveSubtaskEditing(Subtask sub) async {
    final newText = _editingController.text.trim();
    if (newText.isNotEmpty && newText != sub.text) {
      final updated = sub.copyWith(text: newText);
      await widget.databaseService.taskService.updateSubtask(updated);
      await _refreshLocalSubtasks();
    }
    setState(() => _editingSubtaskId = null);
  }

  Future<void> _reorderLocalSubtasks(int oldIndex, int newIndex) async {
    // Adjust for ReorderableListView behavior
    if (newIndex > oldIndex) newIndex -= 1;
    final item = _localSubtasks.removeAt(oldIndex);
    _localSubtasks.insert(newIndex, item);
    // Update order indexes in DB
    await widget.databaseService.taskService.reorderSubtasks(_localSubtasks);
    await _refreshLocalSubtasks();
  }

  List<DateTime> _weekDaysForOffset(int offset) {
    final base = DateTime(
      _now.year,
      _now.month,
      _now.day,
    ).add(Duration(days: offset * 7));
    // Week start Monday
    final weekday = base.weekday; // 1..7
    final monday = base.subtract(Duration(days: weekday - 1));
    return List.generate(7, (i) => monday.add(Duration(days: i))).toList();
  }

  // ... no longer using _lastNDays

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveOffset = widget.weekOffset ?? _weekOffset;
    final days = _weekDaysForOffset(effectiveOffset);

    return Column(
      children: [
        // Week navigation + add habit (can be hidden when parent provides controls)
        if (!widget.hideControls) ...[
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Week navigation row
                Row(
                  children: [
                    Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: () => setState(() => _weekOffset--),
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: Icon(
                            Icons.chevron_left_rounded,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          onTap: _weekOffset != 0 ? () => setState(() => _weekOffset = 0) : null,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 36,
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 14,
                                  color:
                                      _weekOffset == 0
                                          ? colorScheme.primary
                                          : colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${DateFormat('MMM d').format(days.first)} - ${DateFormat('MMM d').format(days.last)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color:
                                        _weekOffset == 0
                                            ? colorScheme.primary
                                            : colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: () => setState(() => _weekOffset++),
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: Icon(
                            Icons.chevron_right_rounded,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withAlpha(100),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Material(
                        color: colorScheme.primaryContainer.withAlpha(80),
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          onTap: _addSubtask,
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: Icon(
                              Icons.add_rounded,
                              color: colorScheme.primary,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _newSubtaskController,
                          decoration: InputDecoration(
                            hintText: 'Add habit...',
                            hintStyle: TextStyle(
                              color: colorScheme.onSurfaceVariant.withAlpha(
                                150,
                              ),
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                          ),
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurface,
                          ),
                          onSubmitted: (_) => _addSubtask(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        // When hideControls is true (used in the mobile task detail screen)
        // render the list inline so the outer page scrolls as a whole. In
        // that case we must not use Expanded and the internal list should
        // use shrinkWrap + NeverScrollableScrollPhysics, matching subtasks.
        Builder(
          builder: (ctx) {
            // Use inline mode only if hideControls and not allowScroll
            final inline = widget.hideControls == true && !widget.allowScroll;

            final listPadding =
                inline
                    ? EdgeInsets.only(
                      left: 8,
                      right: 8,
                      top: 4,
                      bottom: MediaQuery.of(context).viewPadding.bottom,
                    )
                    : EdgeInsets.only(
                      left: widget.hideControls ? 8 : 0,
                      right: widget.hideControls ? 8 : 0,
                      top: 4,
                      bottom:
                          widget.hideControls
                              ? MediaQuery.of(context).viewPadding.bottom
                              : 0,
                    );

            final listView =
                _localSubtasks.isEmpty
                    ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child:
                            widget.showEmptyMessage
                                ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.self_improvement_rounded,
                                      size: 48,
                                      color: colorScheme.onSurfaceVariant
                                          .withAlpha(80),
                                    ),
                                    Text(
                                      'No habits yet',
                                      style: TextStyle(
                                        color: colorScheme.onSurfaceVariant
                                            .withAlpha(150),
                                      ),
                                    ),
                                  ],
                                )
                                : const SizedBox.shrink(),
                      ),
                    )
                    : ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      padding: listPadding,
                      shrinkWrap: inline,
                      physics:
                          inline ? const NeverScrollableScrollPhysics() : null,
                      itemCount: _localSubtasks.length,
                      onReorder: _reorderLocalSubtasks,
                      itemBuilder: (context, index) {
                        final sub = _localSubtasks[index];
                        final id = sub.id?.toString() ?? index.toString();
                        // compute completed count in the shown window (last N days)
                        final int completedCount =
                            days.where((d) => _isCompletedOn(id, d)).length;
                        return ReorderableDelayedDragStartListener(
                          key: ValueKey(sub.id ?? index),
                          index: index,
                          child: _HabitItemHover(
                            builder: (context, isHovering) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                decoration: BoxDecoration(
                                  color:
                                      isHovering
                                          ? colorScheme.surfaceContainerHighest
                                          : colorScheme.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Header row: drag + title + streak + actions
                                      Row(
                                        children: [
                                          // Drag handle
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              right: 8,
                                            ),
                                            child: Icon(
                                              Icons.drag_indicator_rounded,
                                              color:
                                                  isHovering
                                                      ? colorScheme
                                                          .onSurfaceVariant
                                                          .withAlpha(150)
                                                      : colorScheme
                                                          .onSurfaceVariant
                                                          .withAlpha(60),
                                              size: 18,
                                            ),
                                          ),
                                          // Title or edit field
                                          Expanded(
                                            child:
                                                _editingSubtaskId ==
                                                        sub.id?.toString()
                                                    ? TextField(
                                                      controller:
                                                          _editingController,
                                                      autofocus: true,
                                                      focusNode:
                                                          _editingFocusNode,
                                                      decoration: InputDecoration(
                                                        isDense: true,
                                                        contentPadding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 10,
                                                              vertical: 8,
                                                            ),
                                                        border: OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                          borderSide: BorderSide(
                                                            color: colorScheme
                                                                .primary
                                                                .withAlpha(100),
                                                          ),
                                                        ),
                                                        enabledBorder: OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                          borderSide: BorderSide(
                                                            color: colorScheme
                                                                .outlineVariant
                                                                .withAlpha(100),
                                                          ),
                                                        ),
                                                        focusedBorder:
                                                            OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    8,
                                                                  ),
                                                              borderSide: BorderSide(
                                                                color:
                                                                    colorScheme
                                                                        .primary,
                                                              ),
                                                            ),
                                                        filled: true,
                                                        fillColor:
                                                            colorScheme.surface,
                                                      ),
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color:
                                                            colorScheme
                                                                .onSurface,
                                                      ),
                                                      onSubmitted:
                                                          (_) =>
                                                              _saveSubtaskEditing(
                                                                sub,
                                                              ),
                                                      onEditingComplete:
                                                          () =>
                                                              _saveSubtaskEditing(
                                                                sub,
                                                              ),
                                                    )
                                                    : GestureDetector(
                                                      onDoubleTap: () {
                                                        _editingController
                                                            .text = sub.text;
                                                        _originalEditingText =
                                                            sub.text;
                                                        setState(
                                                          () =>
                                                              _editingSubtaskId =
                                                                  sub.id
                                                                      ?.toString(),
                                                        );
                                                        WidgetsBinding.instance
                                                            .addPostFrameCallback((
                                                              _,
                                                            ) {
                                                              if (mounted) {
                                                                _editingFocusNode
                                                                    .requestFocus();
                                                              }
                                                            });
                                                      },
                                                      child: Text(
                                                        sub.text,
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color:
                                                              colorScheme
                                                                  .onSurface,
                                                        ),
                                                      ),
                                                    ),
                                          ),
                                          // Action buttons (edit/delete first, then streak)
                                          if (_editingSubtaskId ==
                                              sub.id?.toString()) ...[
                                            const SizedBox(width: 4),
                                            _buildHabitActionButton(
                                              icon: Icons.check_rounded,
                                              color: colorScheme.primary,
                                              onTap:
                                                  () =>
                                                      _saveSubtaskEditing(sub),
                                              colorScheme: colorScheme,
                                            ),
                                            _buildHabitActionButton(
                                              icon: Icons.close_rounded,
                                              color: colorScheme.error,
                                              onTap: () {
                                                _editingController.text =
                                                    sub.text;
                                                setState(
                                                  () =>
                                                      _editingSubtaskId = null,
                                                );
                                              },
                                              colorScheme: colorScheme,
                                            ),
                                          ] else ...[
                                            Opacity(
                                              opacity: isHovering ? 1.0 : 0.0,
                                              child: IgnorePointer(
                                                ignoring: !isHovering,
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    _buildHabitActionButton(
                                                      icon: Icons.edit_rounded,
                                                      color:
                                                          colorScheme
                                                              .onSurfaceVariant,
                                                      onTap: () {
                                                        _editingController
                                                            .text = sub.text;
                                                        _originalEditingText =
                                                            sub.text;
                                                        setState(
                                                          () =>
                                                              _editingSubtaskId =
                                                                  sub.id
                                                                      ?.toString(),
                                                        );
                                                        WidgetsBinding.instance
                                                            .addPostFrameCallback((
                                                              _,
                                                            ) {
                                                              if (mounted) {
                                                                _editingFocusNode
                                                                    .requestFocus();
                                                              }
                                                            });
                                                      },
                                                      colorScheme: colorScheme,
                                                    ),
                                                    _buildHabitActionButton(
                                                      icon:
                                                          Icons
                                                              .delete_outline_rounded,
                                                      color: colorScheme.error
                                                          .withAlpha(180),
                                                      onTap:
                                                          () => _deleteSubtask(
                                                            sub,
                                                          ),
                                                      colorScheme: colorScheme,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                          const SizedBox(width: 4),
                                          // Streak counter (at the end)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  completedCount > 0
                                                      ? colorScheme.primary
                                                          .withAlpha(20)
                                                      : colorScheme
                                                          .surfaceContainerHigh,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons
                                                      .local_fire_department_rounded,
                                                  size: 14,
                                                  color:
                                                      completedCount > 0
                                                          ? colorScheme.primary
                                                          : colorScheme
                                                              .onSurfaceVariant,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '$completedCount/7',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        completedCount > 0
                                                            ? colorScheme
                                                                .primary
                                                            : colorScheme
                                                                .onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      // Days row - rectangular buttons that fill width
                                      Row(
                                        children: List.generate(days.length, (
                                          dayIndex,
                                        ) {
                                          final day = days[dayIndex];
                                          final isToday =
                                              DateUtils.dateOnly(day) ==
                                              DateUtils.dateOnly(_now);
                                          final completed = _isCompletedOn(
                                            id,
                                            day,
                                          );
                                          final dayLabel = DateFormat(
                                            'E',
                                          ).format(day).substring(0, 1);
                                          return Expanded(
                                            child: Padding(
                                              padding: EdgeInsets.only(
                                                left: dayIndex == 0 ? 0 : 3,
                                                right:
                                                    dayIndex == days.length - 1
                                                        ? 0
                                                        : 3,
                                              ),
                                              child: GestureDetector(
                                                onTap:
                                                    () => _toggleCompletion(
                                                      id,
                                                      day,
                                                    ),
                                                child: AnimatedContainer(
                                                  duration: const Duration(
                                                    milliseconds: 150,
                                                  ),
                                                  height: 48,
                                                  decoration: BoxDecoration(
                                                    color:
                                                        completed
                                                            ? colorScheme
                                                                .primary
                                                            : colorScheme
                                                                .surface,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                    border: Border.all(
                                                      color:
                                                          completed
                                                              ? colorScheme
                                                                  .primary
                                                              : isToday
                                                              ? colorScheme
                                                                  .primary
                                                              : colorScheme
                                                                  .outlineVariant
                                                                  .withAlpha(
                                                                    100,
                                                                  ),
                                                      width:
                                                          isToday && !completed
                                                              ? 2
                                                              : 1,
                                                    ),
                                                  ),
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        dayLabel,
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color:
                                                              completed
                                                                  ? colorScheme
                                                                      .onPrimary
                                                                  : isToday
                                                                  ? colorScheme
                                                                      .primary
                                                                  : colorScheme
                                                                      .onSurfaceVariant,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      completed
                                                          ? Icon(
                                                            Icons.check_rounded,
                                                            size: 16,
                                                            color:
                                                                colorScheme
                                                                    .onPrimary,
                                                          )
                                                          : Text(
                                                            DateFormat(
                                                              'd',
                                                            ).format(day),
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              fontWeight:
                                                                  isToday
                                                                      ? FontWeight
                                                                          .w600
                                                                      : FontWeight
                                                                          .w500,
                                                              color:
                                                                  isToday
                                                                      ? colorScheme
                                                                          .primary
                                                                      : colorScheme
                                                                          .onSurface,
                                                            ),
                                                          ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );

            // If inline, return the list directly (no Expanded). Otherwise keep
            // previous behavior and wrap in Expanded so standalone tracker fills
            // available space.
            if (inline) {
              return listView;
            } else {
              return Expanded(child: listView);
            }
          },
        ),
      ],
    );
  }

  Widget _buildHabitActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

// Widget auxiliar para gestionar el estado de hover en habits
class _HabitItemHover extends StatefulWidget {
  final Widget Function(BuildContext, bool) builder;

  const _HabitItemHover({required this.builder});

  @override
  State<_HabitItemHover> createState() => _HabitItemHoverState();
}

class _HabitItemHoverState extends State<_HabitItemHover> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: widget.builder(context, _isHovering),
    );
  }
}
