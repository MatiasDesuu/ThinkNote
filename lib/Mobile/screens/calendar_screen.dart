import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../../database/models/calendar_event.dart';
import '../../database/models/calendar_event_status.dart';
import '../../database/models/note.dart';
import '../../database/repositories/calendar_event_repository.dart';
import '../../database/repositories/calendar_event_status_repository.dart';
import '../../database/repositories/note_repository.dart';
import '../../database/database_helper.dart';
import '../../services/notification_service.dart';
import '../../widgets/custom_snackbar.dart';
import '../widgets/note_editor.dart';
import 'calendar_event_status_screen.dart';

class CalendarScreen extends StatefulWidget {
  final Function(Note) onNoteSelected;

  const CalendarScreen({super.key, required this.onNoteSelected});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const String _calendarExpandedKey = 'calendar_expanded';
  late CalendarEventRepository _calendarEventRepository;
  late CalendarEventStatusRepository _statusRepository;
  late DateTime _selectedMonth;
  late DateTime _selectedDate;
  List<CalendarEvent> _events = [];
  List<CalendarEventStatus> _statuses = [];
  bool _isLoading = true;
  bool _isExpanded = true;
  bool _isInitialized = false;
  late StreamSubscription<Note> _noteUpdateSubscription;

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
    _loadEvents();
    _loadStatuses();
  }

  Future<void> _loadCalendarState() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isExpanded = prefs.getBool(_calendarExpandedKey) ?? true;
        _isInitialized = true;
      });
    }
  }

  Future<void> _saveCalendarState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_calendarExpandedKey, _isExpanded);
  }

  @override
  void dispose() {
    _noteUpdateSubscription.cancel();
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

  Future<void> _loadEvents() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final events = await _calendarEventRepository.getCalendarEventsByMonth(
        _selectedMonth,
      );
      if (mounted) {
        setState(() {
          _events = events;
          _isLoading = false;
        });
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

      // Initialize default statuses if none exist
      if (statuses.isEmpty) {
        await _initializeDefaultStatuses();
      }
    } catch (e) {
      // Handle error silently for now
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
        // Ignore errors for duplicate statuses
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

      await _calendarEventRepository.createCalendarEvent(event);
      DatabaseHelper.notifyDatabaseChanged();
      await _loadEvents();
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
      await _calendarEventRepository.deleteCalendarEvent(event.id);
      DatabaseHelper.notifyDatabaseChanged();
      await _loadEvents();
    } catch (e) {
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

  Future<void> _updateEventStatus(
    CalendarEvent event,
    String? statusName,
  ) async {
    try {
      CalendarEvent updatedEvent;
      if (statusName == null) {
        // Limpiar el status
        updatedEvent = event.copyWith(clearStatus: true);
      } else {
        // Asignar un status específico
        updatedEvent = event.copyWith(status: statusName);
      }
      await _calendarEventRepository.updateCalendarEvent(updatedEvent);
      DatabaseHelper.notifyDatabaseChanged();
      await _loadEvents();
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error updating event label: $e',
          type: CustomSnackbarType.error,
        );
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
                    ..._statuses.map(
                      (status) => Card(
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
                                style: TextStyle(color: colorScheme.onSurface),
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
                              style: TextStyle(color: colorScheme.onSurface),
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
                      color: colorScheme.primary,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.pop(context);
                            _showStatusManager();
                          },
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            leading: Icon(
                              Icons.label_rounded,
                              color: colorScheme.onPrimary,
                            ),
                            title: Text(
                              'Event Labels',
                              style: TextStyle(color: colorScheme.onPrimary),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showStatusManager() async {
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
                  onSaveNote: () async {
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
        .then((_) {
          // No need to manually reload notes, StreamBuilder will handle it
        });
  }

  Widget _buildWeekView() {
    final colorScheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final firstDayOfWeek = today.subtract(Duration(days: today.weekday - 1));

    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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

          return Expanded(
            child: DragTarget<Note>(
              onWillAcceptWithDetails: (details) => details.data.id != null,
              onAcceptWithDetails:
                  (details) => _handleNoteDrop(details.data, date.day),
              builder: (context, candidateData, rejectedData) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? colorScheme.primaryFixed.withAlpha(50)
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
                        });
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
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              date.day.toString(),
                              style: TextStyle(
                                color:
                                    isSelected
                                        ? colorScheme.primaryFixed
                                        : colorScheme.onSurface,
                                fontWeight:
                                    isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                fontSize: isSelected ? 14 : 12,
                              ),
                            ),
                            if (hasEvents)
                              Container(
                                width: 3,
                                height: 3,
                                margin: const EdgeInsets.only(top: 1),
                                decoration: BoxDecoration(
                                  color:
                                      isSelected
                                          ? colorScheme.primary
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            icon: Icon(Icons.label_rounded, color: colorScheme.primary),
            onPressed: _showStatusManager,
          ),
          IconButton(
            icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
            onPressed: _toggleCalendar,
          ),
        ],
      ),
      body: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: _isExpanded ? 400 : 80,
            child: _isExpanded ? _buildExpandedCalendar() : _buildWeekView(),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: colorScheme.surfaceContainer),
              child: _buildEventsPanel(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedCalendar() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16),
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
                                ? colorScheme.primaryFixed.withAlpha(50)
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
                                            ? colorScheme.primaryFixed
                                            : colorScheme.onSurface,
                                    fontWeight:
                                        isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                    fontSize: isSelected ? 18 : 16,
                                  ),
                                ),
                              ),
                              if (hasEvents)
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
                                                ? colorScheme.primary
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

    // Ordenar eventos según el status y su orderIndex
    eventsForSelectedDay.sort((a, b) {
      // Si ambos eventos tienen status, ordenar por orderIndex
      if (a.status != null && b.status != null) {
        final statusA = _statuses.firstWhere(
          (s) => s.name == a.status,
          orElse:
              () => CalendarEventStatus(
                id: 0,
                name: a.status!,
                color: '#2196F3',
                orderIndex: 999, // Alto orderIndex para status no encontrados
              ),
        );
        final statusB = _statuses.firstWhere(
          (s) => s.name == b.status,
          orElse:
              () => CalendarEventStatus(
                id: 0,
                name: b.status!,
                color: '#2196F3',
                orderIndex: 999, // Alto orderIndex para status no encontrados
              ),
        );
        return statusA.orderIndex.compareTo(statusB.orderIndex);
      }

      // Si solo uno tiene status, el que no tiene status va al final
      if (a.status == null && b.status != null) {
        return 1; // a va después de b
      }
      if (a.status != null && b.status == null) {
        return -1; // a va antes de b
      }

      // Si ninguno tiene status, mantener el orden original
      return 0;
    });

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withAlpha(127),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Notes for ${_selectedDate.day}-${_formattedMonth.split(' ')[0]}-${_selectedDate.year}',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: colorScheme.onSurface),
            ),
          ),
          Expanded(
            child:
                eventsForSelectedDay.isEmpty
                    ? Center(
                      child: Text(
                        'No notes for this day',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: eventsForSelectedDay.length,
                      itemBuilder: (context, index) {
                        final event = eventsForSelectedDay[index];
                        if (event.note == null) {
                          return const SizedBox.shrink();
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: colorScheme.surfaceContainerHighest,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                _openNoteEditor(event.note!);
                              },
                              onLongPress: () {
                                _showStatusMenu(event);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.description_outlined,
                                      color: colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            event.note!.title,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium?.copyWith(
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
                                                    color: _getStatusColor(
                                                      event.status!,
                                                    ),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  event.status!,
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.bodySmall?.copyWith(
                                                    color:
                                                        colorScheme
                                                            .onSurfaceVariant,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline_rounded,
                                        color: colorScheme.error,
                                      ),
                                      onPressed: () => _deleteEvent(event),
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
    );
  }
}
