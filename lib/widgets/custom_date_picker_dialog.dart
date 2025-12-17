import 'package:flutter/material.dart';

class CustomDatePickerDialog extends StatefulWidget {
  final DateTime? initialDate;
  final List<DateTime>? eventDates;

  const CustomDatePickerDialog({super.key, this.initialDate, this.eventDates});

  @override
  State<CustomDatePickerDialog> createState() => _CustomDatePickerDialogState();
}

class _CustomDatePickerDialogState extends State<CustomDatePickerDialog> {
  late DateTime _currentMonth;
  late DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    _currentMonth = widget.initialDate ?? DateTime.now();
  }

  String _getMonthName(int month) {
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
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 320,
          decoration: BoxDecoration(
            color: colorScheme.surface,
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
                      Icons.calendar_month_rounded,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${_getMonthName(_currentMonth.month)} ${_currentMonth.year}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: () {
                        setState(() {
                          _currentMonth = DateTime(
                            _currentMonth.year,
                            _currentMonth.month - 1,
                            1,
                          );
                        });
                      },
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _currentMonth = DateTime.now();
                          _selectedDate = DateTime.now();
                        });
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(40, 32),
                      ),
                      child: const Text('Today'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: () {
                        setState(() {
                          _currentMonth = DateTime(
                            _currentMonth.year,
                            _currentMonth.month + 1,
                            1,
                          );
                        });
                      },
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    _buildCalendarGrid(colorScheme),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.all<Color>(
                                colorScheme.surfaceContainerHigh,
                              ),
                              foregroundColor: WidgetStateProperty.all<Color>(
                                colorScheme.onSurface,
                              ),
                              minimumSize: WidgetStateProperty.all<Size>(
                                const Size(0, 44),
                              ),
                              shape: WidgetStateProperty.all<
                                RoundedRectangleBorder
                              >(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.normal,
                                  fontSize: 15,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.all<Color>(
                                colorScheme.primary,
                              ),
                              foregroundColor: WidgetStateProperty.all<Color>(
                                colorScheme.onPrimary,
                              ),
                              minimumSize: WidgetStateProperty.all<Size>(
                                const Size(0, 44),
                              ),
                              elevation: WidgetStateProperty.all<double>(0),
                              shape: WidgetStateProperty.all<
                                RoundedRectangleBorder
                              >(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            onPressed:
                                _selectedDate == null
                                    ? null
                                    : () =>
                                        Navigator.pop(context, _selectedDate),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Save',
                                style: TextStyle(
                                  color: colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildCalendarGrid(ColorScheme colorScheme) {
    final firstDayOfMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month,
      1,
    );
    final lastDayOfMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month + 1,
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
          rowChildren.add(const SizedBox(width: 40, height: 40));
        } else if (currentDay <= daysInMonth) {
          final day = currentDay;
          final date = DateTime(_currentMonth.year, _currentMonth.month, day);
          final isSelected =
              _selectedDate != null &&
              _selectedDate!.year == date.year &&
              _selectedDate!.month == date.month &&
              _selectedDate!.day == date.day;

          final hasEvents =
              widget.eventDates?.any(
                (eventDate) =>
                    eventDate.year == date.year &&
                    eventDate.month == date.month &&
                    eventDate.day == date.day,
              ) ??
              false;

          rowChildren.add(
            SizedBox(
              width: 40,
              height: 40,
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? colorScheme.primaryFixed.withAlpha(50)
                          : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedDate = date;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
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
            ),
          );
          currentDay++;
        } else {
          rowChildren.add(const SizedBox(width: 40, height: 40));
        }
      }

      calendarRows.add(
        Row(mainAxisAlignment: MainAxisAlignment.center, children: rowChildren),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 24,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children:
                ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                    .map(
                      (day) => SizedBox(
                        width: 40,
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
  }
}
