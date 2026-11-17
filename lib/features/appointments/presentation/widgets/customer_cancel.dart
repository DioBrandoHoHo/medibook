import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../domain/entities/appointment.dart';
import '../controllers/appointments_controller.dart';

/// Luồng hủy lịch của Customer (lich_hen.txt 7.2), dùng chung cho thẻ ở tab Lịch hẹn và
/// màn Chi tiết: hỏi lại -> kiểm tra quy tắc theo dữ liệu mới nhất -> ghi -> báo kết quả.
/// Trả về `true` nếu đã hủy thành công.
///
/// [onBusy] được gọi `true` SAU KHI khách đồng ý (bắt đầu ghi) và `false` khi ghi xong,
/// để màn gọi khoá nút / hiện vòng xoay đúng lúc.
Future<bool> confirmCancelAppointment(
  BuildContext context,
  Appointment appointment, {
  void Function(bool busy)? onBusy,
}) async {
  final controller = context.read<AppointmentsController>();
  final messenger = ScaffoldMessenger.of(context);
  final agreed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Text(AppStrings.cancelDialogTitle),
      titleTextStyle: const TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      content: Text(
        '${appointment.doctorName ?? appointment.serviceName}\n'
        '${AppDateUtils.timeRange(appointment.startAt, appointment.endAt)}  •  '
        '${AppDateUtils.weekdayDate(appointment.startAt)}\n\n'
        '${AppStrings.actionIrreversible}',
      ),
      actions: [
        TextButton(
          key: const ValueKey('cancel_keep'),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text(AppStrings.keepAppointment),
        ),
        TextButton(
          key: const ValueKey('cancel_agree'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text(AppStrings.cancelAppointment),
        ),
      ],
    ),
  );
  if (agreed != true) return false;

  onBusy?.call(true);
  final error = await controller.cancel(appointment.id);
  onBusy?.call(false);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(error ?? AppStrings.cancelledDone),
        backgroundColor: error == null ? null : AppColors.error,
      ),
    );
  return error == null;
}
