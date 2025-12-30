import 'package:flutter/material.dart';
import 'dart:async';
import '../../database/models/calendar_event.dart';
import '../../database/models/calendar_event_status.dart';
import '../../database/models/note.dart';
import '../../database/models/notebook.dart';
import '../../database/models/notebook_icons.dart';
import '../../database/repositories/calendar_event_repository.dart';
import '../../database/repositories/calendar_event_status_repository.dart';
import '../../database/repositories/notebook_repository.dart';
import '../../database/database_helper.dart';
import '../../database/database_service.dart';
import '../../services/notification_service.dart';
import '../custom_snackbar.dart';
import '../calendar_event_status_manager.dart';
import '../context_menu.dart';
import '../custom_tooltip.dart';

class CalendarPanel extends StatefulWidget {
  final Function(Note) onNoteSelected;
  final Function(Note)? onNoteSelectedFromPanel;
  final Function(Note)? onNoteOpenInNewTab;
  final Function(Notebook)? onNotebookSelected;
  final Function(Notebook)? onNotebookSelectedFromFavorite;
  final FocusNode appFocusNode;

  const CalendarPanel({
    super.key,
    required this.onNoteSelected,
    required this.appFocusNode,
    this.onNoteSelectedFromPanel,
    this.onNoteOpenInNewTab,
    this.onNotebookSelected,
    this.onNotebookSelectedFromFavorite,
  });

  @override
  State<CalendarPanel> createState() => CalendarPanelState();
}

