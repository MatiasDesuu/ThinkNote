import '../database_config.dart';

class CalendarEventStatus {
  final int id;
  final String name;
  final String color;
  final int orderIndex;

  const CalendarEventStatus({
    required this.id,
    required this.name,
    required this.color,
    required this.orderIndex,
  });

  factory CalendarEventStatus.fromMap(Map<String, dynamic> map) {
    return CalendarEventStatus(
      id: map[DatabaseConfig.columnCalendarEventStatusId] as int,
      name: map[DatabaseConfig.columnCalendarEventStatusName] as String,
      color: map[DatabaseConfig.columnCalendarEventStatusColor] as String,
      orderIndex:
          map[DatabaseConfig.columnCalendarEventStatusOrderIndex] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      DatabaseConfig.columnCalendarEventStatusId: id,
      DatabaseConfig.columnCalendarEventStatusName: name,
      DatabaseConfig.columnCalendarEventStatusColor: color,
      DatabaseConfig.columnCalendarEventStatusOrderIndex: orderIndex,
    };
  }

  CalendarEventStatus copyWith({
    int? id,
    String? name,
    String? color,
    int? orderIndex,
  }) {
    return CalendarEventStatus(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }
}
