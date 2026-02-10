import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../database/models/calendar_event.dart';
import '../../database/models/calendar_event_status.dart';
import '../../database/models/note.dart';
import '../../database/models/task.dart';
import '../../database/repositories/calendar_event_repository.dart';
import '../../database/repositories/calendar_event_status_repository.dart';
import '../../database/repositories/note_repository.dart';
import '../../database/database_helper.dart';
import '../../services/notification_service.dart';
import '../../widgets/custom_snackbar.dart';
import '../widgets/note_editor.dart';
import 'calendar_event_status_screen.dart';
import 'task_detail_screen.dart';
import '../../database/database_service.dart';
import '../../widgets/custom_date_picker_dialog.dart';

class CalendarScreen extends StatefulWidget {
  final Function(Note) onNoteSelected;

  const CalendarScreen({super.key, required this.onNoteSelected});

  @override
  State<CalendarScreen> createState() => CalendarScreenState();
}

class CalendarScreenState extends State<CalendarScreen> {
  static const String _calendarExpandedKey = 'calendar_expanded';
  static const String _showCombinedEventsKey =
      'calendar_mobile_show_combined_events';
  final DatabaseService _databaseService = DatabaseService();
  late CalendarEventRepository _calendarEventRepository;
  late CalendarEventStatusRepository _statusRepository;
  late DateTime _selectedMonth;
  late DateTime _selectedDate;
  List<CalendarEvent> _events = [];
  List<CalendarEventStatus> _statuses = [];
  List<Task> _tasksWithDeadlines = [];
  bool _isLoading = true;
  bool _isExpanded = true;
  bool _showCombinedEvents = false;
  bool _isInitialized = false;
  late StreamSubscription<Note> _noteUpdateSubscription;
  StreamSubscription? _dbSubscription;
  StreamSubscription? _dbHelperSubscription;
  bool _isUpdatingManually = false;
  bool _isShowingUnassigned = false;
  List<CalendarEvent> _unassignedEvents = [];
  List<Task> _unassignedTasks = [];

  @override
  void initState() {
    super.initState();
    _calendarEventRepository = CalendarEventRepository(DatabaseHelper());
    _statusRepository = CalendarEventStatusRepository(DatabaseHelper());
    _selectedMonth = DateTime.now();
    _selectedDate = DateTime.now();
    _loadCalendarState();
    _noteUpdateSubscription = NotificationService().noteUpdateStream.listen(
      _handleNoteUpdate,
    );
    _setupDatabaseListener();
    _loadEvents();
    _loadStatuses();
    _loadUnassignedItems();
  }

