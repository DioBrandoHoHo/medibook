import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/appointment_status.dart';

/// Tên tiếng Việt + màu của từng trạng thái lịch hẹn. Mọi màn hình dùng chung bảng này
/// (lich_dat.txt 3.3): Chờ xác nhận = cam, Đã xác nhận = xanh lá, Đã hủy = đỏ nhạt, Đã từ chối = đỏ.
abstract final class StatusStyle {
  static String labelOf(AppointmentStatus status) => switch (status) {
        AppointmentStatus.pending => AppStrings.statusPending,
        AppointmentStatus.confirmed => AppStrings.statusConfirmed,
        AppointmentStatus.rejected => AppStrings.statusRejected,
        AppointmentStatus.cancelled => AppStrings.statusCancelled,
      };

  /// (màu nền, màu chữ)
  static (Color, Color) colorsOf(AppointmentStatus status) => switch (status) {
        AppointmentStatus.pending => (AppColors.warningLight, AppColors.warningDark),
        AppointmentStatus.confirmed => (AppColors.successLight, AppColors.success),
        AppointmentStatus.rejected => (AppColors.rejectedLight, AppColors.rejected),
        AppointmentStatus.cancelled => (AppColors.cancelledLight, AppColors.cancelled),
      };

  static IconData iconOf(AppointmentStatus status) => switch (status) {
        AppointmentStatus.pending => Icons.schedule_rounded,
        AppointmentStatus.confirmed => Icons.check_circle_rounded,
        AppointmentStatus.rejected => Icons.block_rounded,
        AppointmentStatus.cancelled => Icons.cancel_rounded,
      };
}

/// Nhãn trạng thái lịch hẹn.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final AppointmentStatus status;

  static String labelOf(AppointmentStatus status) => StatusStyle.labelOf(status);

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = StatusStyle.colorsOf(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Text(
        StatusStyle.labelOf(status),
        style: TextStyle(color: foreground, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
