import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:go_router/go_router.dart';
import 'package:confetti/confetti.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';

// Custom Imports

import '../../core/supabase_service.dart';
import '../../core/models.dart';
import '../../core/bunny_service.dart';
import '../../core/download_service.dart';
import '../../core/theme.dart';
import '../../core/glass_widgets.dart';
import 'sequence_player.dart';

class WorkoutScreen extends StatefulWidget {
  final String workoutId;
  const WorkoutScreen({super.key, required this.workoutId});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  // Data
  Workout? _workout;
  
  // State
  bool _isLoading = true;
  bool _isDownloaded = false; 
  double _downloadProgress = 0.0;
  bool _isDownloading = false;

  // Controllers
  VideoPlayerController? _controller;
  late ConfettiController _confettiController;

  // Controls State
  bool _showControls = true;
  bool _isBuffering = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _fetchAndInitialize();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _toggleFullScreen() {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    if (isLandscape) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  // --- 1. INITIALIZE DATA & PLAYER ---
  Future<void> _fetchAndInitialize() async {
    try {
      // A. Fetch Workout Data
      final data = await SupabaseService().fetchWorkoutDetails(widget.workoutId);
      if (mounted) {
        setState(() => _workout = data);
      }

      // --- PAYWALL CHECK ---
      if (data.isPremium) {
        final isPremiumUser = await SupabaseService().isUserPremium();
        if (!isPremiumUser) {
          if (mounted) {
            // Navigate to Paywall and wait
            await context.push('/paywall');
            
            // Check again in case they upgraded
            final isNowPremium = await SupabaseService().isUserPremium();
            if (!isNowPremium) {
              if (mounted) context.pop(); // Exit if still not premium
              return; // Stop initialization
            }
          }
        }
      }

      // B. Setup Player based on Type
      if (data.type == 'sequence') {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // --- STANDARD VIDEO LOGIC ---
      final dir = await getApplicationDocumentsDirectory();
      final file = File("${dir.path}/${data.videoId}.mp4");
      bool localExists = await file.exists();

      if (mounted) {
        setState(() => _isDownloaded = localExists);
      }

      // C. Initialize Player
      if (localExists) {
        print("📂 Playing from Local: ${file.path}");
        _controller = VideoPlayerController.file(file);
      } else {
        print("📡 Playing from Stream (HLS)");
        final url = BunnyService.getStreamUrl(data.videoId);
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(url),
          formatHint: VideoFormat.hls, 
        );
      }

      await _controller!.initialize();
      await _controller!.setLooping(false); // Don't loop a full workout
      
      if (mounted) {
        setState(() => _isLoading = false);
        _controller!.play();
        _startHideTimer();
      }

      // D. Listen for Video End & Buffering
      _controller!.addListener(() {
        final bool isBuffering = _controller!.value.isBuffering;
        if (isBuffering != _isBuffering) {
          if (mounted) setState(() => _isBuffering = isBuffering);
        }

        if (_controller!.value.position >= _controller!.value.duration) {
          _handleWorkoutComplete();
        }
      });

    } catch (e) {
      print("❌ Error loading workout: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 2. DOWNLOAD LOGIC ---
  Future<void> _handleDownload() async {
    if (_workout == null) return;
    final videoId = _workout!.videoId;

    if (_isDownloaded) {
      // Delete
      await DownloadService().deleteVideo(videoId);
      if (mounted) {
        setState(() => _isDownloaded = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Video removed from downloads.")));
      }
    } else {
      // Download
      setState(() => _isDownloading = true);
      try {
        await DownloadService().downloadVideo(videoId, (progress) {
          if (mounted) setState(() => _downloadProgress = progress);
        });
        
        if (mounted) {
          setState(() {
            _isDownloaded = true;
            _isDownloading = false;
            _downloadProgress = 0.0;
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Download Complete!")));
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isDownloading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Download Failed: $e")));
        }
      }
    }
  }

  // --- 3. COMPLETION LOGIC ---
  void _handleWorkoutComplete() {
    _confettiController.play();
    SupabaseService().markWorkoutComplete(widget.workoutId);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("Workout complete!", style: TextStyle(color: AppTheme.textPrimary)),
        content: Text("Great job.", style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () {
              context.pop();
              context.pop();
            },
            child: Text("Finish", style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _hideTimer?.cancel();
    _controller?.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If data is not loaded yet, show spinner
    if (_workout == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: GlassPage(child: Center(child: CircularProgressIndicator(color: AppTheme.primary))),
      );
    }

    if (_workout!.type == 'sequence') {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: GlassPage(
          child: SequencePlayer(
            workout: _workout!,
            onComplete: _handleWorkoutComplete,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: GlassPage(
        child: OrientationBuilder(
        builder: (context, orientation) {
          final isLandscape = orientation == Orientation.landscape;

          return Stack(
            children: [
              // 1. VIDEO LAYER (Fullscreen in BG)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _toggleControls,
                  child: Container(
                    color: AppTheme.background,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_controller == null || !_controller!.value.isInitialized)
                          CachedNetworkImage(
                            imageUrl: BunnyService.getThumbnailUrl(_workout!.videoId),
                            fit: BoxFit.contain,
                            placeholder: (context, url) => Container(color: AppTheme.background),
                            errorWidget: (context, url, error) => Container(color: AppTheme.background),
                          ),
                        if (_controller != null && _controller!.value.isInitialized)
                          AspectRatio(
                            aspectRatio: _controller!.value.aspectRatio,
                            child: VideoPlayer(_controller!),
                          ),
                        if (_isLoading || (_controller == null || !_controller!.value.isInitialized) || _isBuffering)
                          CircularProgressIndicator(color: AppTheme.primary),
                        
                        // CONTROLS OVERLAY
                        if (_controller != null && _controller!.value.isInitialized)
                          _buildControlsOverlay(isLandscape),
                      ],
                    ),
                  ),
                ),
              ),

              // 2. INFO LAYER (Draggable Sheet - ONLY IN PORTRAIT)
              if (!isLandscape)
                DraggableScrollableSheet(
                  initialChildSize: 0.4,
                  minChildSize: 0.08, // Reduced to peek just below controls
                  maxChildSize: 0.8,
                  builder: (context, scrollController) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, -4))],
                      ),
                      child: ListView(
                        controller: scrollController,
                        padding: EdgeInsets.zero,
                        children: [
                          const SizedBox(height: 12),
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppTheme.textMuted,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _workout!.title,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildBadge(Icons.schedule_rounded, "${_workout!.duration} min", AppTheme.primary),
                              const SizedBox(width: 12),
                              _buildBadge(Icons.bar_chart_rounded, _workout!.difficulty, AppTheme.accent),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            "Instructions",
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppTheme.textMuted,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Follow the movements carefully. Focus on form over speed. If you feel pain, stop immediately.",
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 28),
                          SafeArea(
                            top: false,
                            child: SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _handleWorkoutComplete,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: AppTheme.background,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: const Text("Mark complete"),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

              // 3. CONFETTI LAYER
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  shouldLoop: false,
                  colors: [AppTheme.primary, AppTheme.accent, Colors.amber, Colors.pink],
                ),
              ),
            ],
          );
        },
        ),
      ),
    );
  }

  Widget _buildControlsOverlay(bool isLandscape) {
    return AnimatedOpacity(
      opacity: _showControls ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        color: Colors.black.withOpacity(0.3),
        child: SafeArea(
          child: Stack(
            children: [
              // Gradients
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    height: 100,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black87, Colors.transparent],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Container(
                    height: 100,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black87],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),

              // Top Bar
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                      onPressed: () => context.pop(),
                    ),
                    _buildDownloadButton(),
                  ],
                ),
              ),

              // Center Controls
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      iconSize: 40,
                      icon: const Icon(Icons.replay_10, color: Colors.white),
                      onPressed: () {
                        final newPos = _controller!.value.position - const Duration(seconds: 10);
                        _controller!.seekTo(newPos < Duration.zero ? Duration.zero : newPos);
                        _startHideTimer();
                      },
                    ),
                    const SizedBox(width: 20),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
                          _startHideTimer();
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.2),
                        ),
                        padding: const EdgeInsets.all(15),
                        child: Icon(
                          _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    IconButton(
                      iconSize: 40,
                      icon: const Icon(Icons.forward_10, color: Colors.white),
                      onPressed: () {
                        final newPos = _controller!.value.position + const Duration(seconds: 10);
                        final max = _controller!.value.duration;
                        _controller!.seekTo(newPos > max ? max : newPos);
                        _startHideTimer();
                      },
                    ),
                  ],
                ),
              ),

              // Bottom Progress Bar
              Positioned(
                bottom: isLandscape ? 20 : 70, // Move up in portrait to clear sheet handle
                left: 20,
                right: 20,
                child: ValueListenableBuilder(
                  valueListenable: _controller!,
                  builder: (context, VideoPlayerValue value, child) {
                    final position = value.position;
                    final duration = value.duration;
                    final durationSec = duration.inSeconds.toDouble();
                    final maxVal = durationSec > 0 ? durationSec : 1.0;
                    final val = position.inSeconds.toDouble().clamp(0.0, maxVal);

                    return Row(
                      children: [
                        Text(
                          _formatDuration(position),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 2,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                              activeTrackColor: AppTheme.primary,
                              inactiveTrackColor: AppTheme.textMuted.withOpacity(0.5),
                              thumbColor: AppTheme.primary,
                              overlayColor: AppTheme.primary.withOpacity(0.2),
                            ),
                            child: Slider(
                              value: val,
                              min: 0.0,
                              max: maxVal,
                              onChanged: (v) {
                                _hideTimer?.cancel();
                                _controller!.seekTo(Duration(seconds: v.toInt()));
                              },
                              onChangeEnd: (_) => _startHideTimer(),
                            ),
                          ),
                        ),
                        Text(
                          _formatDuration(duration),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(isLandscape ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white),
                          onPressed: _toggleFullScreen,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET HELPERS ---
  Widget _buildDownloadButton() {
    if (_isDownloading) {
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(value: _downloadProgress, color: AppTheme.primary, strokeWidth: 3),
      );
    }
    return IconButton(
      icon: Icon(
        _isDownloaded ? Icons.check_circle_rounded : Icons.download_for_offline_rounded,
        color: _isDownloaded ? AppTheme.primary : Colors.white,
        size: 28,
      ),
      onPressed: _handleDownload,
    );
  }

  Widget _buildBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