  Future<void> _loadCalendarState() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isExpanded = prefs.getBool(_calendarExpandedKey) ?? true;
        _showCombinedEvents = prefs.getBool(_showCombinedEventsKey) ?? false;
        _isInitialized = true;
      });
      if (_showCombinedEvents) {
        _loadTasksWithDeadlines();
      }
    }
  }

  Future<void> _saveCalendarState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_calendarExpandedKey, _isExpanded);
    await prefs.setBool(_showCombinedEventsKey, _showCombinedEvents);
  }

  @override
  void dispose() {
    _noteUpdateSubscription.cancel();
    _dbSubscription?.cancel();
    _dbHelperSubscription?.cancel();
    super.dispose();
  }

  void _handleNoteUpdate(Note updatedNote) {
    setState(() {
      _events =
          _events.map((event) {
            if (event.note?.id == updatedNote.id) {
              return event.copyWith(note: updatedNote);
            }
            return event;
          }).toList();
    });
  }

  void _setupDatabaseListener() {
    _dbSubscription?.cancel();
    _dbHelperSubscription?.cancel();

    _dbSubscription = DatabaseService().onDatabaseChanged.listen((_) {
      if (!_isUpdatingManually && mounted) {
        _loadEvents();
        _loadUnassignedItems();
        if (_showCombinedEvents) {
          _loadTasksWithDeadlines();
        }
      }
    });

    _dbHelperSubscription = DatabaseHelper.onDatabaseChanged.listen((_) {
      if (!_isUpdatingManually && mounted) {
        _loadEvents();
        _loadUnassignedItems();
        if (_showCombinedEvents) {
          _loadTasksWithDeadlines();
        }
      }
    });
  }

  Future<void> _loadEvents() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final events = await _calendarEventRepository.getCalendarEventsByMonth(
        _selectedMonth,
      );
      final previousMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month - 1,
        1,
      );
      final nextMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        1,
      );
      final previousEvents = await _calendarEventRepository
          .getCalendarEventsByMonth(previousMonth);
      final nextEvents = await _calendarEventRepository
          .getCalendarEventsByMonth(nextMonth);
      if (mounted) {
        setState(() {
          _events = [...previousEvents, ...events, ...nextEvents];
          _isLoading = false;
        });
        if (_showCombinedEvents) {
          _loadTasksWithDeadlines();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadStatuses() async {
    if (!mounted) return;

    try {
      final statuses = await _statusRepository.getAllStatuses();
      if (mounted) {
        setState(() {
          _statuses = statuses;
        });
      }

      if (statuses.isEmpty) {
        await _initializeDefaultStatuses();
      }
    } catch (e) {
      // Ignore errors when loading statuses
    }
  }

  Future<void> _initializeDefaultStatuses() async {
    final defaultStatuses = [
      CalendarEventStatus(
        id: 0,
        name: 'To Write',
        color: '#FFB77D', // Orange pastel
        orderIndex: 0,
      ),
      CalendarEventStatus(
        id: 0,
        name: 'To Record',
        color: '#90CAF9', // Blue pastel
        orderIndex: 1,
      ),
      CalendarEventStatus(
        id: 0,
        name: 'In Progress',
        color: '#CE93D8', // Purple pastel
        orderIndex: 2,
      ),
      CalendarEventStatus(
        id: 0,
        name: 'Completed',
        color: '#A5D6A7', // Green pastel
        orderIndex: 3,
      ),
    ];

    for (final status in defaultStatuses) {
      try {
        await _statusRepository.createStatus(status);
      } catch (e) {
        // Ignore if status already exists
      }
    }

    await _loadStatuses();
  }

  void _toggleCalendar() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    _saveCalendarState();
  }

  void _toggleCombinedEvents() {
    setState(() {
      _showCombinedEvents = !_showCombinedEvents;
    });
    _saveCalendarState();
    if (_showCombinedEvents) {
      _loadTasksWithDeadlines();
    }
  }

  Future<void> _loadTasksWithDeadlines() async {
    if (!mounted) return;

    try {
      final tasksWithDates =
          await DatabaseService().taskService.getTasksWithDeadlines();
      if (mounted) {
        setState(() {
          _tasksWithDeadlines = tasksWithDates;
        });
      }
    } catch (e) {
      print('Error loading tasks with deadlines: $e');
    }
  }

  Future<void> _loadUnassignedItems() async {
    if (!mounted) return;
    try {
      final unassignedEvents =
          await _calendarEventRepository.getUnassignedCalendarEvents();
      final unassignedTasks =
          await _databaseService.taskService.getUnassignedTasks();
      if (mounted) {
        setState(() {
          _unassignedEvents = unassignedEvents;
          _unassignedTasks = unassignedTasks;
        });
      }
    } catch (e) {
      print('Error loading unassigned items: $e');
    }
  }

  void _goToPreviousMonth() {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month - 1,
        1,
      );
    });
    _loadEvents();
  }

  void _goToNextMonth() {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        1,
      );
    });
    _loadEvents();
  }

  void _goToCurrentMonth() {
    setState(() {
      _selectedMonth = DateTime.now();
      _selectedDate = DateTime.now();
    });
    _loadEvents();
  }

  String get _formattedMonth {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[_selectedMonth.month - 1]} ${_selectedMonth.year}';
  }

  Future<void> _handleNoteDrop(Note note, int day) async {
    if (note.id == null) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Cannot add unsaved note to calendar',
          type: CustomSnackbarType.error,
        );
      }
      return;
    }

    try {
      final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
      final existingEvent = _events.firstWhere(
        (event) => event.noteId == note.id && event.date.isAtSameMomentAs(date),
        orElse:
            () => CalendarEvent(id: 0, noteId: 0, date: date, orderIndex: 0),
      );

      if (existingEvent.id != 0) {
        if (mounted) {
          CustomSnackbar.show(
            context: context,
            message: 'This note is already assigned to this day',
            type: CustomSnackbarType.error,
          );
        }
        return;
      }

      final nextOrderIndex = await _calendarEventRepository.getNextOrderIndex();
      final event = CalendarEvent(
        id: 0,
        noteId: note.id!,
        date: date,
        orderIndex: nextOrderIndex,
      );

      _isUpdatingManually = true;
      await _calendarEventRepository.createCalendarEvent(event);
      DatabaseService().notifyDatabaseChanged();
      await _loadEvents();
      await _loadUnassignedItems();
      _isUpdatingManually = false;
    } catch (e) {
      print('Error adding note to calendar: $e');
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error adding note to calendar: $e',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  Future<void> _deleteEvent(CalendarEvent event) async {
    try {
      _isUpdatingManually = true;
      await _calendarEventRepository.deleteCalendarEvent(event.id);
      DatabaseService().notifyDatabaseChanged();
      await _loadEvents();
      await _loadUnassignedItems();
      _isUpdatingManually = false;
    } catch (e) {
      _isUpdatingManually = false;
      print('Error removing note from calendar: $e');
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error removing note from calendar: $e',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  Future<void> _clearTaskDate(Task task) async {
    try {
      _isUpdatingManually = true;
      await _databaseService.taskService.updateTaskDate(task.id!, null);
      DatabaseService().notifyDatabaseChanged();
      await _loadTasksWithDeadlines();
      await _loadUnassignedItems();
      _isUpdatingManually = false;
    } catch (e) {
      _isUpdatingManually = false;
      print('Error clearing task date: $e');
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error removing task from calendar: $e',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  Future<void> _updateEventStatus(
    CalendarEvent event,
    String? statusName,
  ) async {
    try {
      _isUpdatingManually = true;
      CalendarEvent updatedEvent;
      if (statusName == null) {
        updatedEvent = event.copyWith(clearStatus: true);
      } else {
        updatedEvent = event.copyWith(status: statusName);
      }
      await _calendarEventRepository.updateCalendarEvent(updatedEvent);
      DatabaseService().notifyDatabaseChanged();
      await _loadEvents();
      await _loadUnassignedItems();
      _isUpdatingManually = false;
    } catch (e) {
      _isUpdatingManually = false;
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error updating event label: $e',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  void _showEventContextMenu(CalendarEvent event) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      isScrollControlled: true,
      builder:
          (context) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom,
            ),
            child: Container(
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withAlpha(50),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _showStatusMenu(event);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.label_outline_rounded,
                              size: 20,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            const Text('Assign labels'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _moveEventToDate(event);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 20,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            const Text('Move event'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _moveEventToDate(CalendarEvent event) async {
    final eventDates = _events.map((e) => e.date).toList();
    final selectedDate = await showDialog<DateTime>(
      context: context,
      builder:
          (context) => CustomDatePickerDialog(
            initialDate: event.date,
            eventDates: eventDates,
          ),
    );

    if (selectedDate != null && !selectedDate.isAtSameMomentAs(event.date)) {
      try {
        _isUpdatingManually = true;
        final updatedEvent = event.copyWith(date: selectedDate);
        await _calendarEventRepository.updateCalendarEvent(updatedEvent);
        DatabaseService().notifyDatabaseChanged();

        await _loadEvents();
        _isUpdatingManually = false;

        if (mounted) {
          CustomSnackbar.show(
            context: context,
            message:
                'Event moved to ${DateFormat('MMMM d, y').format(selectedDate)}',
            type: CustomSnackbarType.success,
          );
        }
      } catch (e) {
        _isUpdatingManually = false;
        print('Error moving event: $e');
        if (mounted) {
          CustomSnackbar.show(
            context: context,
            message: 'Error moving event',
            type: CustomSnackbarType.error,
          );
        }
      }
    }
  }

  void _showStatusMenu(CalendarEvent event) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      isScrollControlled: true,
      builder: (context) {
        final bottomPadding = MediaQuery.of(context).padding.bottom;
        final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Padding(
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
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ..._statuses.map(
                          (status) => Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
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
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  _updateEventStatus(event, status.name);
                                  Navigator.pop(context);
                                },
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  leading: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: _parseColor(status.color),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  title: Text(
                                    status.name,
                                    style: TextStyle(
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: colorScheme.outlineVariant.withAlpha(127),
                              width: 0.5,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                _updateEventStatus(event, null);
                                Navigator.pop(context);
                              },
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                leading: Icon(
                                  Icons.clear,
                                  color: colorScheme.outline,
                                ),
                                title: Text(
                                  'No Label',
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> showStatusManager() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CalendarEventStatusScreen(),
      ),
    );
    await _loadStatuses();
  }

  Color _parseColor(String colorString) {
    try {
      if (colorString.startsWith('#')) {
        return Color(
          int.parse(colorString.substring(1), radix: 16) + 0xFF000000,
        );
      }
      return Colors.blue;
    } catch (e) {
      return Colors.blue;
    }
  }

  Color _getStatusColor(String statusName) {
    final status = _statuses.firstWhere(
      (s) => s.name == statusName,
      orElse:
          () => CalendarEventStatus(
            id: 0,
            name: statusName,
            color: '#2196F3',
            orderIndex: 0,
          ),
    );
    return _parseColor(status.color);
  }

  void _openNoteEditor(Note note) {
    final editorTitleController = TextEditingController(text: note.title);
    final editorContentController = TextEditingController(text: note.content);
    final editorFocusNode = FocusNode();

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder:
                (context) => NoteEditor(
                  selectedNote: note,
                  titleController: editorTitleController,
                  contentController: editorContentController,
                  contentFocusNode: editorFocusNode,
                  isEditing: true,
                  isImmersiveMode: false,
                  onSave: () async {
                    try {
                      final dbHelper = DatabaseHelper();
                      final noteRepository = NoteRepository(dbHelper);

                      final updatedNote = Note(
                        id: note.id,
                        title: editorTitleController.text.trim(),
                        content: editorContentController.text,
                        notebookId: note.notebookId,
                        createdAt: note.createdAt,
                        updatedAt: DateTime.now(),
                        isFavorite: note.isFavorite,
                        tags: note.tags,
                        orderIndex: note.orderIndex,
                        isTask: note.isTask,
                        isCompleted: note.isCompleted,
                      );

                      final result = await noteRepository.updateNote(
                        updatedNote,
                      );
                      if (result > 0) {
                        DatabaseHelper.notifyDatabaseChanged();
                      }
                    } catch (e) {
                      debugPrint('Error saving note: $e');
                      if (mounted) {
                        CustomSnackbar.show(
                          context: context,
                          message: 'Error saving note: ${e.toString()}',
                          type: CustomSnackbarType.error,
                        );
                      }
                    }
                  },
                  onToggleEditing: () {},
                  onTitleChanged: () {},
                  onContentChanged: () {},
                  onToggleImmersiveMode: (bool isImmersive) {},
                ),
          ),
        )
        .then((_) {});
  }

  Widget _buildWeekView() {
    final colorScheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final firstDayOfWeek = today.subtract(Duration(days: today.weekday - 1));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _formattedMonth,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSurface,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: _isExpanded ? _goToPreviousMonth : null,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  TextButton(
                    onPressed: _goToCurrentMonth,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(40, 32),
                    ),
                    child: const Text('Today'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: _isExpanded ? _goToNextMonth : null,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  IconButton(
                    icon: Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                    ),
                    onPressed: _toggleCalendar,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: List.generate(7, (index) {
                final date = firstDayOfWeek.add(Duration(days: index));
                final isSelected =
                    date.year == _selectedDate.year &&
                    date.month == _selectedDate.month &&
                    date.day == _selectedDate.day;

                final hasEvents = _events.any(
                  (event) =>
                      event.date.year == date.year &&
                      event.date.month == date.month &&
                      event.date.day == date.day,
                );

                final hasTasks =
                    _showCombinedEvents &&
                    _tasksWithDeadlines.any(
                      (task) =>
                          task.date?.year == date.year &&
                          task.date?.month == date.month &&
                          task.date?.day == date.day,
                    );

                final showDot = hasEvents || hasTasks;

                return Expanded(
                  child: DragTarget<Note>(
                    onWillAcceptWithDetails:
                        (details) => details.data.id != null,
                    onAcceptWithDetails:
                        (details) => _handleNoteDrop(details.data, date.day),
                    builder: (context, candidateData, rejectedData) {
                      return Container(
                        margin: const EdgeInsets.only(
                          left: 2,
                          right: 2,
                          top: 2,
                          bottom: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isSelected
                                  ? colorScheme.primaryContainer
                                  : candidateData.isNotEmpty
                                  ? colorScheme.primaryContainer.withAlpha(50)
                                  : null,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedDate = date;
                                if (date.month != _selectedMonth.month ||
                                    date.year != _selectedMonth.year) {
                                  _selectedMonth = DateTime(
                                    date.year,
                                    date.month,
                                    1,
                                  );
                                }
                              });
                              _loadEvents();
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    [
                                      'Mon',
                                      'Tue',
                                      'Wed',
                                      'Thu',
                                      'Fri',
                                      'Sat',
                                      'Sun',
                                    ][index],
                                    style: TextStyle(
                                      color:
                                          isSelected
                                              ? colorScheme.onPrimaryContainer
                                              : colorScheme.onSurfaceVariant,
                                      fontSize: 10,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    date.day.toString(),
                                    style: TextStyle(
                                      color:
                                          isSelected
                                              ? colorScheme.onPrimaryContainer
                                              : colorScheme.onSurface,
                                      fontWeight:
                                          isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                      fontSize: isSelected ? 14 : 12,
                                    ),
                                  ),
                                  if (showDot)
                                    Container(
                                      width: 3,
                                      height: 3,
                                      margin: const EdgeInsets.only(top: 1),
                                      decoration: BoxDecoration(
                                        color:
                                            isSelected
                                                ? colorScheme.onPrimaryContainer
                                                : colorScheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        SizedBox(
          height:
              _isExpanded
                  ? 400
                  : max(100.0, MediaQuery.of(context).size.height * 0.13),
          child: _isExpanded ? _buildExpandedCalendar() : _buildWeekView(),
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(color: colorScheme.surfaceContainer),
            child: _buildEventsPanel(),
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedCalendar() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _formattedMonth,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSurface,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: _goToPreviousMonth,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  TextButton(
                    onPressed: _goToCurrentMonth,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(40, 32),
                    ),
                    child: const Text('Today'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: _goToNextMonth,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  IconButton(
                    icon: Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                    ),
                    onPressed: _toggleCalendar,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child:
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildCalendarGrid(),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid() {
    final colorScheme = Theme.of(context).colorScheme;
    final firstDayOfMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month,
      1,
    );
    final lastDayOfMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
    );
    final firstWeekday = firstDayOfMonth.weekday;
    final daysInMonth = lastDayOfMonth.day;

    final List<Widget> calendarRows = [];
    int currentDay = 1;

    while (currentDay <= daysInMonth) {
      final List<Widget> rowChildren = [];

      for (int i = 1; i <= 7; i++) {
        if (currentDay == 1 && i < firstWeekday) {
          rowChildren.add(const Expanded(child: SizedBox()));
        } else if (currentDay <= daysInMonth) {
          final day = currentDay;
          final isSelected =
              day == _selectedDate.day &&
              _selectedMonth.month == _selectedDate.month &&
              _selectedMonth.year == _selectedDate.year;

          final hasEvents = _events.any(
            (event) =>
                event.date.year == _selectedMonth.year &&
                event.date.month == _selectedMonth.month &&
                event.date.day == day,
          );

          final hasTasks =
              _showCombinedEvents &&
              _tasksWithDeadlines.any(
                (task) =>
                    task.date?.year == _selectedMonth.year &&
                    task.date?.month == _selectedMonth.month &&
                    task.date?.day == day,
              );

          final showDot = hasEvents || hasTasks;

          rowChildren.add(
            Expanded(
              child: DragTarget<Note>(
                onWillAcceptWithDetails: (details) => details.data.id != null,
                onAcceptWithDetails:
                    (details) => _handleNoteDrop(details.data, day),
                builder: (context, candidateData, rejectedData) {
                  return AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? colorScheme.primaryContainer
                                : candidateData.isNotEmpty
                                ? colorScheme.primaryContainer.withAlpha(50)
                                : null,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedDate = DateTime(
                                _selectedMonth.year,
                                _selectedMonth.month,
                                day,
                              );
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            children: [
                              Center(
                                child: Text(
                                  day.toString(),
                                  style: TextStyle(
                                    color:
                                        isSelected
                                            ? colorScheme.onPrimaryContainer
                                            : colorScheme.onSurface,
                                    fontWeight:
                                        isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                    fontSize: isSelected ? 18 : 16,
                                  ),
                                ),
                              ),
                              if (showDot)
                                Positioned(
                                  bottom: 4,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: Container(
                                      width: 5,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color:
                                            isSelected
                                                ? colorScheme.onPrimaryContainer
                                                : colorScheme.primary,
                                        shape: BoxShape.circle,
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
              ),
            ),
          );
          currentDay++;
        } else {
          rowChildren.add(const Expanded(child: SizedBox()));
        }
      }

      calendarRows.add(Expanded(child: Row(children: rowChildren)));
    }

    return Column(
      children: [
        SizedBox(
          height: 32,
          child: Row(
            children:
                ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                    .map(
                      (day) => Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
          ),
        ),
        ...calendarRows,
      ],
    );
  }

  Widget _buildEventsPanel() {
    final colorScheme = Theme.of(context).colorScheme;

    final eventsForSelectedDay =
        _events
            .where(
              (event) =>
                  event.date.year == _selectedDate.year &&
                  event.date.month == _selectedDate.month &&
                  event.date.day == _selectedDate.day,
            )
            .toList();

    eventsForSelectedDay.sort((a, b) {
      if (a.status != null && b.status != null) {
        final statusA = _statuses.firstWhere(
          (s) => s.name == a.status,
          orElse:
              () => CalendarEventStatus(
                id: 0,
                name: a.status!,
                color: '#2196F3',
                orderIndex: 999,
              ),
        );
        final statusB = _statuses.firstWhere(
          (s) => s.name == b.status,
          orElse:
              () => CalendarEventStatus(
                id: 0,
                name: b.status!,
                color: '#2196F3',
                orderIndex: 999,
              ),
        );
        return statusA.orderIndex.compareTo(statusB.orderIndex);
      }
      if (a.status == null && b.status != null) return 1;
      if (a.status != null && b.status == null) return -1;
      return 0;
    });

    final tasksForSelectedDay =
        _tasksWithDeadlines.where((task) {
          if (task.date == null) return false;
          return task.date!.year == _selectedDate.year &&
              task.date!.month == _selectedDate.month &&
              task.date!.day == _selectedDate.day;
        }).toList();

    tasksForSelectedDay.sort((a, b) {
      if (a.completed && !b.completed) return 1;
      if (!a.completed && b.completed) return -1;
      if (a.state == TaskState.inProgress && b.state != TaskState.inProgress) {
        return -1;
      }
      if (a.state != TaskState.inProgress && b.state == TaskState.inProgress) {
        return 1;
      }
      return a.orderIndex.compareTo(b.orderIndex);
    });

    final itemsForSelectedDay =
        _showCombinedEvents
            ? [...eventsForSelectedDay, ...tasksForSelectedDay]
            : eventsForSelectedDay;

    final combinedItems =
        _isShowingUnassigned
            ? (_showCombinedEvents
                ? [..._unassignedEvents, ..._unassignedTasks]
                : _unassignedEvents)
            : itemsForSelectedDay;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: 8,
          ),
          child: Row(
            children: [
              Icon(
                _isShowingUnassigned
                    ? Icons.inbox_rounded
                    : (_showCombinedEvents
                        ? Icons.event_available_rounded
                        : Icons.event_note_rounded),
                color:
                    _isShowingUnassigned
                        ? colorScheme.secondary
                        : colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isShowingUnassigned
                      ? 'Unassigned Items'
                      : '${_showCombinedEvents ? "Events" : "Notes"} for ${DateFormat('EEEE').format(_selectedDate)} ${_selectedDate.day}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(
                  _isShowingUnassigned
                      ? Icons.inbox_rounded
                      : Icons.inbox_outlined,
                  color:
                      _isShowingUnassigned
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                onPressed: () {
                  setState(() => _isShowingUnassigned = !_isShowingUnassigned);
                  if (_isShowingUnassigned) {
                    _loadUnassignedItems();
                  }
                },
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: const Size(32, 32),
                  padding: EdgeInsets.zero,
                ),
              ),
              IconButton(
                icon: Icon(
                  _showCombinedEvents
                      ? Icons.layers_rounded
                      : Icons.layers_outlined,
                  color:
                      _showCombinedEvents
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                onPressed: _toggleCombinedEvents,
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: const Size(32, 32),
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child:
              combinedItems.isEmpty
                  ? Center(
                    child: Text(
                      _isShowingUnassigned
                          ? 'No unassigned items'
                          : 'No ${_showCombinedEvents ? "events" : "notes"} for this day',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: combinedItems.length,
                    itemBuilder: (context, index) {
                      final item = combinedItems[index];
                      if (item is CalendarEvent) {
                        return _buildNoteItem(item, colorScheme);
                      } else if (item is Task) {
                        return _buildTaskItem(item, colorScheme);
                      }
                      return const SizedBox.shrink();
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildNoteItem(CalendarEvent event, ColorScheme colorScheme) {
    if (event.note == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            _openNoteEditor(event.note!);
          },
          onLongPress: () {
            _showEventContextMenu(event);
          },
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 8),
            child: Row(
              children: [
                Icon(Icons.description_outlined, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        event.note!.title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (event.status != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _getStatusColor(event.status!),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              event.status!,
                              style: Theme.of(
                                context,
                              ).textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: colorScheme.error,
                      size: 18,
                    ),
                    onPressed: () async {
                      await _deleteEvent(event);
                    },
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.error.withAlpha(20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
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
  }

  Widget _buildTaskItem(Task task, ColorScheme colorScheme) {
    final isCompleted = task.completed || task.state == TaskState.completed;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            _openTaskDetails(task);
          },
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 8),
            child: Row(
              children: [
                Icon(
                  Icons.task_alt_rounded,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        task.name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color:
                              isCompleted
                                  ? colorScheme.onSurfaceVariant
                                  : colorScheme.onSurface,
                          decoration:
                              isCompleted ? TextDecoration.lineThrough : null,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (task.state != TaskState.none) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _getTaskStateColor(
                                  task.state,
                                  colorScheme,
                                ),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _getTaskStateText(task.state),
                              style: Theme.of(
                                context,
                              ).textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: colorScheme.error,
                      size: 18,
                    ),
                    onPressed: () async {
                      await _clearTaskDate(task);
                    },
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.error.withAlpha(20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
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
  }

  void _openTaskDetails(Task task) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
                TaskDetailScreen(task: task, databaseService: _databaseService),
      ),
    ).then((_) {
      _loadTasksWithDeadlines();
      _loadUnassignedItems();
    });
  }

  Color _getTaskStateColor(TaskState state, ColorScheme colorScheme) {
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

  String _getTaskStateText(TaskState state) {
    switch (state) {
      case TaskState.pending:
        return 'Pending';
      case TaskState.inProgress:
        return 'In Progress';
      case TaskState.completed:
        return 'Completed';
      case TaskState.none:
        return '';
    }
  }
}
