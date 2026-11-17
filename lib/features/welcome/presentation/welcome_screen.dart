import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import 'widgets/doctor_hero_image.dart';
import 'widgets/welcome_background_painter.dart';

/// Màn hình chào mừng (Mục 2): ảnh bác sĩ, tagline, nút "Bắt đầu đặt lịch".
/// Hiệu ứng: ảnh phóng nhẹ + mờ dần, chữ và nút trượt lên lần lượt.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Animation<double> _interval(double begin, double end) =>
      CurvedAnimation(parent: _c, curve: Interval(begin, end, curve: Curves.easeOutCubic));

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final heroAnim = _interval(0, 0.6);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.welcomeDark,
        body: Stack(
          children: [
            const Positioned.fill(child: CustomPaint(painter: WelcomeBackgroundPainter())),
            Column(
              children: [
                // ---- Ảnh bác sĩ ----
                SizedBox(
                  height: size.height * 0.58,
                  width: double.infinity,
                  child: FadeTransition(
                    opacity: heroAnim,
                    child: ScaleTransition(
                      scale: Tween(begin: 1.08, end: 1.0).animate(heroAnim),
                      child: const ClipRRect(
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
                        child: DoctorHeroImage(),
                      ),
                    ),
                  ),
                ),
                // ---- Nội dung ----
                Expanded(
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SlideUp(
                            animation: _interval(0.3, 0.65),
                            child: const Row(
                              children: [
                                Text(
                                  AppStrings.welcomeEyebrow,
                                  style: TextStyle(
                                    color: AppColors.welcomeMuted,
                                    fontSize: 11,
                                    letterSpacing: 1.4,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Spacer(),
                                _PageDots(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Tagline tự thu nhỏ trên màn hình thấp để không bị tràn.
                          Expanded(
                            child: _SlideUp(
                              animation: _interval(0.4, 0.8),
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.topLeft,
                                child: SizedBox(width: 320, child: _Tagline()),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _SlideUp(
                            animation: _interval(0.6, 1),
                            child: _StartButton(
                              onPressed: () => context.push(AppRoutes.auth),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Tagline giữ nguyên văn đặc tả; chữ "anywhere." tô xanh như ảnh mẫu.
class _Tagline extends StatelessWidget {
  const _Tagline();

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(
      color: Colors.white,
      fontSize: 36,
      height: 1.18,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
    );
    return const Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: 'Book your Doctor any Time, '),
          TextSpan(text: 'an', style: TextStyle(color: Color(0xFFD6E4FF))),
          TextSpan(text: 'ywhere.', style: TextStyle(color: AppColors.primaryBright)),
        ],
      ),
      semanticsLabel: AppStrings.welcomeTagline,
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots();

  @override
  Widget build(BuildContext context) {
    Widget dot(double w, Color c) => Container(
          width: w,
          height: 6,
          margin: const EdgeInsets.only(left: 5),
          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot(6, AppColors.welcomeMuted),
        dot(6, AppColors.welcomeMuted),
        dot(26, Colors.white),
      ],
    );
  }
}

/// Nút chính có hiệu ứng nhún khi chạm.
class _StartButton extends StatefulWidget {
  const _StartButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends State<_StartButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: const Duration(milliseconds: 120),
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: FilledButton(
          onPressed: widget.onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(56),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(child: Text(AppStrings.startBooking, overflow: TextOverflow.ellipsis)),
              SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideUp extends StatelessWidget {
  const _SlideUp({required this.animation, required this.child});
  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.35), end: Offset.zero).animate(animation),
        child: child,
      ),
    );
  }
}
