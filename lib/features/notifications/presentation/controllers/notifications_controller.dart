import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';

/// Danh sách thông báo của Staff + số chưa đọc (hiện trên chuông).
/// Lưu ý: số chưa đọc KHÁC số lịch đang chờ xác nhận.
class NotificationsController extends ChangeNotifier {
  NotificationsController(this._repository);

  final NotificationRepository _repository;

  StreamSubscription<List<AppNotification>>? _subscription;
  List<AppNotification> _items = const [];
  bool _hasError = false;

  List<AppNotification> get items => _items;
  bool get hasError => _hasError;

  /// Số thông báo chưa đọc – luôn đếm từ danh sách, không lưu riêng.
  int get unreadCount => _items.where((n) => !n.isRead).length;

  void start() {
    _subscription?.cancel();
    _subscription = _repository.watchLatest().listen(
      (items) {
        _items = items;
        _hasError = false;
        notifyListeners();
      },
      onError: (Object _) {
        _hasError = true;
        notifyListeners();
      },
    );
  }

  void retry() {
    _hasError = false;
    notifyListeners();
    start();
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _items = const [];
    _hasError = false;
  }

  /// Đánh dấu một thông báo đã đọc. Lỗi mạng không làm app dừng.
  Future<void> markRead(String id) => _markRead([id]);

  Future<void> markAllRead() =>
      _markRead(_items.where((n) => !n.isRead).map((n) => n.id).toList());

  Future<void> _markRead(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      await _repository.markRead(ids);
    } catch (_) {
      // Bỏ qua: trạng thái sẽ được đồng bộ lại ở lần lắng nghe kế tiếp.
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
