import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_service.dart';
import '../database/models/task.dart';
import '../database/models/subtask.dart';
import 'habits_widget.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/confirmation_dialogue.dart';

/// Panel de detalles de una tarea seleccionada
class TaskDetailsPanel extends StatefulWidget {
  final Task? selectedTask;
  final List<Subtask> subtasks;
  final List<String> selectedTaskTags;
  final DateTime? selectedDate;
  final TextEditingController nameController;
  final TextEditingController newSubtaskController;
  final TextEditingController editingController;
  final FocusNode editingFocusNode;
  final String? editingSubtaskId;
  final Set<String> expandedSubtasks;
  final TabController subtasksTabController;
  final DatabaseService databaseService;
  final VoidCallback onAddSubtask;
  final Function(Subtask) onToggleSubtask;
  final Function(Subtask) onDeleteSubtask;
  final Function(Subtask) onEditSubtask;
  final Function(Subtask) onSaveSubtaskEditing;
  final VoidCallback onCancelSubtaskEditing;
  final Function(int, int) onReorderSubtasks;
  final Function(Subtask, SubtaskPriority) onUpdateSubtaskPriority;
  final VoidCallback onToggleSortByPriority;
  final Function(String) onToggleSubtaskExpansion;
  final Future<void> Function(DateTime?) onDateChanged;
  final Future<void> Function(TaskState) onStateChanged;
  final Future<void> Function() onTogglePinned;
  final VoidCallback onTagsChanged;
  final VoidCallback onShowManageTags;
  final List<Subtask> Function() getPendingSubtasks;
  final List<Subtask> Function() getCompletedSubtasks;

  const TaskDetailsPanel({
    super.key,
    required this.selectedTask,
    required this.subtasks,
    required this.selectedTaskTags,
    required this.selectedDate,
    required this.nameController,
    required this.newSubtaskController,
    required this.editingController,
    required this.editingFocusNode,
    required this.editingSubtaskId,
    required this.expandedSubtasks,
    required this.subtasksTabController,
    required this.databaseService,
    required this.onAddSubtask,
    required this.onToggleSubtask,
    required this.onDeleteSubtask,
    required this.onEditSubtask,
    required this.onSaveSubtaskEditing,
    required this.onCancelSubtaskEditing,
    required this.onReorderSubtasks,
    required this.onUpdateSubtaskPriority,
    required this.onToggleSortByPriority,
    required this.onToggleSubtaskExpansion,
    required this.onDateChanged,
    required this.onStateChanged,
    required this.onTogglePinned,
    required this.onTagsChanged,
    required this.onShowManageTags,
    required this.getPendingSubtasks,
    required this.getCompletedSubtasks,
  });

  @override
  State<TaskDetailsPanel> createState() => _TaskDetailsPanelState();
}

