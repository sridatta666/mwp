import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models.dart';

class SupabaseService {
  final _client = Supabase.instance.client;
  final _cache = Hive.box('cache');









// --- NEW: FETCH LISTS FOR HOME SCREEN ---

  // 1. Get the latest 5 workouts (for the "New Releases" row)
  Future<List<Workout>> fetchRecentWorkouts() async {
    final rawData = await _fetchWithCache('recent_workouts', () async {
      return await _client
          .from('workouts')
          .select()
          .order('created_at', ascending: false)
          .limit(5);
    });

    return rawData.map((e) => Workout.fromJson(_cast(e))).toList();
  }

  // 1b. Get ALL workouts
  Future<List<Workout>> fetchAllWorkouts() async {
    final rawData = await _fetchWithCache('all_workouts', () async {
      return await _client
          .from('workouts')
          .select()
          .order('created_at', ascending: false);
    });

    return rawData.map((e) => Workout.fromJson(_cast(e))).toList();
  }

  
  
  // 3. Get the "Featured" Program (The big banner at the top)
  Future<Program?> fetchFeaturedProgram() async {
    final rawData = await _fetchSingleWithCache('featured_program', () async {
      return await _client
          .from('programs')
          .select()
          .limit(1)
          .maybeSingle();
    });

    if (rawData == null) return null;
    return Program.fromJson(_cast(rawData));
  }


  // --- HELPER 1: Cast Hive Data safely to JSON ---
  // This fixes the "type '_Map<dynamic, dynamic>' is not a subtype of type 'Map<String, dynamic>'" error
  Map<String, dynamic> _cast(dynamic item) {
    return Map<String, dynamic>.from(item as Map);
  }

  // --- HELPER 2: Network First, Cache Fallback (List) ---
  Future<List<dynamic>> _fetchWithCache(String key, Future<List<dynamic>> Function() networkCall) async {
    try {
      // 1. Try Network
      final data = await networkCall();
      
      // 2. Save to Cache
      await _cache.put(key, data);
      print("🌐 Fetched & Cached List: $key");
      
      return data;
    } catch (e) {
      // 3. Fallback to Cache
      print("⚠️ Network failed ($e). Checking Cache for: $key");
      
      if (_cache.containsKey(key)) {
        print("📂 Loaded List from Cache: $key");
        return List<dynamic>.from(_cache.get(key));
      } else {
        throw Exception("No Internet and no cached data found for $key");
      }
    }
  }

  // --- HELPER 3: Network First, Cache Fallback (Single Item) ---
  Future<dynamic> _fetchSingleWithCache(String key, Future<dynamic> Function() networkCall) async {
    try {
      final data = await networkCall();
      if (data != null) {
        await _cache.put(key, data);
        print("🌐 Fetched & Cached Single: $key");
      }
      return data;
    } catch (e) {
      print("⚠️ Network failed ($e). Checking Cache for: $key");
      if (_cache.containsKey(key)) {
        print("📂 Loaded Single from Cache: $key");
        return _cache.get(key);
      } else {
        // If it's a critical fetch, we might want to throw, but for optional UI elements, maybe return null?
        // But throwing allows the caller to know it failed.
        // For fetchFeaturedProgram, returning null is okay (UI handles null).
        // But rethrow is safer to let caller decide.
        // However, standardizing on Exception for consistency.
        if (key == 'featured_program') return null; // Special case: Optional
        throw Exception("No Internet and no cached data found for $key");
      }
    }
  }

  // 1. Fetch Programs
  Future<List<Program>> fetchAllPrograms() async {
    final rawData = await _fetchWithCache('all_programs', () async {
      return await _client.from('programs').select().order('created_at', ascending: false);
    });
    
    // USE _cast HERE
    return rawData.map((item) => Program.fromJson(_cast(item))).toList();
  }

  // 2. Fetch Days
  Future<List<ProgramDay>> fetchProgramDays(String programId) async {
    final rawData = await _fetchWithCache('days_$programId', () async {
      return await _client
          .from('program_days')
          .select()
          .eq('program_id', programId)
          .order('day_number', ascending: true);
    });

    final daysJson = rawData.map((item) => _cast(item)).toList();

    final workoutIds = <String>{};
    for (final day in daysJson) {
      final list = day['workout_ids'];
      if (list is List) {
        for (final entry in list) {
          if (entry != null) workoutIds.add(entry.toString());
        }
      } else if (day['workout_id'] != null) {
        // Backward compatibility with old schema.
        workoutIds.add(day['workout_id'].toString());
      }
    }

    final workoutLookup = <String, DayWorkoutItem>{};
    if (workoutIds.isNotEmpty) {
      final workoutRows = await _client
          .from('workouts')
          .select('id, title, is_premium')
          .inFilter('id', workoutIds.toList());
      for (final row in (workoutRows as List)) {
        final item = _cast(row);
        final id = item['id']?.toString();
        if (id == null) continue;
        workoutLookup[id] = DayWorkoutItem(
          id: id,
          title: item['title']?.toString() ?? 'Workout',
          isPremium: item['is_premium'] == true,
        );
      }
    }

    return daysJson
        .map((item) => ProgramDay.fromJson(item, workoutLookup: workoutLookup))
        .toList();
  }