class CalendarPanelState extends State<CalendarPanel>
    with SingleTickerProviderStateMixin {
  // When false the panel will be removed from layout (shrinked to nothing)
  // to avoid internal widgets being squashed during parent width animations.
  bool _isPanelVisible = true;
  late CalendarEventRepository _calendarEventRepository;
  late CalendarEventStatusRepository _statusRepository;
  late DateTime _selectedMonth;
  late DateTime _selectedDate;
  List<CalendarEvent> _events = [];
  List<CalendarEventStatus> _statuses = [];
  List<Notebook> _favoriteNotebooks = [];
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late StreamSubscription<Note> _noteUpdateSubscription;
  late StreamSubscription<void> _databaseChangeSubscription;
  late StreamController<List<CalendarEvent>> _eventsController;
  int _eventsLoadCounter = 0;

  @override
  void initState() {
    super.initState();
    _calendarEventRepository = CalendarEventRepository(DatabaseHelper());
    _statusRepository = CalendarEventStatusRepository(DatabaseHelper());
    _selectedMonth = DateTime.now();
    _selectedDate = DateTime.now();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _noteUpdateSubscription = NotificationService().noteUpdateStream.listen(
      _handleNoteUpdate,
    );
    _databaseChangeSubscription = DatabaseService().onDatabaseChanged.listen((
      _,
    ) {
      _loadFavoriteNotebooks();
    });
    _eventsController = StreamController<List<CalendarEvent>>.broadcast();
    _loadEvents();
    _loadStatuses();
    _loadFavoriteNotebooks();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _noteUpdateSubscription.cancel();
    _databaseChangeSubscription.cancel();
    _eventsController.close();
    super.dispose();
  }

  // Public API for external controls (e.g. the sidebar) to show/hide the panel
  // without animating its width down to 0 which causes internal layout
  // overflow. Callers can use the GlobalKey<State> attached to this widget to
  // access these methods.
  void togglePanel() {
    setState(() {
      _isPanelVisible = !_isPanelVisible;
    });
  }

  void showPanel() {
    if (!_isPanelVisible) {
      setState(() {
        _isPanelVisible = true;
      });
    }
  }

  void hidePanel() {
    if (_isPanelVisible) {
      setState(() {
        _isPanelVisible = false;
      });
    }
  }

  /// Reloads all calendar data (events, statuses, and favorite notebooks)
  /// Used for refreshing after sync operations
  void reloadCalendar() {
    _loadEvents();
    _loadStatuses();
    _loadFavoriteNotebooks();
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
    // Emit the updated events list so UI using the stream can update
    if (!_eventsController.isClosed) {
      _eventsController.add(_events);
    }
  }

  Future<void> _loadEvents({bool animate = true}) async {
    if (!mounted) return;

    final int callId = ++_eventsLoadCounter;

    final isFirstLoad = _events.isEmpty;
    setState(() {
      if (isFirstLoad) {
        _isLoading = true;
      }
    });

    try {
      // Load events for the displayed month, adjacent months, and the month
      // containing the currently selected date so the selected day's events
      // don't disappear when the user navigates multiple months away.
      final displayedMonthStart = DateTime(
        _selectedMonth.year,
        _selectedMonth.month,
        1,
      );
      final prevMonthStart = DateTime(
        _selectedMonth.year,
        _selectedMonth.month - 1,
        1,
      );
      final nextMonthStart = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        1,
      );
      final selectedMonthStart = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        1,
      );

      // Build a list of unique month-starts to fetch
      final Map<String, DateTime> monthsToFetch = {};
      void addMonth(DateTime dt) =>
          monthsToFetch['${dt.year}-${dt.month}'] = dt;
      addMonth(displayedMonthStart);
      addMonth(prevMonthStart);
      addMonth(nextMonthStart);
      addMonth(selectedMonthStart);

      final results = await Future.wait(
        monthsToFetch.values.map(
          (dt) => _calendarEventRepository.getCalendarEventsByMonth(dt),
        ),
      );

      // Merge results avoiding duplicates (by id)
      final Map<int, CalendarEvent> merged = {};
      for (final list in results) {
        for (final e in list) {
          merged[e.id] = e;
        }
      }

      // Ignore results from stale calls (user navigated again before this
      // call finished).
      if (!mounted || callId != _eventsLoadCounter) return;

      setState(() {
        _events = merged.values.toList();
        _isLoading = false;
      });
      // Emit events for StreamBuilder consumers
      if (!_eventsController.isClosed) {
        _eventsController.add(_events);
      }
      // Only animate the calendar (not the events panel) so the events
      // list doesn't disappear while switching months.
      if (animate) {
        _animationController.forward();
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

  Future<void> _loadFavoriteNotebooks() async {
    if (!mounted) return;

    try {
      final repo = NotebookRepository(DatabaseHelper());
      final rootNotebooks = await repo.getNotebooksByParentId(null);

      List<Notebook> allNotebooks = [];

      Future<void> loadAllNotebooks(Notebook notebook) async {
        allNotebooks.add(notebook);
        if (notebook.id != null) {
          try {
            final children = await repo.getNotebooksByParentId(notebook.id);
            for (final child in children) {
              await loadAllNotebooks(child);
            }
          } catch (e) {
            // Ignore errors
          }
        }
      }

      for (final notebook in rootNotebooks) {
        await loadAllNotebooks(notebook);
      }

      final favorites = allNotebooks.where((n) => n.isFavorite).toList();
      if (mounted) {
        setState(() {
          _favoriteNotebooks = favorites;
        });
      }
    } catch (e) {
      // Handle error silently
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

  void _goToPreviousMonth() {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month - 1,
        1,
      );
    });
    _loadEvents(animate: false);
  }

  void _goToNextMonth() {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        1,
      );
    });
    _loadEvents(animate: false);
  }

  void _goToCurrentMonth() {
    setState(() {
      _selectedMonth = DateTime.now();
      _selectedDate = DateTime.now();
    });
    _loadEvents(animate: false);
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

  Future<void> _handleNoteDropWithDate(Note note, DateTime date) async {
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
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error adding note to calendar: $e',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  Future<void> _handleEventDropWithDate(
    CalendarEvent event,
    DateTime newDate,
  ) async {
    try {
      // Verificar si ya existe un evento para esta nota en el día destino
      final existingEvent = _events.firstWhere(
        (e) => e.noteId == event.noteId && e.date.isAtSameMomentAs(newDate),
        orElse:
            () => CalendarEvent(id: 0, noteId: 0, date: newDate, orderIndex: 0),
      );

      if (existingEvent.id != 0 && existingEvent.id != event.id) {
        if (mounted) {
          CustomSnackbar.show(
            context: context,
            message: 'This note is already assigned to this day',
            type: CustomSnackbarType.error,
          );
        }
        return;
      }

      // Actualizar la fecha del evento
      final updatedEvent = event.copyWith(date: newDate);
      await _calendarEventRepository.updateCalendarEvent(updatedEvent);
      DatabaseHelper.notifyDatabaseChanged();
      await _loadEvents();
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error moving event: $e',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // If the panel is hidden, return a zero-size widget so parent width
    // animations don't cause children to compress and overflow.
    if (!_isPanelVisible) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          child: Column(
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: 8,
                      ),
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
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall?.copyWith(
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
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
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child:
                              _isLoading
                                  ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                  : _buildCalendar(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 10,
                child: Container(
                  width: constraints.maxWidth,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainer,
                  ),
                  child: StreamBuilder<List<CalendarEvent>>(
                    stream: _eventsController.stream,
                    initialData: _events,
                    builder: (context, snapshot) {
                      final eventsSnapshot = snapshot.data ?? _events;
                      return _buildEventsPanel(eventsSnapshot);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEventsPanel(List<CalendarEvent> eventsSource) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final eventsForSelectedDay =
            eventsSource
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
                    orderIndex:
                        999, // Alto orderIndex para status no encontrados
                  ),
            );
            final statusB = _statuses.firstWhere(
              (s) => s.name == b.status,
              orElse:
                  () => CalendarEventStatus(
                    id: 0,
                    name: b.status!,
                    color: '#2196F3',
                    orderIndex:
                        999, // Alto orderIndex para status no encontrados
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
          width: constraints.maxWidth,
          decoration: BoxDecoration(color: colorScheme.surfaceContainerLow),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.event_note_rounded,
                          size: 20,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          // Use the selected date's month name so selecting days from
                          // previous/next months shows the correct month in the header.
                          'Notes for ${['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][_selectedDate.month - 1]} ${_selectedDate.day}, ${_selectedDate.year}',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(color: colorScheme.onSurface),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.label_rounded,
                        color: colorScheme.primary,
                      ),
                      onPressed: _showStatusManager,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              Expanded(
                child:
                    eventsForSelectedDay.isEmpty
                        ? Center(
                          child: Text(
                            'No notes for this day',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
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

                            return Draggable<CalendarEvent>(
                              data: event,
                              dragAnchorStrategy: pointerDragAnchorStrategy,
                              feedback: Material(
                                color: Colors.transparent,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(51),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.description_outlined,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        event.note?.title ?? 'Unknown Note',
                                        style: TextStyle(
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              child: CustomTooltip(
                                message: event.note!.title,
                                builder: (context, isHovering) {
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
                                          // Inform parent that the note was selected from the calendar
                                          // so it can suppress tab open/replace animations if desired.
                                          if (widget.onNoteSelectedFromPanel !=
                                              null) {
                                            widget.onNoteSelectedFromPanel!(
                                              event.note!,
                                            );
                                          }
                                          widget.onNoteSelected(event.note!);
                                        },
                                        onSecondaryTapDown:
                                            (details) =>
                                                _showStatusMenu(event, details),
                                        child: Listener(
                                          onPointerDown: (pointerEvent) {
                                            try {
                                              if ((pointerEvent.buttons & 4) !=
                                                  0) {
                                                if (widget.onNoteOpenInNewTab !=
                                                        null &&
                                                    event.note != null) {
                                                  widget.onNoteOpenInNewTab!(
                                                    event.note!,
                                                  );
                                                } else {}
                                              }
                                            } catch (e) {
                                              print(
                                                '[calendar] error in onPointerDown: $e',
                                              );
                                            }
                                          },
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTertiaryTapDown: (details) {
                                              if (widget.onNoteOpenInNewTab !=
                                                      null &&
                                                  event.note != null) {
                                                widget.onNoteOpenInNewTab!(
                                                  event.note!,
                                                );
                                              } else {
                                                print(
                                                  '[calendar] onNoteOpenInNewTab callback is null or note is null',
                                                );
                                              }
                                            },
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 6,
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
                                                          CrossAxisAlignment
                                                              .start,
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          event.note!.title,
                                                          style: Theme.of(
                                                                context,
                                                              )
                                                              .textTheme
                                                              .bodyMedium
                                                              ?.copyWith(
                                                                color:
                                                                    colorScheme
                                                                        .onSurface,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                          maxLines: 1,
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                        ),
                                                        if (event.status !=
                                                            null) ...[
                                                          const SizedBox(
                                                            height: 2,
                                                          ),
                                                          Row(
                                                            children: [
                                                              Container(
                                                                width: 8,
                                                                height: 8,
                                                                decoration: BoxDecoration(
                                                                  color: _getStatusColor(
                                                                    event
                                                                        .status!,
                                                                  ),
                                                                  shape:
                                                                      BoxShape
                                                                          .circle,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                width: 4,
                                                              ),
                                                              Baseline(
                                                                baseline: 8,
                                                                baselineType:
                                                                    TextBaseline
                                                                        .alphabetic,
                                                                child: Text(
                                                                  event.status!,
                                                                  style: Theme.of(
                                                                        context,
                                                                      )
                                                                      .textTheme
                                                                      .bodySmall
                                                                      ?.copyWith(
                                                                        color:
                                                                            colorScheme.onSurfaceVariant,
                                                                        fontSize:
                                                                            10,
                                                                      ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                  // Delete button (only visible on hover)
                                                  Opacity(
                                                    opacity:
                                                        isHovering ? 1.0 : 0.0,
                                                    child: IgnorePointer(
                                                      ignoring: !isHovering,
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              left: 4,
                                                            ),
                                                        child: MouseRegion(
                                                          cursor:
                                                              SystemMouseCursors
                                                                  .click,
                                                          child: GestureDetector(
                                                            onTap:
                                                                () =>
                                                                    _deleteEvent(
                                                                      event,
                                                                    ),
                                                            child: Container(
                                                              padding:
                                                                  const EdgeInsets.all(
                                                                    4,
                                                                  ),
                                                              decoration: BoxDecoration(
                                                                color: colorScheme
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
                                                                    colorScheme
                                                                        .error,
                                                              ),
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
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
              ),
              if (_favoriteNotebooks.isNotEmpty) _buildFavoriteNotebooksPanel(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFavoriteNotebooksPanel() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.only(right: 16, left: 16, bottom: 16, top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.favorite_rounded,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Favorite Notebooks',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 130),
            child: SingleChildScrollView(
              child: SizedBox(
                width: double.infinity,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      _favoriteNotebooks.map((notebook) {
                        final notebookIcon =
                            notebook.iconId != null
                                ? NotebookIconsRepository.getIconById(
                                  notebook.iconId!,
                                )
                                : null;
                        final iconToShow =
                            notebookIcon ??
                            NotebookIconsRepository.getDefaultIcon();
                        return Material(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            onTap:
                                () =>
                                    widget.onNotebookSelectedFromFavorite?.call(
                                      notebook,
                                    ) ??
                                    widget.onNotebookSelected?.call(notebook),
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
                                    iconToShow.icon,
                                    color: colorScheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    notebook.name,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurface,
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
    );
  }

  Widget _buildCalendar() {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
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

        // Calculate previous month info
        final prevMonthLastDay = DateTime(
          _selectedMonth.year,
          _selectedMonth.month,
          0,
        );
        final daysInPrevMonth = prevMonthLastDay.day;

        final List<Widget> calendarRows = [];

        // Generate all days to display (42 days = 6 weeks)
        final List<DateTime> allDays = [];

        // Add days from previous month
        for (int i = firstWeekday - 1; i > 0; i--) {
          allDays.add(
            DateTime(
              _selectedMonth.year,
              _selectedMonth.month - 1,
              daysInPrevMonth - i + 1,
            ),
          );
        }

        // Add days from current month
        for (int i = 1; i <= daysInMonth; i++) {
          allDays.add(DateTime(_selectedMonth.year, _selectedMonth.month, i));
        }

        // Add days from next month to complete 42 days
        int nextMonthDay = 1;
        while (allDays.length < 42) {
          allDays.add(
            DateTime(
              _selectedMonth.year,
              _selectedMonth.month + 1,
              nextMonthDay,
            ),
          );
          nextMonthDay++;
        }

        // Build calendar rows
        for (int week = 0; week < 6; week++) {
          final List<Widget> rowChildren = [];

          for (int day = 0; day < 7; day++) {
            final dayIndex = week * 7 + day;
            final date = allDays[dayIndex];
            final isCurrentMonth = date.month == _selectedMonth.month;

            final isSelected =
                _selectedDate.year == date.year &&
                _selectedDate.month == date.month &&
                _selectedDate.day == date.day;

            final hasEvents = _events.any(
              (event) =>
                  event.date.year == date.year &&
                  event.date.month == date.month &&
                  event.date.day == date.day,
            );

            rowChildren.add(
              Expanded(
                child: DragTarget<Object>(
                  onWillAcceptWithDetails: (details) {
                    final data = details.data;
                    if (data is Map<String, dynamic>) {
                      if (data['type'] == 'note') {
                        if (data['isMultiDrag'] == true) {
                          final notes = data['selectedNotes'] as List<Note>;
                          return notes.every((note) => note.id != null);
                        } else {
                          final note = data['note'] as Note;
                          return note.id != null;
                        }
                      }
                    } else if (data is CalendarEvent) {
                      return data.id != 0;
                    }
                    return false;
                  },
                  onAcceptWithDetails: (details) async {
                    final data = details.data;
                    if (data is Map<String, dynamic> &&
                        data['type'] == 'note') {
                      if (data['isMultiDrag'] == true) {
                        final notes = data['selectedNotes'] as List<Note>;
                        for (final note in notes) {
                          await _handleNoteDropWithDate(note, date);
                        }
                      } else {
                        final note = data['note'] as Note;
                        await _handleNoteDropWithDate(note, date);
                      }
                    } else if (data is CalendarEvent) {
                      await _handleEventDropWithDate(data, date);
                    }
                  },
                  builder: (context, candidateData, rejectedData) {
                    return AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color:
                              isSelected
                                  ? (Theme.of(context).brightness ==
                                          Brightness.light
                                      ? colorScheme.primaryContainer
                                      : colorScheme.primaryFixed.withAlpha(50))
                                  : candidateData.isNotEmpty
                                  ? colorScheme.onSurfaceVariant.withAlpha(20)
                                  : null,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              // Always select the tapped date but do not change the displayed month.
                              // If the tapped date belongs to a different month, fetch events for that
                              // month as well so indicators and the events list update correctly.
                              setState(() {
                                _selectedDate = date;
                              });

                              final tappedMonthStart = DateTime(
                                date.year,
                                date.month,
                                1,
                              );
                              final currentDisplayedMonthStart = DateTime(
                                _selectedMonth.year,
                                _selectedMonth.month,
                                1,
                              );

                              if (tappedMonthStart.year !=
                                      currentDisplayedMonthStart.year ||
                                  tappedMonthStart.month !=
                                      currentDisplayedMonthStart.month) {
                                try {
                                  final tappedEvents =
                                      await _calendarEventRepository
                                          .getCalendarEventsByMonth(
                                            tappedMonthStart,
                                          );

                                  if (!mounted) return;

                                  // Merge tappedEvents into _events avoiding duplicates (by id)
                                  final Map<int, CalendarEvent> combined = {};
                                  for (final e in _events) {
                                    combined[e.id] = e;
                                  }
                                  for (final e in tappedEvents) {
                                    combined[e.id] = e;
                                  }

                                  setState(() {
                                    _events = combined.values.toList();
                                  });
                                  // Emit updated events so the events panel (StreamBuilder) updates
                                  if (!_eventsController.isClosed) {
                                    _eventsController.add(_events);
                                  }
                                } catch (e) {
                                  // ignore errors fetching tapped month events
                                }
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(
                              children: [
                                Center(
                                  child: Text(
                                    date.day.toString(),
                                    style: TextStyle(
                                      color:
                                          isSelected
                                              ? (Theme.of(context).brightness ==
                                                      Brightness.light
                                                  ? colorScheme
                                                      .onPrimaryContainer
                                                  : colorScheme.primaryFixed)
                                              : isCurrentMonth
                                              ? colorScheme.onSurface
                                              : colorScheme.onSurfaceVariant
                                                  .withAlpha(100),
                                      fontWeight:
                                          isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                      fontSize: isSelected ? 16 : 14,
                                    ),
                                  ),
                                ),
                                if (hasEvents)
                                  Positioned(
                                    bottom: 2,
                                    left: 0,
                                    right: 0,
                                    child: Center(
                                      child: Container(
                                        width: 4,
                                        height: 4,
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
          }

          calendarRows.add(Expanded(child: Row(children: rowChildren)));
        }

        return Column(
          children: [
            SizedBox(
              height: 24,
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
                                  fontSize: 12,
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
      },
    );
  }

  Future<void> _deleteEvent(CalendarEvent event) async {
    try {
      await _calendarEventRepository.deleteCalendarEvent(event.id);
      DatabaseHelper.notifyDatabaseChanged();
      await _loadEvents();
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error removing note from calendar: $e',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  Future<void> _showStatusMenu(
    CalendarEvent event, [
    TapDownDetails? details,
  ]) async {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final Offset tapPosition = details?.globalPosition ?? Offset.zero;

    List<ContextMenuItem> items = [
      ..._statuses.map(
        (status) => ContextMenuItem(
          icon: Icons.label,
          label: status.name,
          onTap: () async {
            await _updateEventStatus(event, status.name);
          },
          iconColor: _parseColor(status.color),
        ),
      ),
      ContextMenuItem(
        icon: Icons.clear,
        label: 'No Label',
        onTap: () async {
          await _updateEventStatus(event, null);
        },
        iconColor: Theme.of(context).colorScheme.outline,
      ),
      ContextMenuItem(
        icon: Icons.settings,
        label: 'Manage Event Labels',
        onTap: () async {
          await _showStatusManager();
        },
        iconColor: Theme.of(context).colorScheme.primary,
      ),
    ];

    ContextMenuOverlay.show(
      context: context,
      tapPosition:
          tapPosition == Offset.zero
              ? overlay.size.center(Offset.zero)
              : tapPosition,
      items: items,
    );
  }

  Future<void> _showStatusManager() async {
    await showDialog(
      context: context,
      builder:
          (context) => CalendarEventStatusManager(
            onStatusSelected: (status) {
              // This will be handled by the manager itself
            },
          ),
    );
    await _loadStatuses();
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
          message: 'Error updating event status: $e',
          type: CustomSnackbarType.error,
        );
      }
    }
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
}
