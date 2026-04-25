import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';

class RestTimerScreen extends StatefulWidget {
  const RestTimerScreen({super.key});

  @override
  State<RestTimerScreen> createState() => _RestTimerScreenState();
}

class _RestTimerScreenState extends State<RestTimerScreen> {
  int _minutes = 1;
  int _seconds = 0;
  int _remainingSeconds = 0;
  bool _isRunning = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    if (_isRunning) return;
    setState(() {
      _remainingSeconds = _minutes * 60 + _seconds;
      if (_remainingSeconds <= 0) _remainingSeconds = 60;
      _isRunning = true;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remainingSeconds--;
        if (_remainingSeconds <= 0) {
          _timer?.cancel();
          _isRunning = false;
          HapticFeedback.mediumImpact();
        }
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  String _formatDisplay(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Rest timer'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Text(
                _isRunning ? 'Rest' : 'Set rest time',
                style: theme.textTheme.titleMedium?.copyWith(color: AppTheme.textMuted),
              ),
              const SizedBox(height: 24),
              if (_isRunning)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _formatDisplay(_remainingSeconds),
                          style: theme.textTheme.displayLarge?.copyWith(
                            color: _remainingSeconds <= 10 ? AppTheme.accent : AppTheme.primary,
                            fontWeight: FontWeight.w800,
                            fontFeatures: [const FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FilledButton.icon(
                              onPressed: _stopTimer,
                              icon: const Icon(Icons.stop_rounded),
                              label: const Text('Stop'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.accent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _timePicker(
                      theme,
                      value: _minutes,
                      max: 59,
                      label: 'Min',
                      onChanged: (v) => setState(() => _minutes = v),
                    ),
                    Text(
                      ':',
                      style: theme.textTheme.headlineMedium?.copyWith(color: AppTheme.textPrimary),
                    ),
                    _timePicker(
                      theme,
                      value: _seconds,
                      max: 59,
                      label: 'Sec',
                      onChanged: (v) => setState(() => _seconds = v),
                    ),
                  ],
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: _startTimer,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start rest'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: AppTheme.background,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _timePicker(ThemeData theme, {required int value, required int max, required String label, required ValueChanged<int> onChanged}) {
    return Column(
      children: [
        Text(label, style: theme.textTheme.labelMedium?.copyWith(color: AppTheme.textMuted)),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton.filled(
              onPressed: value > 0 ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove_rounded),
              style: IconButton.styleFrom(backgroundColor: AppTheme.surfaceVariant, foregroundColor: AppTheme.textPrimary),
            ),
            SizedBox(
              width: 56,
              child: Text(
                value.toString().padLeft(2, '0'),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [const FontFeature.tabularFigures()],
                ),
              ),
            ),
            IconButton.filled(
              onPressed: value < max ? () => onChanged(value + 1) : null,
              icon: const Icon(Icons.add_rounded),
              style: IconButton.styleFrom(backgroundColor: AppTheme.surfaceVariant, foregroundColor: AppTheme.textPrimary),
            ),
          ],
        ),
      ],
    );
  }
}
