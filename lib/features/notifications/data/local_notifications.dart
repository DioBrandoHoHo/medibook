import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/constants/app_strings.dart';

/// Thông báo của hệ điều hành trên điện thoại (hiện ngay + hẹn giờ).
/// Tách thành interface để test thay bằng bản giả.
abstract interface class LocalNotifications {
  /// Xin quyền hiển thị thông báo (Android 13+ hiện hộp thoại hệ thống). `true` = được phép.
  Future<bool> requestPermission();

  /// Người dùng có đang cho phép thông báo không (có thể đã tắt trong Cài đặt).
  Future<bool> isEnabled();

  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String payload,
  });

  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required String payload,
    required DateTime at,
  });

  Future<void> cancel(int id);

  /// Payload của thông báo người dùng vừa bấm khi app đang chạy.
  Stream<String> get taps;

  /// Payload của thông báo đã MỞ app (app đang tắt hẳn); đọc một lần.
  Future<String?> takeLaunchPayload();
}

/// Bản thật dùng `flutter_local_notifications` (chỉ Android).
class PluginLocalNotifications implements LocalNotifications {
  PluginLocalNotifications({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final _taps = StreamController<String>.broadcast();
  Future<bool>? _ready;
  bool _launchTaken = false;

  static const _channelId = 'appointments';

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      AppStrings.alertChannelName,
      channelDescription: AppStrings.alertChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(''),
    ),
  );

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// Khởi tạo một lần, lần gọi đầu tiên. Lỗi khởi tạo không làm app dừng (thông báo chỉ là phụ).
  Future<bool> _init() => _ready ??= () async {
        if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
        try {
          await _plugin.initialize(
            settings: const InitializationSettings(
              android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            ),
            onDidReceiveNotificationResponse: (response) {
              final payload = response.payload;
              if (payload != null) _taps.add(payload);
            },
          );
          return true;
        } catch (_) {
          return false;
        }
      }();

  @override
  Future<bool> requestPermission() async {
    if (!await _init()) return false;
    try {
      return await _android?.requestNotificationsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isEnabled() async {
    if (!await _init()) return false;
    try {
      return await _android?.areNotificationsEnabled() ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    if (!await _init()) return;
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: _details,
        payload: payload,
      );
    } catch (_) {}
  }

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required String payload,
    required DateTime at,
  }) async {
    if (!await _init()) return;
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        payload: payload,
        // Thời điểm tuyệt đối (UTC) -> không phụ thuộc múi giờ của máy.
        scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
        notificationDetails: _details,
        // Không cần quyền "báo thức chính xác"; hệ điều hành có thể dời vài phút để tiết kiệm pin.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {}
  }

  @override
  Future<void> cancel(int id) async {
    if (!await _init()) return;
    try {
      await _plugin.cancel(id: id);
    } catch (_) {}
  }

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<String?> takeLaunchPayload() async {
    if (_launchTaken || !await _init()) return null;
    _launchTaken = true;
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp != true) return null;
      return details?.notificationResponse?.payload;
    } catch (_) {
      return null;
    }
  }
}
