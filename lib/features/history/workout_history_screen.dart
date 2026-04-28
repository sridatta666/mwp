import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/supabase_service.dart';
import '../../core/models.dart';
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
    if (mounted) {
      setState(() {
      _entries = list;
      _isLoading = false;
    });
    }
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
          ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
          : _entries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fitness_center_rounded, size: 64, color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 16),
                      Text(
                        'No workouts completed yet',
                        style: theme.textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Complete a workout to see it here',
                        style: theme.textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: Theme.of(context).colorScheme.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _entries.length,
                    itemBuilder: (_, i) {
                      final e = _entries[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                            child: Icon(Icons.check_rounded, color: Theme.of(context).colorScheme.primary),
                          ),
                          title: Text(
                            e.title,
                            style: theme.textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.onSurface),
                          ),
                          subtitle: Text(
                            '${_formatDate(e.completedAt)} · ${_formatTime(e.completedAt)}',
                            style: theme.textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
                          ),
                          trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Theme.of(context).colorScheme.outline),
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
