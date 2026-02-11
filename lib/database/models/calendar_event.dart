import '../database_config.dart';
import 'note.dart';

class CalendarEvent {
  final int id;
  final int noteId;
  final Note? note;
  final DateTime date;
  final int orderIndex;
  final String? status;

  const CalendarEvent({
    required this.id,
    required this.noteId,
    this.note,
    required this.date,
    required this.orderIndex,
    this.status,
  });

  factory CalendarEvent.fromMap(Map<String, dynamic> map) {
    return CalendarEvent(
      id: map[DatabaseConfig.columnCalendarEventId] as int,
      noteId: map[DatabaseConfig.columnCalendarEventNoteId] as int,
      note: null,
      date: DateTime.fromMillisecondsSinceEpoch(
        map[DatabaseConfig.columnCalendarEventDate] as int,
      ),
      orderIndex: map[DatabaseConfig.columnCalendarEventOrderIndex] as int,
      status: map[DatabaseConfig.columnCalendarEventStatus] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      DatabaseConfig.columnCalendarEventId: id,
      DatabaseConfig.columnCalendarEventNoteId: noteId,
      DatabaseConfig.columnCalendarEventDate: date.millisecondsSinceEpoch,
      DatabaseConfig.columnCalendarEventOrderIndex: orderIndex,
      DatabaseConfig.columnCalendarEventStatus: status,
    };
  }

  CalendarEvent copyWith({
    int? id,
    int? noteId,
    Note? note,
    DateTime? date,
    int? orderIndex,
    String? status,
    bool clearStatus = false,
  }) {
    String? finalStatus;
    if (clearStatus) {
      finalStatus = null;
    } else if (status != null) {
      finalStatus = status;
    } else {
      finalStatus = this.status;
    }

    return CalendarEvent(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      note: note ?? this.note,
      date: date ?? this.date,
      orderIndex: orderIndex ?? this.orderIndex,
      status: finalStatus,
    );
  }
}
