// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/history/screens/history_screen.dart';
import '../../features/family/screens/family_screen.dart';
import '../../features/alerts/screens/alerts_screen.dart';
import '../widgets/main_shell.dart';
import '../../features/guest/providers/guest_session_provider.dart';

class _RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  
  _RouterNotifier(this._ref) {
    // Listen auth state changes
    Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
    
    // Listen guest session changes
    _ref.listen(guestSessionProvider, (_, __) {
      notifyListeners();
    });
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  
  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: notifier,
    redirect: (context, state) {
      final session   = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      
      // Baca guest session langsung dari provider
      final guestSession = ref.read(guestSessionProvider);
      final isGuest      = guestSession != null;

      final loc         = state.matchedLocation;
      final isAuthRoute = loc == '/login' || loc == '/register';

      // Sudah login atau guest → jangan ke auth route
      if ((isLoggedIn || isGuest) && isAuthRoute) return '/dashboard';
      
      // Belum login dan bukan guest → paksa ke login
      if (!isLoggedIn && !isGuest && !isAuthRoute) return '/login';
      
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) => const RegisterScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, __) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/history',
            builder: (_, __) => const HistoryScreen(),
          ),
          GoRoute(
            path: '/family',
            builder: (_, __) => const FamilyScreen(),
          ),
          GoRoute(
            path: '/alerts',
            builder: (_, __) => const AlertsScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, __) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  );
});