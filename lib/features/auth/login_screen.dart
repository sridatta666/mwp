import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/glass_widgets.dart';

/// Max retries for auth when a connection/network error occurs.
const int _kConnectionRetryCount = 3;
const Duration _kConnectionRetryDelay = Duration(seconds: 2);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  /// True if the error is a connection/network failure (e.g. SocketException, connection abort).
  bool _isConnectionError(Object e) {
    if (e is SocketException) return true;
    if (e is http.ClientException) return true;
    final msg = e.toString().toLowerCase();
    return msg.contains('socketexception') ||
        msg.contains('connection abort') ||
        msg.contains('connection refused') ||
        msg.contains('connection reset') ||
        msg.contains('connection timed out') ||
        msg.contains('network is unreachable');
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter email and password.")),
      );
      return;
    }

    setState(() => _isLoading = true);
    int attempt = 0;

    while (true) {
      try {
        attempt++;
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        if (mounted) {
          setState(() => _isLoading = false);
          context.go('/');
        }
        return;
      } on AuthException catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);

        if (e.message.contains('not confirmed') ||
            e.code == 'email_not_confirmed') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                "Please confirm your email. Check your inbox and click the confirmation link, then try again.",
              ),
              action: SnackBarAction(
                label: "Resend",
                onPressed: _resendConfirmation,
              ),
            ),
          );
          return;
        }

        if (e.code == 'invalid_credentials') {
          await _trySignUpThenReport(email, password);
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_userFriendlyMessage(e))),
        );
        return;
      } catch (e) {
        if (!mounted) return;

        if (_isConnectionError(e) && attempt < _kConnectionRetryCount) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "Connection problem. Retrying (${attempt}/$_kConnectionRetryCount)…",
                ),
              ),
            );
          }
          await Future<void>.delayed(_kConnectionRetryDelay);
          continue;
        }

        setState(() => _isLoading = false);
        if (_isConnectionError(e)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Connection problem. Check your internet connection and try again. If the issue continues, the server may be temporarily unavailable.",
              ),
              duration: Duration(seconds: 5),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e")),
          );
        }
        return;
      }
    }
  }

  Future<void> _resendConfirmation() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: email,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Confirmation email sent. Check your inbox.")),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  Future<void> _trySignUpThenReport(String email, String password) async {
    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );
      if (!mounted) return;

      // Supabase can return a user with no identities for existing accounts
      // (to prevent email enumeration). Treat that as "wrong credentials".
      final identities = response.user?.identities;
      final isExistingUser = identities != null && identities.isEmpty;

      if (isExistingUser) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid email or password.")),
        );
        return;
      }

      // If a session is returned, email confirmation is not required.
      if (response.session != null) {
        context.go('/');
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Account created. Please confirm your email, then sign in.",
            ),
          ),
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      // User already exists = they used wrong password
      if (e.code == 'user_already_exists' || e.code == 'email_exists') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid email or password.")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  String _userFriendlyMessage(AuthException e) {
    if (e.code == 'invalid_credentials') return "Invalid email or password.";
    if (e.code == 'user_banned') return "This account has been suspended.";
    if (e.code == 'email_not_confirmed') {
      return "Please confirm your email before signing in.";
    }
    return e.message;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: GlassPage(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: GlassCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.4),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.fitness_center_rounded, size: 56, color: AppTheme.background),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'MWP',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to continue',
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 28),
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
                  const SizedBox(height: 20),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline_rounded, color: AppTheme.textMuted),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.push('/forgot-password'),
                      child: Text(
                        'Forgot password?',
                        style: TextStyle(color: AppTheme.primary.withOpacity(0.9)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: AppTheme.background,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.background),
                            )
                          : const Text('Login / Sign up'),
                    ),
                  ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
