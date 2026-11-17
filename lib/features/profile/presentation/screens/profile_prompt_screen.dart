import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/router/route_guard.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/repositories/profile_repository.dart';
import '../controllers/profile_controller.dart';

/// Bước hỏi cập nhật hồ sơ (Mục 6).
/// Chỉ xuất hiện khi chưa hoàn thiện hồ sơ VÀ chưa từng bấm "Để sau".
class ProfilePromptScreen extends StatelessWidget {
  const ProfilePromptScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => ProfileController(
        ctx.read<ProfileRepository>(),
        ctx.read<AuthController>(),
      ),
      child: const _ProfilePromptView(),
    );
  }
}

class _ProfilePromptView extends StatelessWidget {
  const _ProfilePromptView();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().currentUser;
    if (user == null) return const SizedBox.shrink(); // router sẽ chuyển về /auth

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.6, end: 1),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (context, v, child) => Transform.scale(scale: v, child: child),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryLight,
                  ),
                  child: const Icon(Icons.badge_outlined, size: 56, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Xin chào, ${user.fullName}!',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              const Text(
                AppStrings.profilePromptQuestion,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary, height: 1.4),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => context.go(AppRoutes.profileEdit),
                child: const Text(AppStrings.yes),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  context.read<ProfileController>().dismissPrompt();
                  context.go(RouteGuard.homeFor(user.role));
                },
                child: const Text(AppStrings.later),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
