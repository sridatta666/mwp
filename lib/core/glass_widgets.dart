import 'package:flutter/material.dart';
import 'theme.dart';

class GlassPage extends StatelessWidget {
  final Widget child;
  const GlassPage({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: isDark ? AppTheme.pageGradient : null,
        color: isDark ? null : Theme.of(context).scaffoldBackgroundColor,
      ),
      child: child,
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 18,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: isDark 
            ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.78)
            : Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: isDark ? Theme.of(context).colorScheme.outlineVariant : Color(0x1F000000)),
      ),
      child: child,
    );
  }
}

