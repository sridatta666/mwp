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
  final String? workoutId;
  final bool isRestDay;
  final String title;
  final bool isPremium; // From joined workout

  ProgramDay({
    required this.id,
    required this.dayNumber,
    required this.weekNumber,
    this.workoutId,
    required this.isRestDay,
    required this.title,
    this.isPremium = false,
  });

  factory ProgramDay.fromJson(Map<String, dynamic> json) {
    String displayTitle = "Workout";
    bool premium = false;

    // If the joined 'workouts' table exists
    if (json['workouts'] != null) {
      displayTitle = json['workouts']['title'] ?? "Workout";
      premium = json['workouts']['is_premium'] ?? false;
    }
    
    // Override if day has specific title (rare)
   if (json['title'] != null && json['title'].toString().isNotEmpty) {
      displayTitle = json['title'];
    }

    return ProgramDay(
      id: json['id'],
      dayNumber: json['day_number'],
      weekNumber: json['week_number'] ?? 1,
      workoutId: json['workout_id'], 
      isRestDay: json['is_rest_day'] ?? false,
      title: displayTitle,
      isPremium: premium,
    );
  }
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
