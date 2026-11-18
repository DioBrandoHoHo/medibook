import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../core/utils/name_utils.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/appointment.dart';
import '../screens/appointment_detail_screen.dart';
import 'status_chip.dart';

/// Một lịch hẹn: ảnh đại diện, tên người đặt, dịch vụ, giờ, ngày, trạng thái.
/// Dùng chung cho Trang chủ (dạng gọn) và màn Lịch đặt (thêm mã lịch + [footer]).
/// Bấm vào sẽ mở Chi tiết lịch hẹn theo đúng id của lịch.
class AppointmentTile extends StatelessWidget {
  const AppointmentTile({
    super.key,
    required this.appointment,
    this.showCode = false,
    this.footer,
    this.now,
    this.showDoctor = false,
  });

  final Appointment appointment;

  /// Hiện mã lịch cạnh tên dịch vụ (màn Lịch đặt).
  final bool showCode;

  /// Có giá trị -> ngày hiện dạng gọn "Ngày mai" / "T5, 19/11"; lịch hôm nay chưa bắt đầu hiện
  /// "còn 25 phút" thay cho ngày (Trang chủ). `null` -> ngày đầy đủ dd/MM/yyyy (Lịch đặt).
  final DateTime? now;

  /// Hiện tên bác sĩ khám ở dòng dưới dịch vụ (nếu lịch đã gắn bác sĩ).
  final bool showDoctor;

  /// Vùng dưới cùng của thẻ (VD nút Xác nhận / Từ chối ở màn Lịch đặt).
  /// Trang chủ không truyền -> không có nút xử lý trên thẻ (trang_chu.txt 2.4).
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
                              // Lịch hôm nay chưa bắt đầu: "còn 25 phút" thay cho chữ "Hôm nay"
                              // (vừa đủ nghĩa, không bị cắt chữ trên màn hình hẹp).
                              startsIn == null
                                  ? '${AppDateUtils.timeRange(a.startAt, a.endAt)}  •  $dateText'
                                  : '${AppDateUtils.timeRange(a.startAt, a.endAt)}  •  ',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                          ),
                          if (startsIn != null)
                            Text(
                              startsIn,
                              key: ValueKey('starts_in_${a.id}'),
                              style: const TextStyle(
                                color: AppColors.primary,
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