class _TaskDetailsPanelState extends State<TaskDetailsPanel> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (widget.selectedTask == null) {
      return Center(
        child: Text(
          'Select a task or create a new one',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    final isHabits = widget.selectedTaskTags.contains('Habits');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header section with title and actions
        _buildHeader(colorScheme: colorScheme, isHabits: isHabits),

        const SizedBox(height: 4),

        // Subtasks list or Habits view if task has 'Habits' tag
        Expanded(
          child:
              isHabits
                  ? HabitsTracker(
                    databaseService: widget.databaseService,
                    subtasks: widget.subtasks,
                    taskId: widget.selectedTask!.id!,
                  )
                  : _buildSubtasksSection(colorScheme: colorScheme),
        ),
      ],
    );
  }

  Widget _buildHeader({
    required ColorScheme colorScheme,
    required bool isHabits,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.nameController,
                  decoration: InputDecoration(
                    hintText: 'Task title...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              // Pin button always visible in header
              _buildHeaderIconButton(
                icon:
                    widget.selectedTask!.isPinned
                        ? Icons.push_pin_rounded
                        : Icons.push_pin_outlined,
                isActive: widget.selectedTask!.isPinned,
                onTap: widget.onTogglePinned,
                colorScheme: colorScheme,
                tooltip: widget.selectedTask!.isPinned ? 'Unpin' : 'Pin',
              ),
            ],
          ),

          if (!isHabits) ...[
            // Action chips row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Date chip
                  _buildActionChip(
                    icon: Icons.calendar_today_rounded,
                    label:
                        widget.selectedDate == null
                            ? 'Add date'
                            : DateFormat(
                              'MMM d, yyyy',
                            ).format(widget.selectedDate!),
                    isActive: widget.selectedDate != null,
                    onTap: () => _selectDate(colorScheme),
                    onClear:
                        widget.selectedDate != null
                            ? () => widget.onDateChanged(null)
                            : null,
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(width: 8),

                  // Status chip
                  _buildActionChip(
                    icon: _getStateIcon(widget.selectedTask!.state),
                    label: _getStateText(widget.selectedTask!.state),
                    isActive: widget.selectedTask!.state != TaskState.none,
                    onTap: _showStatusSelectorDialog,
                    colorScheme: colorScheme,
                    activeColor: _getStateColor(
                      widget.selectedTask!.state,
                      colorScheme,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Tags chip
                  _buildActionChip(
                    icon: Icons.label_outline_rounded,
                    label:
                        widget.selectedTaskTags.isEmpty
                            ? 'Add tags'
                            : widget.selectedTaskTags.length == 1
                            ? widget.selectedTaskTags.first
                            : '${widget.selectedTaskTags.length} tags',
                    isActive: widget.selectedTaskTags.isNotEmpty,
                    onTap: _showTagSelectorDialog,
                    colorScheme: colorScheme,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // New subtask input
            _buildNewSubtaskInput(colorScheme: colorScheme),
          ],

          // Tag selector for habits
          if (isHabits) ...[
            // Tags chip for habits
            _buildActionChip(
              icon: Icons.label_outline_rounded,
              label:
                  widget.selectedTaskTags.isEmpty
                      ? 'Add tags'
                      : widget.selectedTaskTags.length == 1
                      ? widget.selectedTaskTags.first
                      : '${widget.selectedTaskTags.length} tags',
              isActive: widget.selectedTaskTags.isNotEmpty,
              onTap: _showTagSelectorDialog,
              colorScheme: colorScheme,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderIconButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(
              icon,
              size: 20,
              color:
                  isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
    VoidCallback? onClear,
    Color? activeColor,
  }) {
    final chipColor = activeColor ?? colorScheme.primary;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color:
                isActive
                    ? chipColor.withAlpha(25)
                    : colorScheme.surfaceContainerHighest.withAlpha(127),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? chipColor.withAlpha(100) : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive ? chipColor : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
                  color: isActive ? chipColor : colorScheme.onSurfaceVariant,
                ),
              ),
              if (onClear != null) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onClear,
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: chipColor.withAlpha(180),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewSubtaskInput({required ColorScheme colorScheme}) {
    final ordenarPorPrioridad = widget.selectedTask?.sortByPriority ?? false;

    return Container(
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
          // Add button
          Material(
            color: colorScheme.primaryContainer.withAlpha(80),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: widget.onAddSubtask,
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

          // Text field
          Expanded(
            child: TextField(
              controller: widget.newSubtaskController,
              decoration: InputDecoration(
                hintText: 'Add subtask...',
                hintStyle: TextStyle(
                  color: colorScheme.onSurfaceVariant.withAlpha(150),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
              onSubmitted: (_) => widget.onAddSubtask(),
            ),
          ),

          // Sort toggle button
          Tooltip(
            message: ordenarPorPrioridad ? 'Sort manually' : 'Sort by priority',
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: widget.onToggleSortByPriority,
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(
                    ordenarPorPrioridad
                        ? Icons.sort_rounded
                        : Icons.swap_vert_rounded,
                    color:
                        ordenarPorPrioridad
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtasksSection({required ColorScheme colorScheme}) {
    return Column(
      children: [
        // Subtasks tabs
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(4),
          child: SizedBox(
            height: 36,
            child: TabBar(
              controller: widget.subtasksTabController,
              tabAlignment: TabAlignment.fill,
              labelPadding: EdgeInsets.zero,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              splashFactory: NoSplash.splashFactory,
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              indicator: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pending_actions_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text('Pending', overflow: TextOverflow.ellipsis),
                      const SizedBox(width: 4),
                      Text(
                        '(${widget.getPendingSubtasks().length})',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color:
                              widget.subtasksTabController.index == 0
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text('Completed', overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
              onTap: (index) {
                setState(() {});
              },
            ),
          ),
        ),
        // Subtasks TabBarView
        Expanded(
          child: TabBarView(
            controller: widget.subtasksTabController,
            children: [
              // Pending subtasks tab
              widget.getPendingSubtasks().isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.checklist_rounded,
                          size: 48,
                          color: colorScheme.onSurfaceVariant.withAlpha(80),
                        ),
                        Text(
                          'No pending subtasks',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant.withAlpha(150),
                          ),
                        ),
                      ],
                    ),
                  )
                  : ReorderableListView.builder(
                    padding: const EdgeInsets.only(top: 4),
                    itemCount: widget.getPendingSubtasks().length,
                    buildDefaultDragHandles: false,
                    onReorder: widget.onReorderSubtasks,
                    itemBuilder: (context, index) {
                      final subtask = widget.getPendingSubtasks()[index];
                      final isEditing =
                          widget.editingSubtaskId == subtask.id.toString();
                      return _buildSubtaskItem(subtask, isEditing, colorScheme);
                    },
                  ),
              // Completed subtasks tab
              widget.getCompletedSubtasks().isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.task_alt_rounded,
                          size: 48,
                          color: colorScheme.onSurfaceVariant.withAlpha(80),
                        ),
                        Text(
                          'No completed subtasks',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant.withAlpha(150),
                          ),
                        ),
                      ],
                    ),
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.only(top: 4),
                    itemCount: widget.getCompletedSubtasks().length,
                    itemBuilder: (context, index) {
                      final subtask = widget.getCompletedSubtasks()[index];
                      final isEditing =
                          widget.editingSubtaskId == subtask.id.toString();
                      return _buildSubtaskItem(subtask, isEditing, colorScheme);
                    },
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate(ColorScheme colorScheme) async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: widget.selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (fecha != null) {
      await widget.onDateChanged(fecha);
    }
  }

  IconData _getStateIcon(TaskState state) {
    switch (state) {
      case TaskState.pending:
        return Icons.radio_button_unchecked_rounded;
      case TaskState.inProgress:
        return Icons.pending_rounded;
      case TaskState.completed:
        return Icons.check_circle_rounded;
      case TaskState.none:
        return Icons.remove_circle_outline_rounded;
    }
  }

  String _getStateText(TaskState state) {
    switch (state) {
      case TaskState.pending:
        return 'Pending';
      case TaskState.inProgress:
        return 'In progress';
      case TaskState.completed:
        return 'Completed';
      case TaskState.none:
        return 'No status';
    }
  }

  Color _getStateColor(TaskState state, ColorScheme colorScheme) {
    switch (state) {
      case TaskState.pending:
        return colorScheme.onSurfaceVariant;
      case TaskState.inProgress:
        return const Color(0xFFE67E22);
      case TaskState.completed:
        return colorScheme.primary;
      case TaskState.none:
        return colorScheme.onSurfaceVariant;
    }
  }

  Widget _buildSubtaskItem(
    Subtask subtask,
    bool isEditing,
    ColorScheme colorScheme,
  ) {
    final isCompleted = subtask.completed;
    final list =
        isCompleted
            ? widget.getCompletedSubtasks()
            : widget.getPendingSubtasks();
    final index = list.indexOf(subtask);
    final ordenarPorPrioridad = widget.selectedTask?.sortByPriority ?? false;

    return ReorderableDragStartListener(
      key: ValueKey(subtask.id!),
      index: index,
      enabled: !ordenarPorPrioridad && !isCompleted,
      child: _SubtaskItemHover(
        builder: (context, isHovering) {
          return Container(
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color:
                  isHovering
                      ? colorScheme.surfaceContainerHighest
                      : colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  // Drag handle (only for pending and manual sort)
                  if (!ordenarPorPrioridad && !isCompleted)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        color:
                            isHovering
                                ? colorScheme.onSurfaceVariant.withAlpha(150)
                                : colorScheme.onSurfaceVariant.withAlpha(80),
                        size: 18,
                      ),
                    ),

                  // Custom checkbox
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => widget.onToggleSubtask(subtask),
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color:
                              isCompleted
                                  ? colorScheme.primary
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color:
                                isCompleted
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant.withAlpha(
                                      150,
                                    ),
                            width: 1.5,
                          ),
                        ),
                        child:
                            isCompleted
                                ? Icon(
                                  Icons.check_rounded,
                                  size: 14,
                                  color: colorScheme.onPrimary,
                                )
                                : null,
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Priority indicator (only for pending)
                  if (!isCompleted &&
                      subtask.priority != SubtaskPriority.medium)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _getPriorityColor(subtask.priority),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),

                  // Title or edit field
                  Expanded(
                    child:
                        isEditing
                            ? TextField(
                              controller: widget.editingController,
                              autofocus: true,
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide(
                                    color: colorScheme.primary.withAlpha(100),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide(
                                    color: colorScheme.outlineVariant.withAlpha(
                                      100,
                                    ),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide(
                                    color: colorScheme.primary,
                                  ),
                                ),
                                filled: true,
                                fillColor: colorScheme.surface,
                              ),
                              style: TextStyle(
                                fontSize: 14,
                                color: colorScheme.onSurface,
                              ),
                              onSubmitted:
                                  (_) => widget.onSaveSubtaskEditing(subtask),
                              onEditingComplete:
                                  () => widget.onSaveSubtaskEditing(subtask),
                              onTapOutside:
                                  (_) => widget.onCancelSubtaskEditing(),
                            )
                            : GestureDetector(
                              onTap:
                                  () => widget.onToggleSubtaskExpansion(
                                    subtask.id.toString(),
                                  ),
                              onDoubleTap: () => widget.onEditSubtask(subtask),
                              child: Text(
                                subtask.text,
                                maxLines:
                                    widget.expandedSubtasks.contains(
                                          subtask.id.toString(),
                                        )
                                        ? null
                                        : 1,
                                overflow:
                                    widget.expandedSubtasks.contains(
                                          subtask.id.toString(),
                                        )
                                        ? TextOverflow.visible
                                        : TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  decoration:
                                      isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                  color:
                                      isCompleted
                                          ? colorScheme.onSurfaceVariant
                                          : colorScheme.onSurface,
                                ),
                              ),
                            ),
                  ),

                  // Action buttons (always present to maintain size, opacity controls visibility)
                  if (isEditing) ...[
                    _buildSubtaskActionButton(
                      icon: Icons.check_rounded,
                      color: colorScheme.primary,
                      onTap: () => widget.onSaveSubtaskEditing(subtask),
                      colorScheme: colorScheme,
                    ),
                    _buildSubtaskActionButton(
                      icon: Icons.close_rounded,
                      color: colorScheme.error,
                      onTap: widget.onCancelSubtaskEditing,
                      colorScheme: colorScheme,
                    ),
                  ] else ...[
                    // Priority button (only for pending)
                    if (!isCompleted)
                      Opacity(
                        opacity: isHovering ? 1.0 : 0.0,
                        child: IgnorePointer(
                          ignoring: !isHovering,
                          child: _buildSubtaskActionButton(
                            icon: _getPriorityIcon(subtask.priority),
                            color: _getPriorityColor(subtask.priority),
                            onTap: () => _showPrioritySelectorDialog(subtask),
                            colorScheme: colorScheme,
                          ),
                        ),
                      ),
                    // Edit button
                    Opacity(
                      opacity: isHovering ? 1.0 : 0.0,
                      child: IgnorePointer(
                        ignoring: !isHovering,
                        child: _buildSubtaskActionButton(
                          icon: Icons.edit_rounded,
                          color: colorScheme.onSurfaceVariant,
                          onTap: () => widget.onEditSubtask(subtask),
                          colorScheme: colorScheme,
                        ),
                      ),
                    ),
                    // Delete button
                    Opacity(
                      opacity: isHovering ? 1.0 : 0.0,
                      child: IgnorePointer(
                        ignoring: !isHovering,
                        child: _buildSubtaskActionButton(
                          icon: Icons.delete_outline_rounded,
                          color: colorScheme.error.withAlpha(180),
                          onTap: () => widget.onDeleteSubtask(subtask),
                          colorScheme: colorScheme,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSubtaskActionButton({
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
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }

  IconData _getPriorityIcon(SubtaskPriority priority) {
    switch (priority) {
      case SubtaskPriority.high:
        return Icons.arrow_upward_rounded;
      case SubtaskPriority.medium:
        return Icons.remove_rounded;
      case SubtaskPriority.low:
        return Icons.arrow_downward_rounded;
    }
  }

  Color _getPriorityColor(SubtaskPriority priority) {
    switch (priority) {
      case SubtaskPriority.high:
        return Theme.of(context).colorScheme.error;
      case SubtaskPriority.medium:
        return Theme.of(context).colorScheme.primary;
      case SubtaskPriority.low:
        return Theme.of(context).colorScheme.tertiary;
    }
  }

  void _showStatusSelectorDialog() {
    showDialog(
      context: context,
      builder:
          (context) => StatusSelectorDialog(
            selectedState: widget.selectedTask!.state,
            onStateSelected: (state) {
              widget.onStateChanged(state);
              Navigator.pop(context);
            },
          ),
    );
  }

  void _showTagSelectorDialog() {
    showDialog(
      context: context,
      builder:
          (context) => TagSelectorDialog(
            databaseService: widget.databaseService,
            selectedTask: widget.selectedTask!,
            onTagsChanged: widget.onTagsChanged,
          ),
    );
  }

  void _showPrioritySelectorDialog(Subtask subtask) {
    showDialog(
      context: context,
      builder:
          (context) => PrioritySelectorDialog(
            selectedPriority: subtask.priority,
            onPrioritySelected: (priority) {
              widget.onUpdateSubtaskPriority(subtask, priority);
              Navigator.pop(context);
            },
          ),
    );
  }
}

// Widget auxiliar para gestionar el estado de hover
class MouseRegionHoverItem extends StatefulWidget {
  final Widget Function(BuildContext, bool) builder;

  const MouseRegionHoverItem({super.key, required this.builder});

  @override
  State<MouseRegionHoverItem> createState() => _MouseRegionHoverItemState();
}

class _MouseRegionHoverItemState extends State<MouseRegionHoverItem> {
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

// Widget auxiliar para gestionar el estado de hover en subtasks
class _SubtaskItemHover extends StatefulWidget {
  final Widget Function(BuildContext, bool) builder;

  const _SubtaskItemHover({required this.builder});

  @override
  State<_SubtaskItemHover> createState() => _SubtaskItemHoverState();
}

class _SubtaskItemHoverState extends State<_SubtaskItemHover> {
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

// Diálogo para gestionar tags globales
class TagsManagerDialog extends StatefulWidget {
  final DatabaseService databaseService;
  final VoidCallback onTagsChanged;

  const TagsManagerDialog({
    super.key,
    required this.databaseService,
    required this.onTagsChanged,
  });

  @override
  State<TagsManagerDialog> createState() => _TagsManagerDialogState();
}

class _TagsManagerDialogState extends State<TagsManagerDialog> {
  final TextEditingController _newTagController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  List<String> _tags = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  @override
  void dispose() {
    _newTagController.dispose();
    super.dispose();
  }

  Future<void> _loadTags() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final tags = await widget.databaseService.taskService.getAllTags();
      setState(() {
        _tags = tags;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error loading tags: $e',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  Future<void> _addNewTag() async {
    if (_formKey.currentState!.validate()) {
      final newTag = _newTagController.text.trim();

      if (_tags.contains(newTag)) {
        if (mounted) {
          CustomSnackbar.show(
            context: context,
            message: 'This tag already exists',
            type: CustomSnackbarType.error,
          );
        }
        return;
      }

      try {
        await widget.databaseService.taskService.addTag(newTag);
        _newTagController.clear();
        await _loadTags();
        widget.onTagsChanged();
      } catch (e) {
        if (mounted) {
          CustomSnackbar.show(
            context: context,
            message: 'Error adding tag: $e',
            type: CustomSnackbarType.error,
          );
        }
      }
    }
  }

  Future<void> _deleteTag(String tag) async {
    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await showDeleteConfirmationDialog(
      context: context,
      title: 'Delete Tag',
      message:
          'Are you sure you want to delete the tag "$tag"? This action cannot be undone.',
      confirmText: 'Delete',
      confirmColor: colorScheme.error,
    );

    if (confirmed == true) {
      try {
        await widget.databaseService.taskService.deleteTag(tag);
        await _loadTags();
        widget.onTagsChanged();
      } catch (e) {
        if (mounted) {
          CustomSnackbar.show(
            context: context,
            message: 'Error deleting tag: $e',
            type: CustomSnackbarType.error,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 500,
          height: 400,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.label_rounded, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Text(
                      'Tags',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: colorScheme.onSurface,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _newTagController,
                          decoration: InputDecoration(
                            labelText: 'New tag',
                            hintText: 'Enter tag name',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHighest
                                .withAlpha(127),
                            prefixIcon: Icon(
                              Icons.title_rounded,
                              color: colorScheme.primary,
                            ),
                          ),
                          validator:
                              (value) =>
                                  value?.isEmpty ?? true ? 'Required' : null,
                          onFieldSubmitted: (_) => _addNewTag(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        onPressed: _addNewTag,
                        icon: const Icon(Icons.add_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _tags.isEmpty
                        ? Center(
                          child: Text(
                            'No tags available',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                        : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _tags.length,
                          itemBuilder: (context, index) {
                            final tag = _tags[index];
                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: colorScheme.outlineVariant.withAlpha(
                                    127,
                                  ),
                                  width: 0.5,
                                ),
                              ),
                              child: ListTile(
                                leading: Icon(
                                  Icons.label_rounded,
                                  color: colorScheme.primary,
                                  size: 20,
                                ),
                                title: Text(tag),
                                trailing: IconButton(
                                  icon: Icon(
                                    Icons.delete_forever_rounded,
                                    color: colorScheme.error,
                                    size: 20,
                                  ),
                                  onPressed: () => _deleteTag(tag),
                                ),
                              ),
                            );
                          },
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Diálogo para seleccionar tags para una tarea
class TagSelectorDialog extends StatefulWidget {
  final DatabaseService databaseService;
  final Task selectedTask;
  final VoidCallback onTagsChanged;

  const TagSelectorDialog({
    super.key,
    required this.databaseService,
    required this.selectedTask,
    required this.onTagsChanged,
  });

  @override
  State<TagSelectorDialog> createState() => _TagSelectorDialogState();
}

class _TagSelectorDialogState extends State<TagSelectorDialog> {
  final TextEditingController _newTagController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  List<String> _allTags = [];
  List<String> _selectedTags = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  @override
  void dispose() {
    _newTagController.dispose();
    super.dispose();
  }

  Future<void> _loadTags() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final allTags = await widget.databaseService.taskService.getAllTags();
      final taskTags = await widget.databaseService.taskService.getTagsByTaskId(
        widget.selectedTask.id!,
      );

      setState(() {
        _allTags = allTags;
        _selectedTags = taskTags;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error loading tags: $e',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  Future<void> _addNewTag() async {
    if (_formKey.currentState!.validate()) {
      final newTag = _newTagController.text.trim();

      if (_allTags.contains(newTag)) {
        if (mounted) {
          CustomSnackbar.show(
            context: context,
            message: 'This tag already exists',
            type: CustomSnackbarType.error,
          );
        }
        return;
      }

      try {
        await widget.databaseService.taskService.addTag(newTag);
        _newTagController.clear();
        await _loadTags();
        widget.onTagsChanged();
      } catch (e) {
        if (mounted) {
          CustomSnackbar.show(
            context: context,
            message: 'Error adding tag: $e',
            type: CustomSnackbarType.error,
          );
        }
      }
    }
  }

  Future<void> _toggleTag(String tag) async {
    try {
      if (_selectedTags.contains(tag)) {
        await widget.databaseService.taskService.removeTagFromTask(
          tag,
          widget.selectedTask.id!,
        );
      } else {
        await widget.databaseService.taskService.assignTagToTask(
          tag,
          widget.selectedTask.id!,
        );
      }
      await _loadTags();
      widget.onTagsChanged();
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error updating tag: $e',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 500,
          height: 400,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.label_rounded, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Text(
                      'Select Tags',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: colorScheme.onSurface,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _newTagController,
                          decoration: InputDecoration(
                            labelText: 'New tag',
                            hintText: 'Enter tag name',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHighest
                                .withAlpha(127),
                            prefixIcon: Icon(
                              Icons.title_rounded,
                              color: colorScheme.primary,
                            ),
                          ),
                          validator:
                              (value) =>
                                  value?.isEmpty ?? true ? 'Required' : null,
                          onFieldSubmitted: (_) => _addNewTag(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        onPressed: _addNewTag,
                        icon: const Icon(Icons.add_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _allTags.isEmpty
                        ? Center(
                          child: Text(
                            'No tags available',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                        : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _allTags.length,
                          itemBuilder: (context, index) {
                            final tag = _allTags[index];
                            final isSelected = _selectedTags.contains(tag);
                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: colorScheme.outlineVariant.withAlpha(
                                    127,
                                  ),
                                  width: 0.5,
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _toggleTag(tag),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    height: 48,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isSelected
                                              ? Icons.check_circle_rounded
                                              : Icons.circle_outlined,
                                          color:
                                              isSelected
                                                  ? colorScheme.primary
                                                  : colorScheme
                                                      .onSurfaceVariant,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 16),
                                        Text(
                                          tag,
                                          style:
                                              Theme.of(
                                                context,
                                              ).textTheme.bodyLarge,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Diálogo para seleccionar estado de tarea
class StatusSelectorDialog extends StatelessWidget {
  final TaskState selectedState;
  final Function(TaskState) onStateSelected;

  const StatusSelectorDialog({
    super.key,
    required this.selectedState,
    required this.onStateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 300,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.pending_actions_rounded,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Select Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: colorScheme.onSurface,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStatusOption(
                      context,
                      TaskState.none,
                      Icons.remove_circle_outline,
                      colorScheme.onSurfaceVariant,
                      'No status',
                    ),
                    const SizedBox(height: 8),
                    _buildStatusOption(
                      context,
                      TaskState.pending,
                      Icons.circle_outlined,
                      colorScheme.onSurfaceVariant,
                      'Pending',
                    ),
                    const SizedBox(height: 8),
                    _buildStatusOption(
                      context,
                      TaskState.inProgress,
                      Icons.pending_rounded,
                      const Color(0xFFB75D0A),
                      'In progress',
                    ),
                    const SizedBox(height: 8),
                    _buildStatusOption(
                      context,
                      TaskState.completed,
                      Icons.check_circle_rounded,
                      colorScheme.primary,
                      'Completed',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusOption(
    BuildContext context,
    TaskState state,
    IconData icon,
    Color color,
    String text,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = state == selectedState;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onStateSelected(state),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 16),
              Text(
                text,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color:
                      isSelected ? colorScheme.primary : colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              if (isSelected)
                Icon(Icons.check_rounded, color: colorScheme.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// Diálogo para seleccionar prioridad de subtarea
class PrioritySelectorDialog extends StatelessWidget {
  final SubtaskPriority selectedPriority;
  final Function(SubtaskPriority) onPrioritySelected;

  const PrioritySelectorDialog({
    super.key,
    required this.selectedPriority,
    required this.onPrioritySelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 300,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.priority_high_rounded,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Select Priority',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: colorScheme.onSurface,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPriorityOption(
                      context,
                      SubtaskPriority.high,
                      Icons.arrow_upward_rounded,
                      colorScheme.error,
                      'High',
                    ),
                    const SizedBox(height: 8),
                    _buildPriorityOption(
                      context,
                      SubtaskPriority.medium,
                      Icons.remove_rounded,
                      colorScheme.primary,
                      'Medium',
                    ),
                    const SizedBox(height: 8),
                    _buildPriorityOption(
                      context,
                      SubtaskPriority.low,
                      Icons.arrow_downward_rounded,
                      colorScheme.tertiary,
                      'Low',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityOption(
    BuildContext context,
    SubtaskPriority priority,
    IconData icon,
    Color color,
    String text,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = priority == selectedPriority;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onPrioritySelected(priority),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 16),
              Text(
                text,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color:
                      isSelected ? colorScheme.primary : colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              if (isSelected)
                Icon(Icons.check_rounded, color: colorScheme.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
