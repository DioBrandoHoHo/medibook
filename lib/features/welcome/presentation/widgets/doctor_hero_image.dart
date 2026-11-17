import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Ảnh bác sĩ ở màn Welcome: `assets/images/welcome_doctor.webp` (WebP 1536x2752, ~118 KB, ảnh dọc).
///
/// - Căn khung hơi lệch lên trên để thấy rõ khuôn mặt + áo blouse.
/// - Giải mã ảnh theo đúng chiều rộng màn hình ([Image.cacheWidth]) thay vì bản gốc 1536px
///   để giảm bộ nhớ.
/// - Nếu file lỗi/thiếu, hiển thị hình minh hoạ để app không vỡ giao diện.
class DoctorHeroImage extends StatelessWidget {
  const DoctorHeroImage({super.key});

  static const assetPath = 'assets/images/welcome_doctor.webp';

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final cacheWidth = (mq.size.width * mq.devicePixelRatio).round();
    return Image.asset(
      assetPath,
      fit: BoxFit.cover,
      alignment: const Alignment(0, -0.45),
      width: double.infinity,
      height: double.infinity,
      cacheWidth: cacheWidth > 0 ? cacheWidth : null,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stack) => const _IllustratedDoctor(),
    );
  }
}

class _IllustratedDoctor extends StatelessWidget {
  const _IllustratedDoctor();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF4F8FF), Color(0xFFDCE8FF)],
        ),
      ),
      child: Center(
        child: Container(
          width: 132,
          height: 132,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [AppColors.primaryBright, AppColors.primary]),
          ),
          child: const Icon(Icons.medical_services_rounded, size: 64, color: Colors.white),
        ),
      ),
    );
  }
}
