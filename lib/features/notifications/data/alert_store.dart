import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Dữ liệu thông báo khách hàng lưu trên máy theo từng tài khoản.
abstract interface class AlertStore {
  Future<Map<String, String>?> loadStatuses(String uid);
  Future<void> saveStatuses(String uid, Map<String, String> statuses);

  Future<bool> isEnabled(String uid);
  Future<void> setEnabled(String uid, bool enabled);

  Future<Set<int>> loadScheduledIds(String uid);
  Future<void> saveScheduledIds(String uid, Set<int> ids);

  Future<bool> wasPermissionAsked();
  Future<void> markPermissionAsked();
}

/// Bản thật dùng `shared_preferences`.
class PrefsAlertStore implements AlertStore {
  Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  String _k(String uid, String name) => 'alerts.$uid.$name';

  @override
  Future<Map<String, String>?> loadStatuses(String uid) async {
    final raw = (await _prefs())?.getString(_k(uid, 'statuses'));
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as Map<String, dynamic>).map((k, v) => MapEntry(k, '$v'));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveStatuses(String uid, Map<String, String> statuses) async =>
      (await _prefs())?.setString(_k(uid, 'statuses'), jsonEncode(statuses));

  @override
  Future<bool> isEnabled(String uid) async =>
      (await _prefs())?.getBool(_k(uid, 'enabled')) ?? true;

  @override
  Future<void> setEnabled(String uid, bool enabled) async =>
      (await _prefs())?.setBool(_k(uid, 'enabled'), enabled);

  @override
  Future<Set<int>> loadScheduledIds(String uid) async =>
      ((await _prefs())?.getStringList(_k(uid, 'scheduled')) ?? const [])
          .map(int.tryParse)
          .whereType<int>()
          .toSet();

  @override
  Future<void> saveScheduledIds(String uid, Set<int> ids) async => (await _prefs())
      ?.setStringList(_k(uid, 'scheduled'), ids.map((e) => '$e').toList());

  @override
  Future<bool> wasPermissionAsked() async =>
      (await _prefs())?.getBool('alerts.permissionAsked') ?? false;

  @override
  Future<void> markPermissionAsked() async =>
      (await _prefs())?.setBool('alerts.permissionAsked', true);
}
