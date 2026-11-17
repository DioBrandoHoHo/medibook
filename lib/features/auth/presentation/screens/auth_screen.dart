import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_mode_switch.dart';
import '../widgets/login_form.dart';
import '../widgets/register_form.dart';

/// Màn xác thực chung (Mục 3): chuyển đổi giữa Đăng nhập và Đăng ký.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;

  void _setMode(bool isLogin) {
    if (isLogin == _isLogin) return;
    context.read<AuthController>().clearErrors();
    setState(() => _isLogin = isLogin);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            children: [
              _Header(isLogin: _isLogin),
              Transform.translate(
                offset: const Offset(0, -36),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AuthModeSwitch(isLogin: _isLogin, onChanged: _setMode),
                        const SizedBox(height: 22),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 320),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, anim) {
                              final isLoginChild = child.key == const ValueKey('login');
                              final begin = Offset(isLoginChild ? -0.08 : 0.08, 0);
                              return FadeTransition(
                                opacity: anim,
                                child: SlideTransition(
                                  position: Tween(begin: begin, end: Offset.zero).animate(anim),
                                  child: child,
                                ),
                              );
                            },
                            layoutBuilder: (current, previous) => Stack(
                              alignment: Alignment.topCenter,
                              children: [...previous, ?current],
                            ),
                            child: _isLogin
                                ? const LoginForm(key: ValueKey('login'))
                                : const RegisterForm(key: ValueKey('register')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _SwitchHint(isLogin: _isLogin, onTap: () => _setMode(!_isLogin)),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.isLogin});
  final bool isLogin;

  @override
  Widget build(BuildContext context) {
    final canPop = context.canPop();
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, MediaQuery.paddingOf(context).top + 8, 24, 64),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryBright, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 44,
            child: canPop
                ? IconButton(
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                  )
                : null,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.medical_services_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              const Text(
                AppStrings.appName,
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Column(
              key: ValueKey(isLogin),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLogin ? AppStrings.authWelcomeBack : AppStrings.authCreateAccount,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isLogin ? AppStrings.authLoginSubtitle : AppStrings.authRegisterSubtitle,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchHint extends StatelessWidget {
  const _SwitchHint({required this.isLogin, required this.onTap});
  final bool isLogin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          isLogin ? 'Chưa có tài khoản?' : 'Đã có tài khoản?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        TextButton(
          onPressed: onTap,
          child: Text(isLogin ? AppStrings.register : AppStrings.login),
        ),
      ],
    );
  }
}
