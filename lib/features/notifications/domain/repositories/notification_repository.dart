import '../entities/app_notification.dart';

abstract interface class NotificationRepository {
  /// Theo dõi các thông báo mới nhất (mới nhất đứng đầu).
  Stream<List<AppNotification>> watchLatest();

  /// Đánh dấu các thông báo là đã đọc.
  Future<void> markRead(List<String> ids);}
