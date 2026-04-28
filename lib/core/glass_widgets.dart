import 'package:flutter/material.dart';
import 'theme.dart';

class GlassPage extends StatelessWidget {
  final Widget child;
  const GlassPage({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.pageGradient),
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
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppTheme.glassStroke),
      ),
      child: child,
    );
  }
}

