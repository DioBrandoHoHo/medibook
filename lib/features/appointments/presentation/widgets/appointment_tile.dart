import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../core/utils/name_utils.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/appointment.dart';
import '../screens/appointment_detail_screen.dart';
import 'status_chip.dart';

/// Một lịch hẹn.
class AppointmentTile extends StatelessWidget {
  const AppointmentTile({
    super.key,
    required this.appointment,
    this.showCode = false,
    this.footer,
    this.now,
    this.showDoctor = false,
    this.showDate = true,
  });

  final Appointment appointment;

  /// Hiện mã lịch cạnh tên dịch vụ (màn Lịch đặt).
  final bool showCode;

  /// Giờ hiện tại, dùng để hiện ngày dạng gọn.
  final DateTime? now;

  /// Hiện tên bác sĩ khám ở dòng dưới dịch vụ (nếu lịch đã gắn bác sĩ).
  final bool showDoctor;

  /// Hiện ngày cạnh giờ khám.
  final bool showDate;

  /// Vùng dưới cùng của thẻ (VD nút Xác nhận / Từ chối ở màn Lịch đặt).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final now = this.now;
    final doctor = showDoctor ? a.doctorName : null;
    final dateText = now == null
        ? AppDateUtils.date(a.startAt)
        : AppDateUtils.shortDayLabel(a.startAt, now);
    final startsIn = now == null ? null : AppDateUtils.startsIn(a.startAt, now);
    final trailing = startsIn;
    final time = AppDateUtils.timeRange(a.startAt, a.endAt);
    final timeText = trailing != null ? '$time  •  ' : (showDate ? '$time  •  $dateText' : time);
    return InkWell(
      key: ValueKey('appointment_${a.id}'),
      onTap: () => AppointmentDetailScreen.open(context, a.id),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InitialAvatar(initial: NameUtils.initial(a.customerName)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              a.customerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusChip(status: a.status),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              a.serviceName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                          if (showCode) ...[
                            const SizedBox(width: 8),
                            BookingCodeChip(code: a.shortCode),
                          ],
                        ],
                      ),
                      if (doctor != null) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(
                              Icons.medical_services_outlined,
                              size: 15,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                doctor,
                                key: ValueKey('tile_doctor_${a.id}'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 15,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              timeText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                          ),
                          if (trailing != null)
                            Text(
                              trailing,
                              key: ValueKey(
                                startsIn != null ? 'starts_in_${a.id}' : 'overdue_${a.id}',
                              ),
                              style: TextStyle(
                                color: startsIn != null ? AppColors.primary : AppColors.error,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (footer != null) ...[const SizedBox(height: 10), footer!],
          ],
        ),
      ),
    );
  }
}

/// Mã lịch dạng nhãn nhỏ, VD "#DEMO_05".
class BookingCodeChip extends StatelessWidget {
  const BookingCodeChip({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        code,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }
}
