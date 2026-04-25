import 'package:hive_flutter/hive_flutter.dart';

/// Local favorites (workouts and programs) stored in Hive.
class FavoritesService {
  static const _boxName = 'favorites';
  static const _workoutPrefix = 'w_';
  static const _programPrefix = 'p_';

  Box get _box => Hive.box(_boxName);

  Set<String> getFavoriteWorkoutIds() {
    return _box.keys
        .whereType<String>()
        .where((k) => k.startsWith(_workoutPrefix))
        .map((k) => k.substring(_workoutPrefix.length))
        .toSet();
  }

  Set<String> getFavoriteProgramIds() {
    return _box.keys
        .whereType<String>()
        .where((k) => k.startsWith(_programPrefix))
        .map((k) => k.substring(_programPrefix.length))
        .toSet();
  }

  bool isWorkoutFavorite(String workoutId) => _box.containsKey(_workoutPrefix + workoutId);
  bool isProgramFavorite(String programId) => _box.containsKey(_programPrefix + programId);

  Future<void> toggleWorkoutFavorite(String workoutId) async {
    final key = _workoutPrefix + workoutId;
    if (_box.containsKey(key)) {
      await _box.delete(key);
    } else {
      await _box.put(key, workoutId);
    }
  }

  Future<void> toggleProgramFavorite(String programId) async {
    final key = _programPrefix + programId;
    if (_box.containsKey(key)) {
      await _box.delete(key);
    } else {
      await _box.put(key, programId);
    }
  }
}
