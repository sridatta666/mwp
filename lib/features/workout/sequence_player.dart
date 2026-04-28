import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:go_router/go_router.dart';

import '../../core/models.dart';
import '../../core/bunny_service.dart';
import '../../core/supabase_service.dart';
import '../../core/theme.dart';
import '../../core/glass_widgets.dart';

class SequencePlayer extends StatefulWidget {
  final Workout workout;
  final VoidCallback onComplete;

  const SequencePlayer({
    super.key,
    required this.workout,
    required this.onComplete,
  });

  @override
  State<SequencePlayer> createState() => _SequencePlayerState();
}

class _SequencePlayerState extends State<SequencePlayer> {
  // State
  int _currentIndex = 0;
  bool _isResting = false;
  int _restTimeRemaining = 0;
  Timer? _restTimer;
  
  // Performance Data
  final TextEditingController _setsController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();
  int _elapsedSeconds = 0;
  Timer? _stopwatchTimer;
  
  // Player
  VideoPlayerController? _controller;
  bool _isPlaying = false;
  bool _isLoading = true;
  
  // Scroll Controller for Timeline
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeClip(_currentIndex);
  }

  Future<void> _initializeClip(int index) async {
    if (index >= widget.workout.clips.length) {
      widget.onComplete();
      return;
    }

    setState(() {
      _isLoading = true;
      _controller?.dispose();
      _controller = null;
      // Reset Inputs
      _setsController.clear();
      _repsController.clear();
      _elapsedSeconds = 0;
    });

    final clip = widget.workout.clips[index];
    final url = BunnyService.getStreamUrl(clip.videoId);
    
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      formatHint: VideoFormat.hls,
    );

    try {
      await controller.initialize();
      await controller.setLooping(true); // Loop until user clicks Next
      
      if (mounted) {
        setState(() {
          _controller = controller;
          _isLoading = false;
          _isPlaying = true;
        });
        controller.play();
        _startStopwatch();
        _scrollToCurrent();
      }
    } catch (e) {
      print("Error loading clip $index: $e");
    }
  }

  void _startStopwatch() {
    _stopwatchTimer?.cancel();
    _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && !_isResting) {
        setState(() => _elapsedSeconds++);
      }
    });
  }

  void _scrollToCurrent() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _currentIndex * 70.0, 
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _handleNext() async {
    _stopwatchTimer?.cancel();
    _controller?.pause();

    // 1. Save Log
    final sets = int.tryParse(_setsController.text) ?? 0;
    final reps = int.tryParse(_repsController.text) ?? 0;
    final clip = widget.workout.clips[_currentIndex];

    await SupabaseService().saveClipLog(
      programId: widget.workout.id,
      clipIndex: _currentIndex,
      clipTitle: clip.title,
      sets: sets,
      reps: reps,
      durationSeconds: _elapsedSeconds,
    );

    // 2. Advance
    if (clip.restDuration > 0 && _currentIndex < widget.workout.clips.length - 1) {
      _startRest(clip.restDuration);
    } else {
      _nextClip();
    }
  }

  void _startRest(int duration) {
    setState(() {
      _isResting = true;
      _restTimeRemaining = duration;
      _isPlaying = false;
    });

    _scrollToCurrent(); 

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restTimeRemaining <= 1) {
        _skipRest();
      } else {
        setState(() => _restTimeRemaining--);
      }
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    setState(() => _isResting = false);
    _nextClip();
  }

  void _nextClip() {
    final nextIndex = _currentIndex + 1;
    if (nextIndex >= widget.workout.clips.length) {
      widget.onComplete();
    } else {
      setState(() => _currentIndex = nextIndex);
      _initializeClip(nextIndex);
    }
  }

  void _togglePlayPause() {
    if (_controller == null || _isResting) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _isPlaying = false;
        _stopwatchTimer?.cancel(); // Pause stopwatch too
      } else {
        _controller!.play();
        _isPlaying = true;
        _startStopwatch(); // Resume stopwatch
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _restTimer?.cancel();
    _stopwatchTimer?.cancel();
    _scrollController.dispose();
    _setsController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 4,
          child: Container(
            color: AppTheme.background,
            child: _isResting 
                ? _buildRestScreen()
                : _buildVideoPlayer(),
          ),
        ),

        // 2. INPUT AREA (Only when active)
        if (!_isResting && !_isLoading)
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // Timer Display
                Column(
                  children: [
                    Icon(Icons.timer_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                    Text(_formatTime(_elapsedSeconds), style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(width: 15),
                
                // Inputs
                Expanded(child: _buildCompactInput("Sets", _setsController)),
                const SizedBox(width: 10),
                Expanded(child: _buildCompactInput("Reps", _repsController)),
                const SizedBox(width: 15),

                // Next Button
                ElevatedButton(
                  onPressed: _handleNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: AppTheme.background,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(12),
                  ),
                  child: const Icon(Icons.check_rounded),
                ),
              ],
            ),
          ),

        // 3. TIMELINE AREA
        Expanded(
          flex: 3,
          child: GlassCard(
            margin: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(15, 10, 15, 5),
                  child: Text("Timeline", style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: widget.workout.clips.length,
                    itemBuilder: (context, index) {
                      final clip = widget.workout.clips[index];
                      final isCurrent = index == _currentIndex;
                      final isPast = index < _currentIndex;
                      
                      return _buildTimelineItem(index, clip, isCurrent, isPast);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatTime(int seconds) {
    final m = (seconds / 60).floor();
    final s = seconds % 60;
    return "$m:${s.toString().padLeft(2, '0')}";
  }

  Widget _buildCompactInput(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (_controller != null && _controller!.value.isInitialized)
           AspectRatio(
             aspectRatio: _controller!.value.aspectRatio,
             child: VideoPlayer(_controller!),
           )
        else
          CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),

        _buildControls(),
        
        Positioned(
          top: 20,
          left: 20,
          right: 20,
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    "${_currentIndex + 1} / ${widget.workout.clips.length}", 
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControls() {
    return GestureDetector(
      onTap: _togglePlayPause,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.transparent,
        child: Center(
              child: !_isPlaying && !_isLoading
              ? Container(
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(50)),
                  padding: const EdgeInsets.all(20),
                  child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 50),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildRestScreen() {
    final nextClip = widget.workout.clips[_currentIndex + 1];
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Theme.of(context).colorScheme.primary.withOpacity(0.3), Theme.of(context).colorScheme.surface],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("Rest", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 32, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Text("$_restTimeRemaining", style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 72, fontWeight: FontWeight.w800)),
          const SizedBox(height: 32),
          Text("Up next", style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Text(nextClip.title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _skipRest,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: AppTheme.background,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text("Skip rest"),
          )
        ],
      ),
    );
  }

  Widget _buildTimelineItem(int index, WorkoutClip clip, bool isCurrent, bool isPast) {
    Color color = isCurrent ? Theme.of(context).colorScheme.primary : (isPast ? Theme.of(context).colorScheme.outline : Theme.of(context).colorScheme.onSurface);
    if (isCurrent && _isResting) color = Theme.of(context).colorScheme.secondary; 

    return Column(
      children: [
        ListTile(
          leading: Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCurrent ? Theme.of(context).colorScheme.primary : (isPast ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest),
              border: isCurrent ? Border.all(color: Colors.white, width: 2) : null,
            ),
            child: Center(
              child: isPast
                  ? Icon(Icons.check_rounded, size: 16, color: Colors.white)
                  : Text("${index + 1}", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
            ),
          ),
          title: Text(
            clip.title,
            style: TextStyle(color: isPast ? Theme.of(context).colorScheme.outline : Theme.of(context).colorScheme.onSurface, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal),
          ),
          trailing: isCurrent && _isPlaying
              ? Icon(Icons.graphic_eq_rounded, color: Theme.of(context).colorScheme.primary)
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        ),
        
        if (clip.restDuration > 0 && index < widget.workout.clips.length - 1)
          Container(
            padding: const EdgeInsets.only(left: 35), 
            child: Row(
              children: [
                      Container(width: 2, height: 20, color: Theme.of(context).colorScheme.surfaceContainerHighest),
                      const SizedBox(width: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isCurrent && _isResting) ? Theme.of(context).colorScheme.primary.withOpacity(0.3) : Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.timer_rounded, size: 12, color: (isCurrent && _isResting) ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline),
                            const SizedBox(width: 6),
                            Text(
                              "${clip.restDuration}s rest",
                              style: TextStyle(color: (isCurrent && _isResting) ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.outline, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
              ],
            ),
          ),
          
        if (clip.restDuration == 0 && index < widget.workout.clips.length - 1)
          Container(
            padding: const EdgeInsets.only(left: 35),
            alignment: Alignment.centerLeft,
            child: Container(width: 2, height: 20, color: Theme.of(context).colorScheme.surfaceContainerHighest),
          ),
      ],
    );
  }
}
