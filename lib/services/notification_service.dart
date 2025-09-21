import 'dart:async';
import '../database/models/note.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _noteUpdateController = StreamController<Note>.broadcast();
  Stream<Note> get noteUpdateStream => _noteUpdateController.stream;

  void notifyNoteUpdate(Note note) {
    _noteUpdateController.add(note);
  }

  void dispose() {
    _noteUpdateController.close();
  }
}
