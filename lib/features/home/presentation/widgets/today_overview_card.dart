import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../appointments/domain/entities/appointment_status.dart';
import '../../domain/staff_home_summary.dart';

/// Khu vực "Tổng quan hôm nay" với 4 thẻ chỉ số. Các con số lấy từ [StaffHomeSummary]
/// (tính từ danh sách lịch hẹn chung), widget này không tự đếm hay cộng trừ.
class TodayOverviewCard extends StatelessWidget {
  const TodayOverviewCard({
    super.key,
    required this.summary,
    required this.today,
    required this.onOpenToday,
  });

  final StaffHomeSummary summary;

  /// Ngày đang được thống kê (ngày hiện tại).
  final DateTime today;

  /// Mở màn Lịch đặt lọc "Hôm nay", kèm lọc trạng thái (rỗng = mọi trạng thái).
  final void Function(Set<AppointmentStatus> statuses) onOpenToday;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.bar_chart_rounded, color: AppColors.primary, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // FittedBox: tự thu nhỏ chữ trên màn hình hẹp thay vì cắt bằng dấu "…".
                  const FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      AppStrings.todayOverview,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        AppDateUtils.weekdayDate(today),
                        key: const ValueKey('overview_date'),
                        style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                      ),
                      Text(
                        AppStrings.todayRemaining(summary.todayRemaining),
                        key: const ValueKey('today_remaining'),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              key: const ValueKey('see_detail'),
              onPressed: () => onOpenToday(const {}),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                backgroundColor: AppColors.primaryLight,
                padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: const StadiumBorder(),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppStrings.seeDetail,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (summary.todayTotal > 0) ...[_StatusBar(summary: summary), const SizedBox(height: 12)],
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatCard(
                name: 'today_total',
                value: summary.todayTotal,
                label: AppStrings.statTodayTotal,
                icon: Icons.event_note_rounded,
                color: AppColors.primary,
                tint: AppColors.primaryLight,
                onTap: () => onOpenToday(const {}),
              ),
              const SizedBox(width: 10),
              _StatCard(
                name: 'pending',
                value: summary.todayPending,
                label: AppStrings.statPending,
                icon: Icons.schedule_rounded,
                color: AppColors.warning,
                tint: AppColors.warningLight,
                onTap: () => onOpenToday(const {AppointmentStatus.pending}),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatCard(
                name: 'confirmed',
                value: summary.todayConfirmed,
                label: AppStrings.statConfirmed,
                icon: Icons.check_circle_rounded,
                color: AppColors.success,
                tint: AppColors.successLight,
                onTap: () => onOpenToday(const {AppointmentStatus.confirmed}),
              ),
              const SizedBox(width: 10),
              _StatCard(
                name: 'cancelled',
                value: summary.todayCancelledOrRejected,
                label: AppStrings.statCancelledRejected,
                icon: Icons.cancel_rounded,
                color: AppColors.error,
                tint: AppColors.errorLight,
                onTap: () =>
                    onOpenToday(const {AppointmentStatus.cancelled, AppointmentStatus.rejected}),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Một thẻ chỉ số: icon, con số, nhãn. Bấm vào mở Lịch đặt lọc đúng nhóm lịch đó.
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.name,
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.tint,
    required this.onTap,
  });

  final String name;
  final int value;
  final String label;
  final IconData icon;
  final Color color;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: tint,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('stat_card_$name'),
          onTap: onTap,
          // Dạng gọn: số lớn + icon nhỏ ở hàng trên, nhãn chiếm trọn bề ngang ở hàng dưới
          // (nhãn dài như "Lịch hẹn hôm nay" vẫn nằm trên một dòng ở màn hình 360dp).
          // Nhờ thấp hơn, thẻ cần xử lý + 4 chỉ số vừa một màn hình mà không phải cuộn.
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Text(
                      '$value',
                      key: ValueKey('stat_$name'),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.1,
                      ),
                    ),
                    const Spacer(),
                    Icon(icon, color: color, size: 24),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Thanh tỉ lệ mảnh: phần cam / xanh lá / đỏ ứng với Chờ xác nhận / Đã xác nhận /
/// Đã hủy – Từ chối của hôm nay. Cùng màu với 3 thẻ chỉ số bên dưới, nên nhìn là hiểu.
class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.summary});

  final StaffHomeSummary summary;

  @override
  Widget build(BuildContext context) {
    final parts = [
      (summary.todayPending, AppColors.warning),
      (summary.todayConfirmed, AppColors.success),
      (summary.todayCancelledOrRejected, AppColors.error),
    ].where((p) => p.$1 > 0).toList();
    return ClipRRect(
      key: const ValueKey('today_status_bar'),
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        child: Row(
          // stretch: các ô màu (không có nội dung bên trong) lấp đủ chiều cao 8.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < parts.length; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              Expanded(
                flex: parts[i].$1,
                child: ColoredBox(color: parts[i].$2),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
