import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_service.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../core/glass_widgets.dart';


class TimelineScreen extends StatefulWidget {
  final String programId;
  TimelineScreen({super.key, required this.programId});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  // Data
  List<ProgramDay> _days = [];
  Set<String> _completedIds = {};
  bool _isLoading = true;
  String _programTitle = "Loading..."; 
  String _programDesc = "";
  String? _programImage;

  @override
  void initState() {
    super.initState();
    _fetchSchedule();
  }

  Future<void> _fetchSchedule() async {
    try {
      // 1. Fetch Program Details
      final programData = await Supabase.instance.client
          .from('programs')
          .select('title, description, image_url')
          .eq('id', widget.programId)
          .single();

      // 2. Fetch Schedule
      final days = await SupabaseService().fetchProgramDays(widget.programId);
      final completed = await SupabaseService().fetchCompletedWorkoutIds();

      if (mounted) {
        setState(() {
          _days = days;
          _programTitle = programData['title'];
          _completedIds = completed;
          _programDesc = programData['description'] ?? "";
          final image = programData['image_url']?.toString();
          _programImage = (image != null && image.trim().isNotEmpty) ? image : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading program timeline: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: GlassPage(child: Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: GlassPage(
        child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            floating: false,
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                _programTitle,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (_programImage != null)
                    CachedNetworkImage(
                      imageUrl: _programImage!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(color: Theme.of(context).colorScheme.surface),
                      errorWidget: (_, _, _) => Container(color: Theme.of(context).colorScheme.surface),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.surface,
                          ],
                        ),
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, AppTheme.background.withOpacity(0.9)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                _programDesc,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final day = _days[index];
                bool isNewWeek = index == 0;
                int displayWeek = day.weekNumber;
                if (displayWeek == 0) displayWeek = ((day.dayNumber - 1) / 7).floor() + 1;
                if (index > 0) {
                  final prevDay = _days[index - 1];
                  int currentWeek = ((day.dayNumber - 1) / 7).floor() + 1;
                  int prevWeek = ((prevDay.dayNumber - 1) / 7).floor() + 1;
                  if (currentWeek != prevWeek) isNewWeek = true;
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isNewWeek)
                      Padding(
                        padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 18,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              "WEEK $displayWeek",
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    _buildDayCard(day),
                  ],
                );
              },
              childCount: _days.length,
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 48)),
        ],
        ),
      ),
    );
  }

  Widget _buildDayCard(ProgramDay day) {
    bool isRest = day.isRestDay;
    bool hasWorkouts = day.workoutIds.isNotEmpty;
    bool hasMultiple = day.workoutIds.length > 1;
    bool isComplete = !isRest &&
        hasWorkouts &&
        day.workoutIds.every((id) => _completedIds.contains(id));

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: isComplete
            ? Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.6), width: 2)
            : (isRest ? Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.3)) : null),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isRest ? Colors.transparent : Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: isRest ? Border.all(color: Theme.of(context).colorScheme.outline) : null,
                ),
                child: Center(
                  child: Icon(
                    isRest ? Icons.nightlight_round_rounded
                        : (isComplete ? Icons.check_rounded : (day.isPremium ? Icons.lock_rounded : Icons.play_arrow_rounded)),
                    color: isRest ? Theme.of(context).colorScheme.outline : (day.isPremium ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.primary),
                    size: 26,
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Day ${day.dayNumber}",
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: isRest ? Theme.of(context).colorScheme.outline : Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      isRest ? "Rest Day" : day.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: isComplete ? Theme.of(context).colorScheme.outline : Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        decoration: isComplete ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (!isRest && hasMultiple)
                      Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          "${day.workoutIds.length} videos",
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (!isRest && !isComplete && !hasMultiple)
                IconButton(
                  icon: Icon(Icons.arrow_forward_ios_rounded, color: Theme.of(context).colorScheme.outline, size: 14),
                  onPressed: () async => _openWorkout(day.workoutIds.first),
                ),
            ],
          ),
          if (!isRest && !hasWorkouts)
            Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text("No workout assigned yet.", style: TextStyle(color: Theme.of(context).colorScheme.outline)),
            ),
          if (!isRest && hasMultiple) ...[
            SizedBox(height: 14),
            _buildWorkoutTimeline(day),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkoutTimeline(ProgramDay day) {
    return Column(
      children: [
        for (int i = 0; i < day.workoutIds.length; i++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _completedIds.contains(day.workoutIds[i]) ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline,
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (i != day.workoutIds.length - 1)
                    Container(
                      width: 2,
                      height: 36,
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.35),
                    ),
                ],
              ),
              SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () async => _openWorkout(day.workoutIds[i]),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _completedIds.contains(day.workoutIds[i])
                                ? Icons.check_circle_rounded
                                : (day.workouts.length > i && day.workouts[i].isPremium
                                    ? Icons.lock_rounded
                                    : Icons.play_arrow_rounded),
                            color: _completedIds.contains(day.workoutIds[i]) ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              day.workouts.length > i ? day.workouts[i].title : "Workout ${i + 1}",
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Theme.of(context).colorScheme.outline),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _openWorkout(String workoutId) async {
    await context.push('/workout/$workoutId');
    if (mounted) {
      _fetchSchedule();
    }
  }
}
