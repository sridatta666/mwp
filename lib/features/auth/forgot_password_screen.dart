import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../core/glass_widgets.dart';

/// Deep link path for password reset. Must be allowed in Supabase Dashboard →
/// Authentication → URL Configuration → Redirect URLs (e.g. mwp://reset-password).
const String kResetPasswordRedirectPath = 'mwp://reset-password';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  bool _isConnectionError(Object e) {
    if (e is SocketException) return true;
    if (e is http.ClientException) return true;
    final msg = e.toString().toLowerCase();
    return msg.contains('socketexception') ||
        msg.contains('connection abort') ||
        msg.contains('connection refused');
  }

  Future<void> _sendResetLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email address.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: kResetPasswordRedirectPath,
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
          _emailSent = true;
        });
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isConnectionError(e)
                  ? 'Connection problem. Check your internet and try again.'
                  : 'Error: $e',
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: GlassPage(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: GlassCard(
                  padding: const EdgeInsets.all(24),
                  child: _emailSent ? _buildSuccessView() : _buildForm(theme),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.lock_reset_rounded,
          size: 64,
          color: AppTheme.primary.withValues(alpha: 0.9),
        ),
        const SizedBox(height: 24),
        Text(
          'Forgot password?',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your email and we\'ll send you a link to reset your password.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email_outlined, color: AppTheme.textMuted),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _sendResetLink,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: AppTheme.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.background,
                    ),
                  )
                : const Text('Send reset link'),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.mark_email_read_rounded,
          size: 64,
          color: AppTheme.primary.withValues(alpha: 0.9),
        ),
        const SizedBox(height: 24),
        Text(
          'Check your email',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        Text(
          'We sent a password reset link to ${_emailController.text.trim()}. '
          'Click the link in the email to set a new password.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textMuted,
              ),
        ),
        const SizedBox(height: 32),
        TextButton.icon(
          onPressed: () => context.go('/login'),
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
          label: const Text('Back to login'),
          style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
        ),
      ],
    );
  }
}
