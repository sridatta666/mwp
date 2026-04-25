import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../core/models.dart';
import '../../core/supabase_service.dart';
import '../../core/theme.dart';

class ProgramManagerScreen extends StatefulWidget {
  const ProgramManagerScreen({super.key});

  @override
  State<ProgramManagerScreen> createState() => _ProgramManagerScreenState();
}

class _ProgramManagerScreenState extends State<ProgramManagerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // State
  List<Program> _programs = [];
  List<Workout> _workouts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkAccess();
    _fetchData();
  }

  Future<void> _checkAccess() async {
    final isAdmin = await SupabaseService().isUserAdmin();
    if (!isAdmin) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Access Denied: Admins Only")));
        Navigator.pop(context);
      }
    }
  }

  Future<void> _fetchData() async {
    try {
      // Fetch Programs
      final progResponse = await Supabase.instance.client
          .from('programs')
          .select()
          .order('created_at', ascending: false);
      
      // Fetch Workouts
      final workResponse = await Supabase.instance.client
          .from('workouts')
          .select()
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _programs = (progResponse as List).map((e) => Program.fromJson(e)).toList();
          _workouts = (workResponse as List).map((e) => Workout.fromJson(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print("Error: $e");
    }
  }

  // --- ACTIONS ---

  void _handleAdd() {
    if (_tabController.index == 0) {
      _createProgram();
    } else {
      context.push('/admin').then((_) => _fetchData()); // Refresh after return
    }
  }

  Future<void> _deleteProgram(String id) async {
    final confirm = await _showConfirmDialog("Delete Program?", "This cannot be undone.");
    if (!confirm) return;

    try {
      await Supabase.instance.client.from('programs').delete().eq('id', id);
      _fetchData();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Program Deleted")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _deleteWorkout(String id) async {
    final confirm = await _showConfirmDialog("Delete Workout?", "This might affect programs using it.");
    if (!confirm) return;

    try {
      await Supabase.instance.client.from('workouts').delete().eq('id', id);
      _fetchData();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Workout Deleted")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title, style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(content, style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("Cancel", style: TextStyle(color: AppTheme.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text("Delete", style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w600))),
        ],
      ),
    ) ?? false;
  }

  void _createProgram() {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("New program", style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: titleController,
          style: TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            labelText: "Program title",
            labelStyle: TextStyle(color: AppTheme.textMuted),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.surfaceVariant)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primary)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel", style: TextStyle(color: AppTheme.textSecondary))),
          TextButton(
            onPressed: () async {
              if (titleController.text.isEmpty) return;
              try {
                await Supabase.instance.client.from('programs').insert({
                  'title': titleController.text,
                  'description': 'New 4-week program',
                  'total_weeks': 4,
                  'difficulty_level': 'All Levels',
                  'type': 'standard',
                });
                if (mounted) {
                  Navigator.pop(context);
                  _fetchData();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Program created")));
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
              }
            },
            child: Text("Create", style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Admin"),
        backgroundColor: Colors.transparent,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          tabs: const [
            Tab(text: "Programs"),
            Tab(text: "Workouts"),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _handleAdd,
        backgroundColor: AppTheme.primary,
        foregroundColor: AppTheme.background,
        child: const Icon(Icons.add_rounded),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildProgramList(),
                _buildWorkoutList(),
              ],
            ),
    );
  }

  Widget _buildProgramList() {
    return ListView.builder(
      itemCount: _programs.length,
      itemBuilder: (context, index) {
        final program = _programs[index];
        return ListTile(
          title: Text(program.title, style: TextStyle(color: AppTheme.textPrimary)),
          subtitle: Text("${program.totalWeeks} weeks · ${program.difficulty}", style: TextStyle(color: AppTheme.textMuted)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.delete_rounded, color: AppTheme.accent),
                onPressed: () => _deleteProgram(program.id),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.textMuted, size: 14),
            ],
          ),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => ProgramEditor(program: program)));
          },
        );
      },
    );
  }

  Widget _buildWorkoutList() {
    return ListView.builder(
      itemCount: _workouts.length,
      itemBuilder: (context, index) {
        final workout = _workouts[index];
        return ListTile(
          leading: Icon(
            workout.type == 'sequence' ? Icons.playlist_play_rounded : Icons.videocam_rounded,
            color: AppTheme.primary,
          ),
          title: Text(workout.title, style: TextStyle(color: AppTheme.textPrimary)),
          subtitle: Text("${workout.duration} min · ${workout.difficulty}", style: TextStyle(color: AppTheme.textMuted)),
          trailing: IconButton(
            icon: Icon(Icons.delete_rounded, color: AppTheme.accent),
            onPressed: () => _deleteWorkout(workout.id),
          ),
        );
      },
    );
  }
}

