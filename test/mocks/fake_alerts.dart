import 'dart:async';

import 'package:medibook/features/notifications/data/alert_store.dart';
import 'package:medibook/features/notifications/data/local_notifications.dart';

/// Thông báo đã hiện / đã hẹn trong bản giả.
class FakeNotice {
  FakeNotice(this.id, this.title, this.body, this.payload, [this.at]);

  final int id;
  final String title;
  final String body;
  final String payload;
  final DateTime? at;
}

/// Thông báo hệ điều hành giả – ghi lại mọi lần hiện / hẹn / huỷ. CHỈ dùng cho test.
class FakeLocalNotifications implements LocalNotifications {
  FakeLocalNotifications({this.granted = true, this.launchPayload});

  /// Người dùng có đồng ý cho hiện thông báo không.
  bool granted;
  String? launchPayload;
  int permissionRequests = 0;

  final List<FakeNotice> shown = [];

  /// Lời nhắc đang hẹn theo id.
  final Map<int, FakeNotice> scheduled = {};
  final List<int> cancelled = [];
  final _taps = StreamController<String>.broadcast();

  /// Giả lập người dùng bấm vào một thông báo.
  void tap(String payload) => _taps.add(payload);

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return granted;
  }

  @override
  Future<bool> isEnabled() async => granted;

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    if (granted) shown.add(FakeNotice(id, title, body, payload));
  }

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required String payload,
    required DateTime at,
  }) async {
    scheduled[id] = FakeNotice(id, title, body, payload, at);
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    scheduled.remove(id);
  }

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<String?> takeLaunchPayload() async {
    final p = launchPayload;
    launchPayload = null;
    return p;
  }
}

/// Bộ nhớ trên máy giả (trong RAM). Dùng chung một đối tượng giữa các lần "mở app" để giả lập
/// dữ liệu còn lại sau khi tắt app.
class MemoryAlertStore implements AlertStore {
  final Map<String, Map<String, String>> statuses = {};
  final Map<String, bool> enabled = {};
  final Map<String, Set<int>> scheduledIds = {};
  bool permissionAsked = false;

  @override
  Future<Map<String, String>?> loadStatuses(String uid) async =>
      statuses[uid] == null ? null : Map.of(statuses[uid]!);

  @override
  Future<void> saveStatuses(String uid, Map<String, String> value) async =>
      statuses[uid] = Map.of(value);

  @override
  Future<bool> isEnabled(String uid) async => enabled[uid] ?? true;

  @override
  Future<void> setEnabled(String uid, bool value) async => enabled[uid] = value;

  @override
  Future<Set<int>> loadScheduledIds(String uid) async => Set.of(scheduledIds[uid] ?? const {});

  @override
  Future<void> saveScheduledIds(String uid, Set<int> ids) async => scheduledIds[uid] = Set.of(ids);

  @override
  Future<bool> wasPermissionAsked() async => permissionAsked;

  @override
  Future<void> markPermissionAsked() async => permissionAsked = true;
}
