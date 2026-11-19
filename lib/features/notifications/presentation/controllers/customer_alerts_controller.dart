import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../appointments/domain/entities/appointment.dart';
import '../../../appointments/presentation/controllers/appointments_controller.dart';
import '../../data/alert_store.dart';
import '../../data/local_notifications.dart';
import '../../domain/appointment_alerts.dart';

/// Thông báo + nhắc lịch khám cho KHÁCH HÀNG (lich_hen.txt – Phần bổ sung N).
///
/// KHÔNG có nguồn dữ liệu riêng: nghe đúng [AppointmentsController] mà Trang chủ / Lịch hẹn của
/// khách đang dùng (lịch của chính khách). Mỗi khi danh sách đổi:
/// 1. So với trạng thái đã lưu trên máy -> lịch vừa được xác nhận / từ chối -> hiện thông báo.
/// 2. Lưu lại trạng thái mới.
/// 3. Đối chiếu lời nhắc: hẹn nhắc 1 ngày + 1 giờ trước giờ khám cho lịch ĐÃ XÁC NHẬN sắp tới,
///    huỷ lời nhắc của lịch đã bị huỷ / từ chối / đổi giờ / đã qua.
/// Đăng xuất -> huỷ mọi lời nhắc của tài khoản đó (người khác dùng máy không nhận nhầm).
class CustomerAlertsController extends ChangeNotifier {
  CustomerAlertsController(this._notifications, this._store);

  final LocalNotifications _notifications;
  final AlertStore _store;

  String? _uid;
  AppointmentsController? _source;
  StreamSubscription<String>? _tapSub;
  final _openRequests = StreamController<String>.broadcast();

  bool _enabled = true;
  bool _systemEnabled = true;
  int _scheduledCount = 0;
  String? _lastSignature;

  /// Các lần đồng bộ chạy lần lượt (không chồng lên nhau).
  Future<void> _queue = Future<void>.value();

  /// Công tắc "Thông báo lịch hẹn" ở tab Cá nhân (lưu trên máy, theo tài khoản).
  bool get enabled => _enabled;

  /// Hệ điều hành có cho phép MediBook hiện thông báo không (người dùng có thể tắt trong Cài đặt).
  bool get systemEnabled => _systemEnabled;

  /// Số lời nhắc đang hẹn.
  int get scheduledCount => _scheduledCount;

  /// Id lịch hẹn cần mở khi người dùng bấm vào một thông báo.
  Stream<String> get openRequests => _openRequests.stream;

  /// Bắt đầu cho khách [uid] (gọi khi vào khu vực Khách hàng).
  Future<void> start(String uid, AppointmentsController source) async {
    stop(cancelReminders: false);
    _uid = uid;
    _source = source;
    _lastSignature = null;
    _enabled = await _store.isEnabled(uid);
    // Xin quyền một lần cho mỗi lần cài app (Android 13+); từ chối thì vẫn dùng app bình thường.
    if (!await _store.wasPermissionAsked()) {
      await _store.markPermissionAsked();
      await _notifications.requestPermission();
    }
    _systemEnabled = await _notifications.isEnabled();
    if (_uid != uid) return; // đã đăng xuất trong lúc chờ
    source.addListener(_onSource);
    _tapSub = _notifications.taps.listen(_openPayload);
    _openPayload(await _notifications.takeLaunchPayload());
    _onSource();
    notifyListeners();
  }

  /// Ngừng (đăng xuất). Mặc định huỷ mọi lời nhắc của tài khoản này.
  void stop({bool cancelReminders = true}) {
    _source?.removeListener(_onSource);
    _source = null;
    _tapSub?.cancel();
    _tapSub = null;
    final uid = _uid;
    _uid = null;
    _lastSignature = null;
    if (cancelReminders && uid != null) {
      _enqueue(() async {
        for (final id in await _store.loadScheduledIds(uid)) {
          await _notifications.cancel(id);
        }
        await _store.saveScheduledIds(uid, const {});
      });
      _scheduledCount = 0;
    }
  }

  /// Bật / tắt thông báo lịch hẹn. Bật lại thì xin quyền (nếu chưa có) và hẹn lại lời nhắc.
  Future<void> setEnabled(bool value) async {
    final uid = _uid;
    if (uid == null) return;
    _enabled = value;
    notifyListeners();
    await _store.setEnabled(uid, value);
    if (value) {
      final granted = await _notifications.requestPermission();
      _systemEnabled = granted || await _notifications.isEnabled();
    }
    _lastSignature = null;
    _onSource();
    notifyListeners();
  }

  /// Quay lại app (VD vừa bật thông báo trong Cài đặt) -> đọc lại quyền của hệ điều hành.
  Future<void> refreshSystemStatus() async {
    if (_uid == null) return;
    final value = await _notifications.isEnabled();
    if (value == _systemEnabled) return;
    _systemEnabled = value;
    notifyListeners();
  }

  /// Chờ các lần đồng bộ đang chạy xong (dùng trong test).
  @visibleForTesting
  Future<void> get idle => _queue;

  void _openPayload(String? payload) {
    final id = appointmentIdFromPayload(payload);
    if (id != null) _openRequests.add(id);
  }

  void _onSource() {
    final source = _source;
    final uid = _uid;
    if (source == null || uid == null || source.status != LoadStatus.ready) return;
    final items = List<Appointment>.of(source.items);
    // Chỉ đồng bộ khi dữ liệu liên quan thật sự đổi (đồng hồ chạy mỗi phút không kích hoạt).
    final signature = '$_enabled|${items.map((a) => '${a.id}:${a.status.name}:'
        '${a.startAt.millisecondsSinceEpoch}').join(',')}';
    if (signature == _lastSignature) return;
    _lastSignature = signature;
    final now = source.now;
    _enqueue(() => _sync(uid, items, now));
  }

  void _enqueue(Future<void> Function() task) {
    _queue = _queue.then((_) => task()).catchError((Object _) {});
  }

  Future<void> _sync(String uid, List<Appointment> items, DateTime now) async {
    // 1–2. Thông báo trạng thái mới so với lần trước (lần đầu trên máy này: chỉ ghi nhận, không báo).
    final previous = await _store.loadStatuses(uid);
    if (previous != null && _enabled) {
      for (final alert in detectStatusChanges(previous, items)) {
        await _notifications.show(
          id: alert.id,
          title: alert.title,
          body: alert.body,
          payload: alert.payload,
        );
      }
    }
    await _store.saveStatuses(uid, statusSnapshot(items));

    // 3. Đối chiếu lời nhắc.
    final plans = _enabled ? planReminders(items, now) : const <AppointmentAlert>[];
    final wanted = {for (final p in plans) p.id};
    for (final id in (await _store.loadScheduledIds(uid)).difference(wanted)) {
      await _notifications.cancel(id);
    }
    for (final p in plans) {
      // Cùng id -> hệ điều hành thay lời nhắc cũ (VD lịch đổi giờ).
      await _notifications.schedule(
        id: p.id,
        title: p.title,
        body: p.body,
        payload: p.payload,
        at: p.fireAt!,
      );
    }
    await _store.saveScheduledIds(uid, wanted);
    if (_uid == uid && _scheduledCount != plans.length) {
      _scheduledCount = plans.length;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stop(cancelReminders: false);
    _openRequests.close();
    super.dispose();
  }
}