// --- SUB-SCREEN: PROGRAM EDITOR (Standard Only) ---
class ProgramEditor extends StatefulWidget {
  final Program program;
  const ProgramEditor({super.key, required this.program});

  @override
  State<ProgramEditor> createState() => _ProgramEditorState();
}

class _ProgramEditorState extends State<ProgramEditor> {
  bool _isLoading = true;
  List<Workout> _allWorkouts = []; 
  List<ProgramDay> _programDays = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final client = Supabase.instance.client;
    
    // Only fetch for Standard Program logic
    final workoutResponse = await client.from('workouts').select();
    final workouts = (workoutResponse as List).map((e) => Workout.fromJson(e)).toList();
    final daysResponse = await client.from('program_days').select('*, workouts(*)').eq('program_id', widget.program.id).order('day_number', ascending: true);
    final days = (daysResponse as List).map((e) => ProgramDay.fromJson(e)).toList();

    if (mounted) {
      setState(() {
        _allWorkouts = workouts;
        _programDays = days;
        _isLoading = false;
      });
    }
  }

  Future<void> _addDay() async {
    try{
    final newDayNum = _programDays.length + 1;
    final int weekNum = ((newDayNum - 1) / 7).floor() + 1;
    final String? defaultWorkoutId = _allWorkouts.isNotEmpty ? _allWorkouts.first.id : null;
    await Supabase.instance.client.from('program_days').insert({
      'program_id': widget.program.id,
      'day_number': newDayNum,
      'week_number': weekNum,
      'is_rest_day': false,
      'workout_id': defaultWorkoutId,
    });
    if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Day Added!")));
      }
    _fetchData();
  }catch(e){
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
  }
  }

  Future<void> _updateDay(String dayId, String? workoutId, bool isRest) async {
    await Supabase.instance.client.from('program_days').update({
      'workout_id': workoutId,
      'is_rest_day': isRest,
    }).eq('id', dayId);
    _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text(widget.program.title), backgroundColor: Colors.transparent),
      floatingActionButton: FloatingActionButton(
        onPressed: _addDay,
        backgroundColor: AppTheme.primary,
        foregroundColor: AppTheme.background,
        child: const Icon(Icons.add_rounded),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
              itemCount: _programDays.length,
              itemBuilder: (context, index) {
                final day = _programDays[index];
                return Card(
                  color: AppTheme.surfaceVariant,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Day ${day.dayNumber} (Week ${(day.dayNumber / 7).ceil()})",
                          style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text("Rest day?", style: TextStyle(color: AppTheme.textPrimary)),
                            Switch(value: day.isRestDay, onChanged: (val) => _updateDay(day.id, null, val), activeColor: AppTheme.primary),
                          ],
                        ),
                        if (!day.isRestDay)
                          DropdownButtonFormField<String>(
                            value: _allWorkouts.any((w) => w.id == day.workoutId) ? day.workoutId : null,
                            dropdownColor: AppTheme.surfaceVariant,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: "Select workout",
                              labelStyle: TextStyle(color: AppTheme.textMuted),
                              filled: true,
                              fillColor: AppTheme.surface,
                            ),
                            items: _allWorkouts.map((w) => DropdownMenuItem(value: w.id, child: Text(w.title, style: TextStyle(color: AppTheme.textPrimary)))).toList(),
                            onChanged: (newId) => _updateDay(day.id, newId, false),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
