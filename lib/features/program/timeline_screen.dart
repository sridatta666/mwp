import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_service.dart';
import '../../core/models.dart';
import '../../core/theme.dart';


class TimelineScreen extends StatefulWidget {
  final String programId;
  const TimelineScreen({super.key, required this.programId});

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
          .select('title, description') 
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
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            floating: false,
            pinned: true,
            backgroundColor: AppTheme.background,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                _programTitle,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
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
                      placeholder: (_, __) => Container(color: AppTheme.surface),
                      errorWidget: (_, __, ___) => Container(color: AppTheme.surface),
                    )
                  else
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.primary,
                            AppTheme.surface,
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                _programDesc,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
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
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 18,
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              "WEEK $displayWeek",
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppTheme.textPrimary,
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
          const SliverToBoxAdapter(child: SizedBox(height: 48)),
        ],
      ),
    );
  }

  Widget _buildDayCard(ProgramDay day) {
    bool isRest = day.isRestDay;
    bool hasWorkouts = day.workoutIds.isNotEmpty;
    bool isComplete = !isRest &&
        hasWorkouts &&
        day.workoutIds.every((id) => _completedIds.contains(id));

    return GestureDetector(
      onTap: () async {
        if (isRest) return;
        if (!hasWorkouts) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No workout assigned yet.")));
          return;
        }
        if (day.workoutIds.length == 1) {
          await context.push('/workout/${day.workoutIds.first}');
        } else {
          await _showDayWorkoutPicker(day);
        }
        _fetchSchedule();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(18),
          border: isComplete
              ? Border.all(color: AppTheme.primary.withOpacity(0.6), width: 2)
              : (isRest ? Border.all(color: AppTheme.textMuted.withOpacity(0.3)) : null),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isRest ? Colors.transparent : AppTheme.primary.withOpacity(0.2),
                shape: BoxShape.circle,
                border: isRest ? Border.all(color: AppTheme.textMuted) : null,
              ),
              child: Center(
                child: Icon(
                  isRest ? Icons.nightlight_round_rounded
                      : (isComplete ? Icons.check_rounded : (day.isPremium ? Icons.lock_rounded : Icons.play_arrow_rounded)),
                  color: isRest ? AppTheme.textMuted : (day.isPremium ? AppTheme.accent : AppTheme.primary),
                  size: 26,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Day ${day.dayNumber}",
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: isRest ? AppTheme.textMuted : AppTheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isRest ? "Rest Day" : day.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: isComplete ? AppTheme.textMuted : AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      decoration: isComplete ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (!isRest && day.workoutIds.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        "${day.workoutIds.length} videos",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (!isRest && !isComplete)
              Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.textMuted, size: 14),
          ],
        ),
      ),
    );
  }

  Future<void> _showDayWorkoutPicker(ProgramDay day) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final items = day.workouts;
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: Text(
                  "Day ${day.dayNumber} workouts",
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
                ),
              ),
              for (int i = 0; i < day.workoutIds.length; i++)
                ListTile(
                  leading: Icon(
                    items.length > i && items[i].isPremium ? Icons.lock_rounded : Icons.play_arrow_rounded,
                    color: items.length > i && items[i].isPremium ? AppTheme.accent : AppTheme.primary,
                  ),
                  title: Text(
                    items.length > i ? items[i].title : "Workout ${i + 1}",
                    style: const TextStyle(color: AppTheme.textPrimary),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textMuted),
                  onTap: () async {
                    Navigator.pop(context);
                    await this.context.push('/workout/${day.workoutIds[i]}');
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
