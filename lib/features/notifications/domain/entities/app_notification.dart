/// Thông báo dành cho Staff. Trạng thái đã đọc dùng CHUNG cho mọi Staff.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    this.appointmentId,
    this.isDemo = false,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  /// Lịch hẹn liên quan (nếu có) – bấm thông báo sẽ mở chi tiết lịch này.
  final String? appointmentId;
  final bool isDemo;

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        title: title,
        body: body,
        createdAt: createdAt,
        isRead: isRead ?? this.isRead,
        appointmentId: appointmentId,
        isDemo: isDemo,
      );
}
