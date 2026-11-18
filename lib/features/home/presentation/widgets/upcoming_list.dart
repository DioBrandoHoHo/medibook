import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../../appointments/presentation/widgets/appointment_tile.dart';

/// Khu vực "Lịch hẹn sắp diễn ra": tối đa 3 lịch gần nhất + nút "Xem tất cả".
/// Mỗi lịch có tên bác sĩ, ngày dạng gọn và thời gian còn lại nếu là lịch hôm nay.
class UpcomingList extends StatelessWidget {
  const UpcomingList({
    super.key,
    required this.upcoming,
    required this.now,
    required this.onSeeAll,
  });

  final List<Appointment> upcoming;

  /// Giờ hiện tại: để hiện "Hôm nay / Ngày mai" và "còn 25 phút" trên từng lịch.
  final DateTime now;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 4, 0),
              child: Row(
                children: [
                  const Icon(Icons.event_available_rounded, color: AppColors.primary, size: 22),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        AppStrings.upcomingTitle,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('see_all'),
                    onPressed: onSeeAll,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(AppStrings.seeAll, style: TextStyle(fontWeight: FontWeight.w600)),
                        Icon(Icons.chevron_right_rounded, size: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (upcoming.isEmpty)
              const EmptyView(message: AppStrings.upcomingEmpty)
            else
              for (var i = 0; i < upcoming.length; i++) ...[
                if (i > 0)
                  const Divider(height: 1, indent: 14, endIndent: 14, color: AppColors.border),
                AppointmentTile(appointment: upcoming[i], now: now, showDoctor: true),
              ],
          ],
        ),
      ),
    );
  }
}
