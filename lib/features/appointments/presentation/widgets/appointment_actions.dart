import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../domain/entities/appointment.dart';
import '../controllers/appointments_controller.dart';

/// Luồng Xác nhận / Từ chối DÙNG CHUNG cho thẻ ở màn Lịch đặt và màn Chi tiết.
Future<bool> runAppointmentAction(
  BuildContext context,
  Appointment appointment, {
  required bool confirm,
}) async {
  final controller = context.read<AppointmentsController>();
  final messenger = ScaffoldMessenger.of(context);

  final agreed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text(confirm ? AppStrings.confirmDialogTitle : AppStrings.rejectDialogTitle),
      titleTextStyle: const TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${appointment.customerName} ${appointment.shortCode}',
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            '${appointment.serviceName}\n'
            '${AppDateUtils.timeRange(appointment.startAt, appointment.endAt)}, '
            'ngày ${AppDateUtils.date(appointment.startAt)}',
            style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 12),
          const Text(
            AppStrings.actionIrreversible,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('dialog_cancel'),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text(AppStrings.cancel),
        ),
        TextButton(
          key: const ValueKey('dialog_agree'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: confirm ? AppColors.primary : AppColors.error,
          ),
          child: Text(confirm ? AppStrings.confirmAppointment : AppStrings.rejectAppointment),
        ),
      ],
    ),
  );
  if (agreed != true) return false;

  final error = confirm
      ? await controller.confirm(appointment.id)
      : await controller.reject(appointment.id);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(error ?? (confirm ? AppStrings.confirmedDone : AppStrings.rejectedDone)),
      ),
    );
  return error == null;
}
