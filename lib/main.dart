import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme.dart';
import 'core/supabase_http_client.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/forgot_password_screen.dart';
import 'features/auth/reset_password_screen.dart';
import 'features/program/home_screen.dart';
import 'features/program/timeline_screen.dart';
import 'features/workout/workout_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'features/profile/profile_screen.dart';
import 'features/admin/upload_screen.dart';
import 'features/admin/program_manager.dart';
import 'features/monetization/paywall_screen.dart';
import 'features/history/workout_history_screen.dart';
import 'features/tools/rest_timer_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Custom HTTP client with longer timeouts to reduce "connection abort" errors
  // when calling Supabase Auth (e.g. on slow or flaky networks).
  final httpClient = createSupabaseHttpClient();

  await Supabase.initialize(
    url: 'https://pnmpyxeixlhuwpujtolg.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBubXB5eGVpeGxodXdwdWp0b2xnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk2ODczNjIsImV4cCI6MjA4NTI2MzM2Mn0.JYbIs8TV9Lgv2pTrw0RmlPR8dcAi7KWmreoGdDjw7L8',
    httpClient: httpClient,
  );

  // Listen for password recovery deep link → navigate to set new password
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.passwordRecovery) {
      _router.go('/reset-password');
    }
  });

  // 2. Initialize Hive (The Offline DB)
  await Hive.initFlutter();
  await Hive.openBox('downloads');
  await Hive.openBox('cache');
  await Hive.openBox('favorites');
  await Hive.openBox('settings');

  
  runApp(const MyApp());
}

final _router = GoRouter(
initialLocation: '/',
  // 1. ADD REDIRECT LOGIC
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    
    // If no session, and we are NOT on the login page, go to login
    if (session == null &&
        state.uri.toString() != '/login' &&
        state.uri.toString() != '/forgot-password') {
      return '/login';
    }
    
    // If we have a session and we're on login or forgot-password, go home
    // (reset-password is allowed when session is recovery from email link)
    if (session != null &&
        (state.uri.toString() == '/login' ||
            state.uri.toString() == '/forgot-password')) {
      return '/';
    }
    
    return null; // No redirect needed
  },

  routes: [
        
    GoRoute(
      path: '/login',
      builder: (context, state) => LoginScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/reset-password',
      builder: (context, state) => ResetPasswordScreen(),
    ),

    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/program/:id',
      builder: (context, state) => TimelineScreen( programId: state.pathParameters['id']!,),
      
    ),
    
    GoRoute(
      path: '/workout/:id',
      builder: (context, state) => WorkoutScreen(
        workoutId: state.pathParameters['id']!,
      ),
    ),

    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminUploadScreen(),
    ),
    
   GoRoute(
      path: '/manager',
      builder: (context, state) => const ProgramManagerScreen(),
    ),
    
    GoRoute(
      path: '/paywall',
      builder: (context, state) => const PaywallScreen(),
    ),
    GoRoute(
      path: '/history',
      builder: (context, state) => const WorkoutHistoryScreen(),
    ),
    GoRoute(
      path: '/rest-timer',
      builder: (context, state) => const RestTimerScreen(),
    ),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('settings').listenable(keys: ['is_dark_mode']),
      builder: (context, box, child) {
        final isDarkMode = box.get('is_dark_mode', defaultValue: true) as bool;
        return MaterialApp.router(
          routerConfig: _router,
          title: 'MWP',
          debugShowCheckedModeBanner: false,
          
          // APPLY THE THEME HERE
          theme: AppTheme.lightTheme, 
          darkTheme: AppTheme.darkTheme,
          themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
        );
      },
    );
  }
}