  // 3. Fetch Workout Details
  Future<Workout> fetchWorkoutDetails(String workoutId) async {
    final rawData = await _fetchSingleWithCache('workout_$workoutId', () async {
      return await _client
          .from('workouts')
          .select()
          .eq('id', workoutId)
          .single();
    });

    if (rawData == null) throw Exception("Workout not found");
    return Workout.fromJson(_cast(rawData));
  }
   

  // 4. Mark Complete (Online Only for MVP)
 Future<void> markWorkoutComplete(String workoutId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return; // Guard: User must be logged in

    try {
      await _client.from('user_progress').insert({
        'user_id': userId,
        'workout_id': workoutId,
        'completed_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print("Error marking complete: $e");
      // Optional: Ignore duplicate key errors if user clicks twice
    }
  }
 Future<Set<String>> fetchCompletedWorkoutIds() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return {};

    final response = await _client
        .from('user_progress')
        .select('workout_id')
        .eq('user_id', userId);

    final List<dynamic> data = response as List;
    // Convert to a Set for fast lookup (O(1) complexity)
    return data.map((e) => e['workout_id'] as String).toSet();
  }

  // 5. Check Subscription Status
  Future<bool> isUserPremium() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    try {
      // Check 'profiles' table for 'is_premium' flag
      final data = await _client
          .from('profiles')
          .select('is_premium')
          .eq('id', user.id)
          .maybeSingle();

      if (data == null) return false;
      return data['is_premium'] == true;
    } catch (e) {
      print("Error checking premium status: $e");
      return false; 
    }
  }

  // 6. Check Admin Status
  Future<bool> isUserAdmin() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      print("⚠️ Admin Check Failed: No User Logged In");
      return false;
    }

    try {
      final data = await _client
          .from('profiles')
          .select('is_admin')
          .eq('id', user.id)
          .maybeSingle();

      if (data == null) {
        print("⚠️ Admin Check Failed: No profile found for user ${user.id}. Run backfill SQL.");
        return false;
      }
      
      final isAdmin = data['is_admin'] == true;
      print("✅ Admin Check: User is ${isAdmin ? 'ADMIN' : 'NOT Admin'}");
      return isAdmin;
    } catch (e) {
      print("❌ Admin Check Error: $e");
      return false; 
    }
  }

  // 8. Workout history (completed workouts with date)
  Future<List<WorkoutHistoryEntry>> fetchWorkoutHistory({int limit = 50}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final progress = await _client
          .from('user_progress')
          .select('workout_id, completed_at')
          .eq('user_id', userId)
          .order('completed_at', ascending: false)
          .limit(limit);
      final List<dynamic> list = progress as List;
      if (list.isEmpty) return [];

      final workoutIds = list.map((e) => e['workout_id'] as String).toSet().toList();
      final workouts = <String, String>{};
      for (final id in workoutIds) {
        try {
          final w = await _client.from('workouts').select('title').eq('id', id).maybeSingle();
          if (w != null) workouts[id] = w['title'] as String? ?? 'Workout';
        } catch (_) {}
      }
      return list.map((e) {
        final id = e['workout_id'] as String;
        final at = DateTime.parse(e['completed_at'] as String);
        return WorkoutHistoryEntry(
          workoutId: id,
          title: workouts[id] ?? 'Workout',
          completedAt: at,
        );
      }).toList();
    } catch (e) {
      print("Error fetching workout history: $e");
      return [];
    }
  }

  // 9. Progress stats (total and this week)
  Future<Map<String, int>> fetchProgressStats() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return {'total': 0, 'thisWeek': 0};

    try {
      final progress = await _client
          .from('user_progress')
          .select('completed_at')
          .eq('user_id', userId);
      final List<dynamic> list = progress as List;
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      int thisWeek = 0;
      for (final e in list) {
        final at = DateTime.parse(e['completed_at'] as String);
        if (at.isAfter(weekStart) || at.isAtSameMomentAs(weekStart)) thisWeek++;
      }
      return {'total': list.length, 'thisWeek': thisWeek};
    } catch (e) {
      print("Error fetching progress stats: $e");
      return {'total': 0, 'thisWeek': 0};
    }
  }

  // 7. Save Clip Log
  Future<void> saveClipLog({
    required String programId,
    required int clipIndex,
    required String clipTitle,
    required int sets,
    required int reps,
    required int durationSeconds,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      await _client.from('clip_logs').insert({
        'user_id': user.id,
        'program_id': programId,
        'clip_index': clipIndex,
        'clip_title': clipTitle,
        'sets': sets,
        'reps': reps,
        'duration_seconds': durationSeconds,
        'created_at': DateTime.now().toIso8601String(),
      });
      print("✅ Log Saved: $clipTitle");
    } catch (e) {
      print("❌ Error saving log: $e");
      // Don't rethrow to avoid blocking the user flow, just log it.
    }
  }
}
