import 'package:flutter/material.dart';
import 'dart:async';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import '../database/models/diary_entry.dart';
import '../database/services/diary_service.dart';
import '../database/database_helper.dart';
import '../database/repositories/diary_repository.dart';

class DiaryCalendarPanel extends StatefulWidget {
  final Function(DiaryEntry) onDiaryEntrySelected;
  final Function(DateTime)? onDateSelected;
  final DateTime? selectedDate;
  final FocusNode appFocusNode;

  const DiaryCalendarPanel({
    super.key,
    required this.onDiaryEntrySelected,
    this.onDateSelected,
    this.selectedDate,
    required this.appFocusNode,
  });

  @override
  DiaryCalendarPanelState createState() => DiaryCalendarPanelState();
}

class DiaryCalendarPanelState extends State<DiaryCalendarPanel>
    with SingleTickerProviderStateMixin {
  late DiaryService _diaryService;
  late DateTime _selectedMonth;
  late DateTime _selectedDate;
  List<DiaryEntry> _entries = [];
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _diaryService = DiaryService(DiaryRepository(DatabaseHelper()));
    _selectedMonth = DateTime.now();
    _selectedDate = DateTime.now();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _loadEntries();
  }

  @override
  void didUpdateWidget(DiaryCalendarPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update internal selected date when widget's selectedDate changes
    if (widget.selectedDate != null &&
        (oldWidget.selectedDate == null ||
            !_isSameDay(widget.selectedDate!, oldWidget.selectedDate!))) {
      setState(() {
        _selectedDate = widget.selectedDate!;
      });
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final entries = await _diaryService.getDiaryEntriesByMonth(
        _selectedMonth.year,
        _selectedMonth.month,
      );
      if (mounted) {
        setState(() {
          _entries = entries;
          _isLoading = false;
        });
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

  Future<void> reloadEntries() async {
    await _loadEntries();
  }

  void _goToPreviousMonth() {
    _animationController.reverse().then((_) {
      setState(() {
        _selectedMonth = DateTime(
          _selectedMonth.year,
          _selectedMonth.month - 1,
          1,
        );
      });
      _loadEntries();
    });
  }

  void _goToNextMonth() {
    _animationController.reverse().then((_) {
      setState(() {
        _selectedMonth = DateTime(
          _selectedMonth.year,
          _selectedMonth.month + 1,
          1,
        );
      });
      _loadEntries();
    });
  }

  void _goToCurrentMonth() {
    _animationController.reverse().then((_) {
      setState(() {
        _selectedMonth = DateTime.now();
        _selectedDate = DateTime.now();
      });
      _loadEntries();
    });
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

  bool _hasEntryForDate(DateTime date) {
    return _entries.any((entry) {
      final entryDate = DateTime(
        entry.date.year,
        entry.date.month,
        entry.date.day,
      );
      final checkDate = DateTime(date.year, date.month, date.day);
      return entryDate.isAtSameMomentAs(checkDate);
    });
  }

  DiaryEntry? _getEntryForDate(DateTime date) {
    try {
      return _entries.firstWhere((entry) {
        final entryDate = DateTime(
          entry.date.year,
          entry.date.month,
          entry.date.day,
        );
        final checkDate = DateTime(date.year, date.month, date.day);
        return entryDate.isAtSameMomentAs(checkDate);
      });
    } catch (e) {
      return null;
    }
  }

  void _onDateSelected(DateTime date) {
    // Update internal selected date
    setState(() {
      _selectedDate = date;
    });

    final entry = _getEntryForDate(date);
    if (entry != null) {
      // If entry exists, open it
      widget.onDiaryEntrySelected(entry);
    } else {
      // If no entry exists, just select the date
      widget.onDateSelected?.call(date);
    }
  }

  bool _isDateSelected(DateTime date) {
    return _isSameDay(date, _selectedDate);
  }

  List<DateTime> _getDaysInMonth() {
    final firstDay = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final daysInMonth = lastDay.day;

    final firstWeekday = firstDay.weekday;
    final days = <DateTime>[];

    // Add days from previous month to fill first week
    for (int i = firstWeekday - 1; i > 0; i--) {
      days.add(firstDay.subtract(Duration(days: i)));
    }

    // Add days of current month
    for (int i = 1; i <= daysInMonth; i++) {
      days.add(DateTime(_selectedMonth.year, _selectedMonth.month, i));
    }

    // Add days from next month to fill last week
    final remainingDays = 42 - days.length; // 6 weeks * 7 days
    for (int i = 1; i <= remainingDays; i++) {
      days.add(lastDay.add(Duration(days: i)));
    }

    return days;
  }

  Widget _buildTrailingButton() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: _goToPreviousMonth,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final days = _getDaysInMonth();

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          child: Column(
            children: [
              // Header with title and MoveWindow at the same level
              Stack(
                children: [
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_month_rounded,
                            size: 20,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formattedMonth,
                            style: Theme.of(
                              context,
                            ).textTheme.titleSmall?.copyWith(
                              color: colorScheme.onSurface,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Spacer(),
                          _buildTrailingButton(),
                        ],
                      ),
                    ),
                  ),
                  // MoveWindow en el área del título, excluyendo el área de los botones
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 120, // Excluir área de los botones de navegación
                    height: 48,
                    child: MoveWindow(),
                  ),
                ],
              ),
              // Calendar grid
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child:
                        _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : _buildCalendarGrid(days),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCalendarGrid(List<DateTime> days) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Day headers
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
        // Calendar grid
        Expanded(
          child: LayoutBuilder(
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

              final List<Widget> calendarRows = [];
              int currentDay = 1;
              int nextMonthDay = 1;

              while (currentDay <= daysInMonth) {
                final List<Widget> rowChildren = [];

                for (int i = 1; i <= 7; i++) {
                  if (currentDay == 1 && i < firstWeekday) {
                    // Days from previous month
                    final prevMonth = DateTime(
                      _selectedMonth.year,
                      _selectedMonth.month - 1,
                      0,
                    );
                    final prevMonthDay = prevMonth.day - (firstWeekday - i - 1);
                    final prevMonthDate = DateTime(
                      _selectedMonth.year,
                      _selectedMonth.month - 1,
                      prevMonthDay,
                    );

                    rowChildren.add(
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _onDateSelected(prevMonthDate),
                                borderRadius: BorderRadius.circular(8),
                                child: Center(
                                  child: Text(
                                    prevMonthDay.toString(),
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant
                                          .withAlpha(100),
                                      fontWeight: FontWeight.normal,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  } else if (currentDay <= daysInMonth) {
                    final day = currentDay;
                    final date = DateTime(
                      _selectedMonth.year,
                      _selectedMonth.month,
                      day,
                    );
                    final isSelected = _isDateSelected(date);
                    final hasEntry = _hasEntryForDate(date);

                    rowChildren.add(
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? colorScheme.primaryContainer
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _onDateSelected(date),
                                borderRadius: BorderRadius.circular(8),
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
                                          fontSize: isSelected ? 16 : 14,
                                        ),
                                      ),
                                    ),
                                    if (hasEntry)
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
                        ),
                      ),
                    );
                    currentDay++;
                  } else {
                    // Days from next month
                    final nextMonthDate = DateTime(
                      _selectedMonth.year,
                      _selectedMonth.month + 1,
                      nextMonthDay,
                    );

                    rowChildren.add(
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _onDateSelected(nextMonthDate),
                                borderRadius: BorderRadius.circular(8),
                                child: Center(
                                  child: Text(
                                    nextMonthDay.toString(),
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant
                                          .withAlpha(100),
                                      fontWeight: FontWeight.normal,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                    nextMonthDay++;
                  }
                }

                calendarRows.add(Expanded(child: Row(children: rowChildren)));
              }

              return Column(children: calendarRows);
            },
          ),
        ),
      ],
    );
  }
}
