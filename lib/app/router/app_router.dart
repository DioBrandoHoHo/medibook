import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/screens/auth_screen.dart';
import '../../features/profile/presentation/screens/profile_edit_screen.dart';
import '../../features/profile/presentation/screens/profile_prompt_screen.dart';
import '../../features/welcome/presentation/splash_screen.dart';
import '../../features/welcome/presentation/welcome_screen.dart';
import '../shells/customer_shell.dart';
import '../shells/staff_shell.dart';
import 'app_routes.dart';
import 'route_guard.dart';

/// Cấu hình go_router.
GoRouter createAppRouter(AuthController auth) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: auth.sessionChanges,
    redirect: (context, state) => RouteGuard.redirect(state.matchedLocation, auth.currentUser),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.auth,
        pageBuilder: (context, state) => _fadeSlide(state, const AuthScreen()),
      ),
      GoRoute(
        path: AppRoutes.profilePrompt,
        pageBuilder: (context, state) => _fadeSlide(state, const ProfilePromptScreen()),
      ),
      GoRoute(
        path: AppRoutes.profileEdit,
        builder: (context, state) => const ProfileEditScreen(),
      ),
      GoRoute(
        path: AppRoutes.customerShell,
        pageBuilder: (context, state) => _fadeSlide(state, const CustomerShell()),
      ),
      GoRoute(
        path: AppRoutes.staffShell,
        pageBuilder: (context, state) => _fadeSlide(state, const StaffShell()),
      ),
    ],
    errorBuilder: (context, state) =>
        const Scaffold(body: Center(child: Text('Không tìm thấy trang'))),
  );
}

/// Hiệu ứng chuyển trang.
CustomTransitionPage<void> _fadeSlide(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 420),
    transitionsBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}
