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
  final bool hideControls; // if true, don't render internal week/nav and add row
  final int? weekOffset; // external week offset (parent-controlled)
  final bool showEmptyMessage; // whether to show 'No habits' when subtasks empty
  final Map<int, List<String>>? initialCompletions;

  const HabitsTracker({
    super.key,
    required this.databaseService,
    required this.subtasks,
    required this.taskId,
    this.hideControls = false,
    this.weekOffset,
  this.showEmptyMessage = true,
  this.initialCompletions,
  });

  @override
  State<HabitsTracker> createState() => _HabitsTrackerState();
}

class _HabitsTrackerState extends State<HabitsTracker> {
  Map<String, List<String>> _data = {}; // subtaskId -> list of date strings (ISO yyyy-MM-dd)
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
    _dbSubscription = widget.databaseService.onDatabaseChanged.listen((_) async {
      await _refreshLocalSubtasks();
      await _loadData();
    });
  } catch (_) {}
  _editingFocusNode.addListener(() {
      if (!_editingFocusNode.hasFocus && _editingSubtaskId != null) {
        // small delay to let button handlers run first
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted && !_editingFocusNode.hasFocus && _editingSubtaskId != null) {
            // restore original text and exit edit mode
            _editingController.text = _originalEditingText ?? _editingController.text;
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
      final completionsMap = await widget.databaseService.taskService.getHabitCompletionsForTask(widget.taskId);
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
        await widget.databaseService.taskService.setHabitCompletion(numericId, iso, !wasCompleted);
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
      final subs = await widget.databaseService.taskService.getSubtasksByTaskId(widget.taskId);
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
  await widget.databaseService.taskService.createSubtask(widget.taskId, text);
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
    final base = DateTime(_now.year, _now.month, _now.day).add(Duration(days: offset * 7));
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
        // Week navigation + add row (can be hidden when parent provides controls)
        if (!widget.hideControls) ...[
          // Week navigation
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () {
                    setState(() => _weekOffset--);
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Return to current week
                        if (_weekOffset != 0) {
                          setState(() => _weekOffset = 0);
                        }
                      },
                      icon: Icon(Icons.date_range_rounded, size: 18, color: colorScheme.onSurfaceVariant),
                      label: Text(
                        '${DateFormat('MMM d').format(days.first)} - ${DateFormat('MMM d').format(days.last)}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: colorScheme.surface,
                        side: const BorderSide(color: Colors.transparent),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded),
                  onPressed: () {
                    setState(() => _weekOffset++);
                  },
                ),
              ],
            ),
          ),

          Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _addSubtask,
                    child: Center(
                      child: Icon(
                        Icons.add_rounded,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _newSubtaskController,
                  decoration: InputDecoration(
                    labelText: 'Add new habit',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withAlpha(127),
                    prefixIcon: Icon(
                      Icons.add_task_rounded,
                      color: colorScheme.primary,
                    ),
                  ),
                  onSubmitted: (_) => _addSubtask(),
                ),
              ),
            ],
          ),
        ],

          // When hideControls is true (used in the mobile task detail screen)
          // render the list inline so the outer page scrolls as a whole. In
          // that case we must not use Expanded and the internal list should
          // use shrinkWrap + NeverScrollableScrollPhysics, matching subtasks.
          Builder(builder: (ctx) {
            final inline = widget.hideControls == true;

            final listPadding = inline
                ? EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 8,
                    bottom: MediaQuery.of(context).viewPadding.bottom,
                  )
                : EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 8,
                    bottom: MediaQuery.of(context).viewPadding.bottom,
                  );

            final listView = _localSubtasks.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: widget.showEmptyMessage
                          ? Text('No habits', style: TextStyle(color: colorScheme.onSurfaceVariant))
                          : const SizedBox.shrink(),
                    ),
                  )
                : ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    padding: listPadding,
                    shrinkWrap: inline,
                    physics: inline ? const NeverScrollableScrollPhysics() : null,
                    itemCount: _localSubtasks.length,
                    onReorder: _reorderLocalSubtasks,
                    itemBuilder: (context, index) {
                      final sub = _localSubtasks[index];
                      final id = sub.id?.toString() ?? index.toString();
                      // compute completed count in the shown window (last N days)
                      final int completedCount = days.where((d) => _isCompletedOn(id, d)).length;
                      return ReorderableDelayedDragStartListener(
                        key: ValueKey(sub.id ?? index),
                        index: index,
                        child: Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    // leading habit icon (no background to match other list items)
                                    SizedBox(
                                      width: 36,
                                      height: 36,
                                      child: Center(
                                        child: Icon(
                                          Icons.self_improvement_rounded,
                                          size: 20,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: _editingSubtaskId == sub.id?.toString()
                                          ? TextField(
                                              controller: _editingController,
                                              autofocus: true,
                                              focusNode: _editingFocusNode,
                                              decoration: InputDecoration(
                                                isDense: true,
                                                contentPadding: const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(16),
                                                ),
                                                filled: true,
                                                fillColor: colorScheme.surfaceContainerHighest.withAlpha(
                                                  127,
                                                ),
                                                prefixIcon: Icon(
                                                  Icons.edit_rounded,
                                                  color: colorScheme.primary,
                                                ),
                                              ),
                                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                                decoration:
                                                    sub.completed ? TextDecoration.lineThrough : null,
                                                color: sub.completed ? colorScheme.onSurfaceVariant : colorScheme.onSurface,
                                              ),
                                              onSubmitted: (_) => _saveSubtaskEditing(sub),
                                              onEditingComplete: () => _saveSubtaskEditing(sub),
                                            )
                                          : GestureDetector(
                                              onDoubleTap: () {
                                                _editingController.text = sub.text;
                                                _originalEditingText = sub.text;
                                                setState(() => _editingSubtaskId = sub.id?.toString());
                                                // request focus after frame so TextField is present
                                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                                  if (mounted) _editingFocusNode.requestFocus();
                                                });
                                              },
                                              child: Text(
                                                sub.text,
                                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                                      fontWeight: FontWeight.w600,
                                                      color: colorScheme.onSurface,
                                                    ),
                                              ),
                                            ),
                                    ),
                                    const SizedBox(width: 8),
                                    // editing action buttons (accept/cancel) like in normal subtasks
                                    if (_editingSubtaskId == sub.id?.toString()) ...[
                                      IconButton(
                                        icon: Icon(
                                          Icons.check_rounded,
                                          color: colorScheme.primary,
                                          size: 20,
                                        ),
                                        tooltip: '',
                                        onPressed: () => _saveSubtaskEditing(sub),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.close_rounded,
                                          color: colorScheme.error,
                                          size: 20,
                                        ),
                                        tooltip: '',
                                        onPressed: () {
                                          // restore original text and exit edit mode
                                          _editingController.text = sub.text;
                                          setState(() => _editingSubtaskId = null);
                                        },
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                      ),
                                    ],
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: colorScheme.surfaceContainerHigh,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.whatshot_rounded, size: 14, color: colorScheme.primary),
                                          const SizedBox(width: 6),
                                          Text(
                                            '$completedCount',
                                            style: TextStyle(color: colorScheme.onSurface),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: Icon(Icons.delete_forever_rounded, color: colorScheme.error, size: 20),
                                      tooltip: '',
                                      onPressed: () => _deleteSubtask(sub),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxHeight: 58),
                                  child: Row(
                                    children: List.generate(days.length, (dayIndex) {
                                      final day = days[dayIndex];
                                      final isToday = DateUtils.dateOnly(day) == DateUtils.dateOnly(_now.add(Duration(days: (effectiveOffset) * 7)));
                                      final completed = _isCompletedOn(id, day);
                                      final label = DateFormat('E').format(day).substring(0, 1); // single letter day
                                      return Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                          child: GestureDetector(
                                            onTap: () => _toggleCompletion(id, day),
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 180),
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: completed ? colorScheme.primary : colorScheme.surface,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: isToday ? colorScheme.primary : colorScheme.outline,
                                                  width: isToday ? 1.5 : 1,
                                                ),
                                              ),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    label,
                                                    style: TextStyle(
                                                      color: completed ? colorScheme.onPrimary : colorScheme.onSurface,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                  Text(
                                                    DateFormat('d').format(day),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: completed ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
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
                                ),
                              ],
                            ),
                          ),
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
          }),
      ],
    );
  }
}
