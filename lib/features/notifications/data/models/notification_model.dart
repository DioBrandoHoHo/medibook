import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/app_notification.dart';

/// Chuyển đổi giữa document Firestore `notifications/{id}` và entity [AppNotification].
abstract final class NotificationModel {
  static const collection = 'notifications';

  static AppNotification fromMap(String id, Map<String, dynamic> data) {
    final createdAt = data['createdAt'];
    return AppNotification(
      id: id,
      title: data['title'] as String? ?? 'Thông báo',
      body: data['body'] as String? ?? '',
      // Thông báo vừa ghi, máy chủ chưa kịp gán giờ -> tạm dùng giờ hiện tại.
      createdAt: createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
      isRead: data['isRead'] == true,
      appointmentId: data['appointmentId'] as String?,
      isDemo: data['isDemo'] == true,
    );
  }

  static Map<String, Object?> toMap(AppNotification n) => {
        'title': n.title,
        'body': n.body,
        'createdAt': Timestamp.fromDate(n.createdAt),
        'isRead': n.isRead,
        'appointmentId': n.appointmentId,
        'isDemo': n.isDemo,
      };
}
