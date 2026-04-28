import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/download_service.dart';
import '../../core/supabase_service.dart';
import '../../core/settings_service.dart';
import '../../core/theme.dart';
import '../../core/glass_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _storageUsed = "Checking...";
  bool _isAdmin = false;
  Map<String, int> _stats = {};
  bool _notificationsEnabled = true;
  final _settingsService = SettingsService();

  @override
  void initState() {
    super.initState();
    _refreshStorage();
    _checkAdminStatus();
    _loadStats();
    _notificationsEnabled = _settingsService.notificationsEnabled;
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await SupabaseService().isUserAdmin();
    if (mounted) setState(() => _isAdmin = isAdmin);
  }

  Future<void> _loadStats() async {
    final stats = await SupabaseService().fetchProgressStats();
    if (mounted) setState(() => _stats = stats);
  }

  Future<void> _refreshStorage() async {
    final usage = await DownloadService().getTotalUsage();
    if (mounted) setState(() => _storageUsed = usage);
  }

  Future<void> _clearAllDownloads() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("Clear all downloads?", style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          "This will delete all offline videos to free up space.",
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancel", style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DownloadService().deleteAllDownloads();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Storage cleared")));
        _refreshStorage();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? "Unknown";

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Profile"),
        backgroundColor: Colors.transparent,
      ),
      body: GlassPage(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
          children: [
            const SizedBox(height: 24),
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.person_rounded, size: 48, color: AppTheme.background),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              email,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Progress stats
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.bar_chart_rounded, color: AppTheme.primary, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        "Your progress",
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_stats['total'] ?? 0}',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              "Workouts completed",
                              style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 40, color: AppTheme.textMuted.withOpacity(0.3)),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '${_stats['thisWeek'] ?? 0}',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: AppTheme.accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              "This week",
                              style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Activity & tools
            Text(
              "Activity & tools",
              style: theme.textTheme.labelLarge?.copyWith(color: AppTheme.textMuted, letterSpacing: 1),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.history_rounded, color: AppTheme.primary),
              ),
              title: Text("Workout history", style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
              subtitle: Text("See all completed workouts", style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textMuted),
              onTap: () => context.push('/history'),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.timer_rounded, color: AppTheme.primary),
              ),
              title: Text("Rest timer", style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
              subtitle: Text("Countdown between sets", style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textMuted),
              onTap: () => context.push('/rest-timer'),
            ),
            const SizedBox(height: 24),

            // Storage card
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.folder_rounded, color: AppTheme.primary, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        "Offline storage",
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _storageUsed,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            "Used by videos",
                            style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: _clearAllDownloads,
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.accent.withOpacity(0.2),
                          foregroundColor: AppTheme.accent,
                        ),
                        icon: const Icon(Icons.delete_forever_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Settings
            Text(
              "Settings",
              style: theme.textTheme.labelLarge?.copyWith(color: AppTheme.textMuted, letterSpacing: 1),
            ),
            const SizedBox(height: 12),
            GlassCard(
              borderRadius: 16,
              child: Column(
                children: [
                  SwitchListTile(
                    value: _notificationsEnabled,
                    onChanged: (v) async {
                      await _settingsService.setNotificationsEnabled(v);
                      if (mounted) setState(() => _notificationsEnabled = v);
                    },
                    title: Text("Notifications", style: TextStyle(color: AppTheme.textPrimary)),
                    subtitle: Text("Reminders and updates", style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    activeColor: AppTheme.primary,
                  ),
                  Divider(height: 1, color: AppTheme.textMuted.withOpacity(0.2)),
                  ListTile(
                    leading: Icon(Icons.info_outline_rounded, color: AppTheme.textMuted, size: 22),
                    title: Text("About MWP", style: TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: "MWP",
                        applicationVersion: "1.0.0",
                        applicationLegalese: "Your personal fitness companion. Workouts, programs, and progress in one place.",
                      );
                    },
                  ),
                  Divider(height: 1, color: AppTheme.textMuted.withOpacity(0.2)),
                  ListTile(
                    leading: Icon(Icons.mail_outline_rounded, color: AppTheme.textMuted, size: 22),
                    title: Text("Contact support", style: TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
                    onTap: () async {
                      final uri = Uri.parse("mailto:support@mwp.app?subject=MWP%20App%20Support");
                      try {
                        if (await canLaunchUrl(uri)) await launchUrl(uri);
                      } catch (_) {}
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (_isAdmin) ...[
              Text(
                "Admin",
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppTheme.textMuted,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/admin'),
                      icon: const Icon(Icons.upload_rounded, size: 20),
                      label: const Text("Upload"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: AppTheme.surfaceVariant),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/manager'),
                      icon: const Icon(Icons.edit_calendar_rounded, size: 20),
                      label: const Text("Programs"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: AppTheme.surfaceVariant),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],

            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Supabase.instance.client.auth.signOut();
                  if (context.mounted) context.go('/login');
                },
                icon: const Icon(Icons.logout_rounded, size: 22),
                label: const Text("Log out"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accent,
                  side: const BorderSide(color: AppTheme.accent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
          ),
        ),
      ),
    );
  }
}
