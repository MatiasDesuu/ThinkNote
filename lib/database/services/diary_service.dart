import 'dart:async';
import '../repositories/diary_repository.dart';
import '../models/diary_entry.dart';

class DiaryService {
  final DiaryRepository _diaryRepository;
  final StreamController<void> _diaryChangesController =
      StreamController<void>.broadcast();

  DiaryService(this._diaryRepository);

  Stream<void> get onDiaryChanged => _diaryChangesController.stream;

  Future<DiaryEntry?> createDiaryEntry(DateTime date) async {
    try {
      final entry = DiaryEntry(
        content: '',
        date: date,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final id = await _diaryRepository.createDiaryEntry(entry);
      final createdEntry = await _diaryRepository.getDiaryEntry(id);

      _diaryChangesController.add(null);
      return createdEntry;
    } catch (e) {
      print('Error creating diary entry: $e');
      rethrow;
    }
  }

  Future<DiaryEntry?> getDiaryEntry(int id) async {
    try {
      return await _diaryRepository.getDiaryEntry(id);
    } catch (e) {
      print('Error getting diary entry: $e');
      rethrow;
    }
  }

  Future<DiaryEntry?> getDiaryEntryByDate(DateTime date) async {
    try {
      return await _diaryRepository.getDiaryEntryByDate(date);
    } catch (e) {
      print('Error getting diary entry by date: $e');
      rethrow;
    }
  }

  Future<List<DiaryEntry>> getAllDiaryEntries() async {
    try {
      return await _diaryRepository.getAllDiaryEntries();
    } catch (e) {
      print('Error getting all diary entries: $e');
      rethrow;
    }
  }

  Future<List<DiaryEntry>> getDiaryEntriesByMonth(int year, int month) async {
    try {
      return await _diaryRepository.getDiaryEntriesByMonth(year, month);
    } catch (e) {
      print('Error getting diary entries by month: $e');
      rethrow;
    }
  }

  Future<int> updateDiaryEntry(DiaryEntry entry) async {
    try {
      final updatedEntry = entry.copyWith(updatedAt: DateTime.now());
      final result = await _diaryRepository.updateDiaryEntry(updatedEntry);
      _diaryChangesController.add(null);
      return result;
    } catch (e) {
      print('Error updating diary entry: $e');
      rethrow;
    }
  }

  Future<int> deleteDiaryEntry(int id) async {
    try {
      final result = await _diaryRepository.deleteDiaryEntry(id);
      _diaryChangesController.add(null);
      return result;
    } catch (e) {
      print('Error deleting diary entry: $e');
      rethrow;
    }
  }

  Future<int> permanentlyDeleteDiaryEntry(int id) async {
    try {
      final result = await _diaryRepository.permanentlyDeleteDiaryEntry(id);
      _diaryChangesController.add(null);
      return result;
    } catch (e) {
      print('Error permanently deleting diary entry: $e');
      rethrow;
    }
  }

  Future<List<DiaryEntry>> getDeletedDiaryEntries() async {
    try {
      return await _diaryRepository.getDeletedDiaryEntries();
    } catch (e) {
      print('Error getting deleted diary entries: $e');
      rethrow;
    }
  }

  Future<int> restoreDiaryEntry(int id) async {
    try {
      final result = await _diaryRepository.restoreDiaryEntry(id);
      _diaryChangesController.add(null);
      return result;
    } catch (e) {
      print('Error restoring diary entry: $e');
      rethrow;
    }
  }

  void dispose() {
    _diaryChangesController.close();
  }
}
