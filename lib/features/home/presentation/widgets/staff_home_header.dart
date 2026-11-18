import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../profile/presentation/widgets/user_avatar.dart';

/// Phần đầu Trang chủ trên nền xanh: logo + tên app + slogan, chuông thông báo
/// (kèm số chưa đọc), ảnh đại diện, và lời chào kèm tên người dùng.
/// Trang chủ Customer dùng lại widget này, không có chuông ([onBellTap] = null).
class StaffHomeHeader extends StatelessWidget {
  const StaffHomeHeader({
    super.key,
    required this.staffName,
    this.unreadCount = 0,
    this.onBellTap,
    required this.onAvatarTap,
    this.wish = AppStrings.greetingWish,
    this.avatar = '',
  });

  final String staffName;
  final int unreadCount;
  final VoidCallback? onBellTap;
  final VoidCallback onAvatarTap;

  /// Dòng chữ nhỏ dưới tên.
  final String wish;

  /// Ảnh đại diện đã lưu của người dùng (`AppUser.avatar`); rỗng = hiện chữ cái đầu.
  final String avatar;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryBright, AppColors.primary, AppColors.primaryDark],
          ),
        ),
        child: Stack(
          children: [
            // Hoạ tiết trang trí (thay cho ảnh minh hoạ trong bản thiết kế).
            const Positioned(right: -46, top: -30, child: _Bubble(size: 170, alpha: 0.10)),
            const Positioned(right: 70, bottom: -70, child: _Bubble(size: 150, alpha: 0.07)),
            Positioned(
              right: 22,
              bottom: 18,
              child: Icon(
                Icons.monitor_heart_outlined,
                size: 76,
                color: Colors.white.withValues(alpha: 0.22),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopRow(),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, right: 96),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.greeting,
                            style: TextStyle(
                              fontSize: 14.5,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            staffName,
                            key: const ValueKey('greeting_name'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            wish,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopRow() {
    return Row(
      children: [
        // Logo dựng bằng icon (chưa có file logo).
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.local_hospital_rounded, color: AppColors.primary, size: 28),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                AppStrings.appName,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                AppStrings.slogan,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.85)),
              ),
            ],
          ),
        ),
        if (onBellTap != null)
          IconButton(
            key: const ValueKey('bell_button'),
            tooltip: AppStrings.notifications,
            onPressed: onBellTap,
            icon: Badge(
              // Không có thông báo chưa đọc -> ẩn số đỏ (đặc tả 2.1).
              isLabelVisible: unreadCount > 0,
              // Quá 99 thì hiện "99+" để chấm đỏ không phình to.
              label: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                key: const ValueKey('unread_badge'),
              ),
              child: const Icon(Icons.notifications_rounded, size: 27, color: Colors.white),
            ),
          ),
        const SizedBox(width: 2),
        InkWell(
          key: const ValueKey('staff_avatar'),
          customBorder: const CircleBorder(),
          onTap: onAvatarTap,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.35),
            ),
            child: UserAvatar(
              name: staffName,
              avatar: avatar,
              radius: 20,
              background: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size, required this.alpha});

  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: alpha),
      ),
    );
  }
}
