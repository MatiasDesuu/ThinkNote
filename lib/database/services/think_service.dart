import '../repositories/think_repository.dart';
import '../models/think.dart';
import 'dart:async';

class ThinkService {
  final ThinkRepository _thinkRepository;
  final StreamController<void> _changeController =
      StreamController<void>.broadcast();

  ThinkService(this._thinkRepository);

  Stream<void> get onThinkChanged => _changeController.stream;

  void _notifyChanges() {
    _changeController.add(null);
  }

  Future<Think?> createThink() async {
    final now = DateTime.now();
    final think = Think(
      title: 'New Think',
      content: '',
      createdAt: now,
      updatedAt: now,
    );

    final id = await _thinkRepository.createThink(think);
    _notifyChanges();
    return getThink(id);
  }

  Future<Think?> getThink(int id) async {
    return await _thinkRepository.getThink(id);
  }

  Future<List<Think>> getAllThinks({bool orderByIndex = true}) async {
    return await _thinkRepository.getAllThinks(orderByIndex: orderByIndex);
  }

  Future<bool> updateThink(Think think) async {
    final now = DateTime.now();
    final updatedThink = think.copyWith(updatedAt: now);

    final result = await _thinkRepository.updateThink(updatedThink);
    _notifyChanges();
    return result > 0;
  }

  Future<bool> deleteThink(int id) async {
    final result = await _thinkRepository.deleteThink(id);
    _notifyChanges();
    return result > 0;
  }

  Future<void> reorderThinks(List<Think> thinks) async {
    await _thinkRepository.reorderThinks(thinks);
    _notifyChanges();
  }

  Future<List<Think>> getFavoriteThinks() async {
    return await _thinkRepository.getFavoriteThinks();
  }

  Future<bool> toggleFavorite(int id, bool isFavorite) async {
    final result = await _thinkRepository.toggleFavorite(id, isFavorite);
    _notifyChanges();
    return result > 0;
  }

  Future<List<Think>> searchThinks(String query) async {
    return await _thinkRepository.searchThinks(query);
  }

  Future<List<Think>> getDeletedThinks() async {
    return await _thinkRepository.getDeletedThinks();
  }

  Future<bool> restoreThink(int id) async {
    final result = await _thinkRepository.restoreThink(id);
    _notifyChanges();
    return result > 0;
  }

  Future<bool> permanentlyDeleteThink(int id) async {
    final result = await _thinkRepository.permanentlyDeleteThink(id);
    _notifyChanges();
    return result > 0;
  }

  void dispose() {
    _changeController.close();
  }
}
