class Program {
  final String id;
  final String title;
  final String description;
  final int totalWeeks;
  final String difficulty;
  final String? imageUrl; // Added for thumbnails
  final String type; // 'standard' or 'sequence'
  final List<WorkoutClip> clips;

  Program({
    required this.id,
    required this.title,
    required this.description,
    required this.totalWeeks,
    required this.difficulty,
    this.imageUrl,
    this.type = 'standard',
    this.clips = const [],
  });

  factory Program.fromJson(Map<String, dynamic> json) {
    List<WorkoutClip> parsedClips = [];
    if (json['clips'] != null) {
      final list = json['clips'] as List;
      parsedClips = list.map((i) => WorkoutClip.fromJson(i)).toList();
    }
    return Program(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      totalWeeks: json['total_weeks'] ?? 4,
      difficulty: json['difficulty_level'] ?? 'All Levels',
      imageUrl: json['image_url'],
      type: json['type'] ?? 'standard',
      clips: parsedClips,
    );
  }
}

class ProgramDay {
  final String id;
  final int dayNumber;
  final int weekNumber;
  final List<String> workoutIds;
  final bool isRestDay;
  final List<DayWorkoutItem> workouts;

  ProgramDay({
    required this.id,
    required this.dayNumber,
    required this.weekNumber,
    this.workoutIds = const [],
    required this.isRestDay,
    this.workouts = const [],
  });

  String get title {
    if (isRestDay) return "Rest Day";
    if (workouts.isNotEmpty) {
      if (workouts.length == 1) return workouts.first.title;
      return "${workouts.length} workouts";
    }
    if (workoutIds.length == 1) return "Workout";
    return "${workoutIds.length} workouts";
  }

  bool get isPremium {
    return workouts.any((w) => w.isPremium);
  }

  factory ProgramDay.fromJson(
    Map<String, dynamic> json, {
    Map<String, DayWorkoutItem>? workoutLookup,
  }) {
    final List<String> ids = [];

    // New schema: an array of workout IDs per day.
    if (json['workout_ids'] is List) {
      for (final entry in (json['workout_ids'] as List)) {
        if (entry != null) ids.add(entry.toString());
      }
    }

    // Backward compatibility: existing rows with a single workout_id.
    if (ids.isEmpty && json['workout_id'] != null) {
      ids.add(json['workout_id'].toString());
    }

    final mappedWorkouts = <DayWorkoutItem>[];
    if (workoutLookup != null) {
      for (final id in ids) {
        final item = workoutLookup[id];
        if (item != null) mappedWorkouts.add(item);
      }
    }

    return ProgramDay(
      id: json['id'],
      dayNumber: json['day_number'],
      weekNumber: json['week_number'] ?? 1,
      workoutIds: ids,
      isRestDay: json['is_rest_day'] ?? false,
      workouts: mappedWorkouts,
    );
  }
}

class DayWorkoutItem {
  final String id;
  final String title;
  final bool isPremium;

  DayWorkoutItem({
    required this.id,
    required this.title,
    required this.isPremium,
  });
}

class WorkoutClip {
  final String videoId;
  final String title;
  final int restDuration; // Rest AFTER this clip (seconds)

  WorkoutClip({
    required this.videoId,
    required this.title,
    this.restDuration = 0,
  });

  factory WorkoutClip.fromJson(Map<String, dynamic> json) {
    return WorkoutClip(
      videoId: json['video_id'],
      title: json['title'] ?? 'Clip',
      restDuration: json['rest_duration'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'video_id': videoId,
    'title': title,
    'rest_duration': restDuration,
  };
}

/// A single completed workout record for history/activity.
class WorkoutHistoryEntry {
  final String workoutId;
  final String title;
  final DateTime completedAt;

  WorkoutHistoryEntry({
    required this.workoutId,
    required this.title,
    required this.completedAt,
  });
}

class Workout {
  final String id;
  final String title;
  final String description;
  
  // ✅ THE NEW CORE FIELDS (Netflix Style)
  final String videoId;  // Bunny.net Video ID (Main video or empty for sequence)
  final int duration;    // e.g. 20 (minutes)
  final String difficulty; // e.g. "Intermediate"
  final bool isPremium;    // Monetization Flag
  
  // New Fields for Sequences
  final String type; // 'standard' or 'sequence'
  final List<WorkoutClip> clips;

  Workout({
    required this.id,
    required this.title,
    required this.description,
    required this.videoId,
    required this.duration,
    required this.difficulty,
    required this.isPremium,
    this.type = 'standard',
    this.clips = const [],
  });

  factory Workout.fromJson(Map<String, dynamic> json) {
    List<WorkoutClip> parsedClips = [];
    if (json['clips'] != null) {
      // If stored as JSONB in Supabase
      final list = json['clips'] as List;
      parsedClips = list.map((i) => WorkoutClip.fromJson(i)).toList();
    }

    return Workout(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      // Map database columns to our clean class
      videoId: json['video_id'] ?? '', 
      duration: json['duration'] ?? 15,
      difficulty: json['difficulty'] ?? 'Beginner',
      isPremium: json['is_premium'] ?? false,
      type: json['type'] ?? 'standard',
      clips: parsedClips,
    );
  }
}
