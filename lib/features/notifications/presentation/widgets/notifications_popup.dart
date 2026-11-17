import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../appointments/presentation/controllers/appointments_controller.dart';
import '../../../appointments/presentation/screens/appointment_detail_screen.dart';
import '../../domain/entities/app_notification.dart';
import '../controllers/notifications_controller.dart';

/// POPUP danh sách thông báo (đặc tả yêu cầu popup, không phải màn hình riêng).
class NotificationsPopup extends StatelessWidget {
  const NotificationsPopup({super.key});

  static Future<void> show(BuildContext context) =>
      showDialog<void>(context: context, builder: (_) => const NotificationsPopup());

  /// Mở thông báo: đánh dấu đã đọc, rồi mở lịch hẹn liên quan (nếu còn tồn tại).
  void _open(BuildContext context, AppNotification n) {
    context.read<NotificationsController>().markRead(n.id);
    final appointmentId = n.appointmentId;
    if (appointmentId == null) return;
    if (context.read<AppointmentsController>().byId(appointmentId) == null) return;
    final navigator = Navigator.of(context);
    navigator.pop(); // đóng popup
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => AppointmentDetailScreen(appointmentId: appointmentId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<NotificationsController>();
    final now = context.read<AppointmentsController>().now;
    final items = controller.items;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 6),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    AppStrings.notifications,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: AppStrings.close,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Flexible(
            child: controller.hasError
                ? ErrorRetryView(message: AppStrings.errUnknown, onRetry: controller.retry)
                : items.isEmpty
                    ? const EmptyView(
                        message: AppStrings.notificationsEmpty,
                        icon: Icons.notifications_off_outlined,
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: items.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, color: AppColors.border),
                        itemBuilder: (context, i) => _NotificationRow(
                          notification: items[i],
                          now: now,
                          onTap: () => _open(context, items[i]),
                        ),
                      ),
          ),
          if (controller.unreadCount > 0) ...[
            const Divider(height: 1, color: AppColors.border),
            TextButton(
              key: const ValueKey('mark_all_read'),
              onPressed: controller.markAllRead,
              child: const Text(AppStrings.markAllRead),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.notification, required this.now, required this.onTap});

  final AppNotification notification;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    return InkWell(
      key: ValueKey('notification_${n.id}'),
      onTap: onTap,
      child: Container(
        // Thông báo chưa đọc có nền xanh nhạt + chấm xanh.
        color: n.isRead ? null : AppColors.primaryLight.withValues(alpha: 0.5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: n.isRead ? Colors.transparent : AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title,
                    style: TextStyle(
                      fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    n.body,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppDateUtils.timeAgo(n.createdAt, now),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
