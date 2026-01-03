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
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate responsive dimensions
    final isMobile = screenWidth < 600;
    final dialogWidth =
        isMobile ? (screenWidth - 32).clamp(280.0, 320.0) : 320.0;
    final horizontalPadding = isMobile ? 12.0 : 16.0;
    final cellSize =
        isMobile
            ? ((dialogWidth - (horizontalPadding * 2)) / 7).clamp(32.0, 40.0)
            : 40.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 40),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: dialogWidth,
          constraints: const BoxConstraints(maxWidth: 320, minWidth: 280),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 56,
                child: Row(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(left: horizontalPadding),
                      child: Icon(
                        Icons.calendar_month_rounded,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${_getMonthName(_currentMonth.month)} ${_currentMonth.year}',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.chevron_left_rounded),
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
                    if (!isMobile || screenWidth > 350)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _currentMonth = DateTime.now();
                            _selectedDate = DateTime.now();
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 0),
                        ),
                        child: const Text('Today'),
                      ),
                    Padding(
                      padding: EdgeInsets.only(right: 16),
                      child: IconButton(
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
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  0,
                  horizontalPadding,
                  horizontalPadding,
                ),
                child: Column(
                  children: [
                    _buildCalendarGrid(colorScheme, cellSize),
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

  Widget _buildCalendarGrid(ColorScheme colorScheme, double cellSize) {
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
          rowChildren.add(SizedBox(width: cellSize, height: cellSize));
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
              width: cellSize,
              height: cellSize,
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? colorScheme.primaryContainer
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
                                      ? colorScheme.onPrimaryContainer
                                      : colorScheme.onSurface,
                              fontWeight:
                                  isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                              fontSize:
                                  isSelected
                                      ? (cellSize * 0.4)
                                      : (cellSize * 0.35),
                            ),
                          ),
                        ),
                        if (hasEvents)
                          Positioned(
                            bottom: 3,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                width: 4,
                                height: 4,
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
            ),
          );
          currentDay++;
        } else {
          rowChildren.add(SizedBox(width: cellSize, height: cellSize));
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
                        width: cellSize,
                        child: Center(
                          child: Text(
                            day,
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: (cellSize * 0.3).clamp(10.0, 12.0),
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
