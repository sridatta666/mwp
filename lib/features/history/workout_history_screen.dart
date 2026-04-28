import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/supabase_service.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../core/glass_widgets.dart';

class WorkoutHistoryScreen extends StatefulWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  State<WorkoutHistoryScreen> createState() => _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends State<WorkoutHistoryScreen> {
  List<WorkoutHistoryEntry> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final list = await SupabaseService().fetchWorkoutHistory();
    if (mounted) setState(() {
      _entries = list;
      _isLoading = false;
    });
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(d.year, d.month, d.day);
    if (date == today) return 'Today';
    final yesterday = today.subtract(const Duration(days: 1));
    if (date == yesterday) return 'Yesterday';
    return '${d.day}/${d.month}/${d.year}';
  }

  String _formatTime(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Workout history'),
        backgroundColor: Colors.transparent,
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => _load(),
            ),
        ],
      ),
      body: GlassPage(
        child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _entries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fitness_center_rounded, size: 64, color: AppTheme.textMuted),
                      const SizedBox(height: 16),
                      Text(
                        'No workouts completed yet',
                        style: theme.textTheme.titleMedium?.copyWith(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Complete a workout to see it here',
                        style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _entries.length,
                    itemBuilder: (_, i) {
                      final e = _entries[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        color: AppTheme.surfaceVariant,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primary.withOpacity(0.2),
                            child: const Icon(Icons.check_rounded, color: AppTheme.primary),
                          ),
                          title: Text(
                            e.title,
                            style: theme.textTheme.titleSmall?.copyWith(color: AppTheme.textPrimary),
                          ),
                          subtitle: Text(
                            '${_formatDate(e.completedAt)} · ${_formatTime(e.completedAt)}',
                            style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textMuted),
                          onTap: () => context.push('/workout/${e.workoutId}'),
                        ),
                      );
                    },
                  ),
                ),
      ),
    );
  }
}
