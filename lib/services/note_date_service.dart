import '../database/database_helper.dart';
import '../database/models/calendar_event.dart';
import '../database/repositories/calendar_event_repository.dart';

class NoteDateService {
  static final NoteDateService _instance = NoteDateService._internal();
  factory NoteDateService() => _instance;
  NoteDateService._internal();

  late final CalendarEventRepository _calendarEventRepository =
      CalendarEventRepository(DatabaseHelper());

  static final RegExp _dateTagRegex = RegExp(
    r'@date\(\s*([^\)]+?)\s*\)',
    caseSensitive: false,
  );

  Future<void> syncNoteDates({
    required int noteId,
    required String title,
    required String content,
  }) async {
    final targetDates = _extractDates('$title\n$content');
    final existingEvents =
        await _calendarEventRepository.getCalendarEventsByNoteId(noteId);

    if (targetDates.isEmpty) {
      if (existingEvents.isEmpty) return;
      for (final event in existingEvents) {
        await _calendarEventRepository.deleteCalendarEvent(event.id);
      }
      return;
    }

    final Map<String, List<CalendarEvent>> eventsByDate = {};
    for (final event in existingEvents) {
      final key = _dateKey(event.date);
      eventsByDate.putIfAbsent(key, () => []).add(event);
    }

    final targetKeys = targetDates.map(_dateKey).toSet();
    final List<CalendarEvent> eventsToDelete = [];

    for (final entry in eventsByDate.entries) {
      if (!targetKeys.contains(entry.key)) {
        eventsToDelete.addAll(entry.value);
      } else if (entry.value.length > 1) {
        entry.value.sort((a, b) => a.id.compareTo(b.id));
        eventsToDelete.addAll(entry.value.skip(1));
      }
    }

    for (final event in eventsToDelete) {
      await _calendarEventRepository.deleteCalendarEvent(event.id);
    }

    final existingKeys = eventsByDate.keys.toSet();
    final missingDates =
        targetDates.where((date) => !existingKeys.contains(_dateKey(date)));

    if (missingDates.isEmpty) return;

    var nextOrderIndex = await _calendarEventRepository.getNextOrderIndex();
    for (final date in missingDates) {
      final event = CalendarEvent(
        id: 0,
        noteId: noteId,
        date: date,
        orderIndex: nextOrderIndex,
      );
      await _calendarEventRepository.createCalendarEvent(event);
      nextOrderIndex++;
    }
  }

  List<DateTime> _extractDates(String text) {
    if (text.isEmpty) return [];

    final Set<DateTime> results = {};
    for (final match in _dateTagRegex.allMatches(text)) {
      final raw = match.group(1)?.trim();
      if (raw == null || raw.isEmpty) continue;

      final parts = raw.split(RegExp(r'\s*->\s*'));
      if (parts.isEmpty || parts.length > 2) continue;

      final start = _parseDateFlexible(parts[0].trim());
      if (start == null) continue;

      if (parts.length == 1) {
        results.add(_normalizeDate(start));
        continue;
      }

      final end = _parseDateFlexible(parts[1].trim());
      if (end == null) continue;

      var startDate = _normalizeDate(start);
      var endDate = _normalizeDate(end);

      if (endDate.isBefore(startDate)) {
        final temp = startDate;
        startDate = endDate;
        endDate = temp;
      }

      var current = startDate;
      while (!current.isAfter(endDate)) {
        results.add(current);
        current = current.add(const Duration(days: 1));
      }
    }

    final sorted = results.toList()..sort();
    return sorted;
  }

  DateTime? _parseDateFlexible(String raw) {
    if (raw.isEmpty) return null;

    final iso = _parseIsoDate(raw);
    if (iso != null) return iso;

    final slash = _parseSlashDate(raw);
    if (slash != null) return slash;

    final monthName = _parseMonthNameDate(raw);
    if (monthName != null) return monthName;

    return null;
  }

  DateTime? _parseIsoDate(String raw) {
    final parts = raw.split('-');
    if (parts.length != 3) return null;

    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    return _validateDateParts(year, month, day);
  }

  DateTime? _parseSlashDate(String raw) {
    final match = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(raw);
    if (match == null) return null;

    final day = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final year = int.tryParse(match.group(3)!);
    return _validateDateParts(year, month, day);
  }

  DateTime? _parseMonthNameDate(String raw) {
    final dayFirst =
        RegExp(r'^(\d{1,2})\s*,?\s*([A-Za-z]+)\s*(\d{4})$')
            .firstMatch(raw);
    if (dayFirst != null) {
      final day = int.tryParse(dayFirst.group(1)!);
      final monthName = dayFirst.group(2)!.toLowerCase();
      final year = int.tryParse(dayFirst.group(3)!);
      final month = _monthNameToNumber(monthName);
      return _validateDateParts(year, month, day);
    }

    final monthFirst =
        RegExp(r'^([A-Za-z]+)\s*(\d{1,2})\s*,?\s*(\d{4})$')
            .firstMatch(raw);
    if (monthFirst == null) return null;

    final monthName = monthFirst.group(1)!.toLowerCase();
    final day = int.tryParse(monthFirst.group(2)!);
    final year = int.tryParse(monthFirst.group(3)!);
    final month = _monthNameToNumber(monthName);
    return _validateDateParts(year, month, day);
  }

  DateTime? _validateDateParts(int? year, int? month, int? day) {
    if (year == null || month == null || day == null) return null;

    final candidate = DateTime(year, month, day);
    if (candidate.year != year ||
        candidate.month != month ||
        candidate.day != day) {
      return null;
    }

    return candidate;
  }

  int? _monthNameToNumber(String name) {
    const months = {
      'jan': 1,
      'january': 1,
      'feb': 2,
      'february': 2,
      'mar': 3,
      'march': 3,
      'apr': 4,
      'april': 4,
      'may': 5,
      'jun': 6,
      'june': 6,
      'jul': 7,
      'july': 7,
      'aug': 8,
      'august': 8,
      'sep': 9,
      'sept': 9,
      'september': 9,
      'oct': 10,
      'october': 10,
      'nov': 11,
      'november': 11,
      'dec': 12,
      'december': 12,
    };

    return months[name];
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String _dateKey(DateTime date) {
    final normalized = _normalizeDate(date);
    return '${normalized.year}-${normalized.month}-${normalized.day}';
  }
}
