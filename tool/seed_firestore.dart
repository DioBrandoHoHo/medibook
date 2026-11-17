// Ghi bộ dữ liệu có sẵn (tool/seed_data.dart) lên Cloud Firestore của dự án.
//
// Cách chạy (từ thư mục gốc dự án):
//   dart run tool/seed_firestore.dart <SĐT nhân viên> <mật khẩu nhân viên> <SĐT khách hàng mẫu>
// VD:
//   dart run tool/seed_firestore.dart 0901234567 <mật khẩu nhân viên> 0912345678
//
// - Đăng nhập bằng tài khoản NHÂN VIÊN (Security Rules chỉ cho nhân viên ghi dữ liệu `isDemo = true`).
// - Đọc API key + mã dự án từ android/app/google-services.json (file này không đưa lên Git).
// - Ghi đè đúng các bản ghi có id cố định (doctors/demo_d0x, appointments/seed_*, notifications/seed_n_*);
//   KHÔNG đụng lịch hẹn thật do khách đặt. Khung giữ chỗ cũ của dữ liệu mẫu không còn dùng thì bị xoá.
// - Chạy lại bất cứ lúc nào để đưa dữ liệu mẫu về trạng thái ban đầu theo ngày chạy.

import 'dart:convert';
import 'dart:io';

import 'package:medibook/features/appointments/domain/entities/appointment.dart';
import 'package:medibook/features/booking/domain/entities/busy_slot.dart';
import 'package:medibook/features/booking/domain/entities/doctor.dart';
import 'package:medibook/features/notifications/domain/entities/app_notification.dart';

import 'seed_data.dart';

Future<void> main(List<String> args) async {
  if (args.length != 3) {
    stderr.writeln('Cách dùng: dart run tool/seed_firestore.dart <SĐT nhân viên> <mật khẩu> <SĐT khách hàng mẫu>');
    exitCode = 64;
    return;
  }
  final config = jsonDecode(File('android/app/google-services.json').readAsStringSync())
      as Map<String, dynamic>;
  final projectId = (config['project_info'] as Map)['project_id'] as String;
  final apiKey = (((config['client'] as List).first as Map)['api_key'] as List).first['current_key'] as String;

  final client = _Rest(projectId);
  try {
    await client.signIn(apiKey, '${args[0]}@medibook.local', args[1]);
    final staff = await client.getDoc('users/${client.uid}');
    if (_str(staff, 'role') != 'staff') {
      throw StateError('Tài khoản ${args[0]} không phải nhân viên (role = ${_str(staff, 'role')}).');
    }

    final customer = await client.findUserByPhone(args[2]);
    if (customer == null) throw StateError('Không tìm thấy khách hàng có SĐT ${args[2]}.');
    final (customerId, customerName) = customer;
    stdout.writeln('Khách hàng mẫu: $customerName ($customerId)');

    final data = buildSeedData(now: DateTime.now(), customerId: customerId, customerName: customerName);
    final keepSlots = {for (final s in data.busySlots) s.id};
    final staleSlots = (await client.demoIds('busy_slots')).where((id) => !keepSlots.contains(id)).toList();
    // Thông báo mẫu của lần ghi trước không còn đúng: Rules không cho xoá -> đánh dấu đã đọc.
    final keepNotifs = {for (final n in data.notifications) n.id};
    final staleNotifs =
        (await client.demoIds('notifications')).where((id) => !keepNotifs.contains(id)).toList();

    final writes = <Map<String, Object?>>[
      for (final d in data.doctors) client.upsert('doctors/${d.id}', _doctor(d)),
      for (final a in data.appointments) client.upsert('appointments/${a.id}', _appointment(a)),
      for (final s in data.busySlots) client.upsert('busy_slots/${s.id}', _busySlot(s)),
      for (final n in data.notifications) client.upsert('notifications/${n.id}', _notification(n)),
      for (final id in staleSlots) {'delete': client.docName('busy_slots/$id')},
      for (final id in staleNotifs) client.markRead('notifications/$id'),
    ];
    for (var i = 0; i < writes.length; i += 400) {
      await client.commit(writes.sublist(i, i + 400 > writes.length ? writes.length : i + 400));
    }
    stdout.writeln('Đã ghi: ${data.doctors.length} bác sĩ, ${data.appointments.length} lịch hẹn, '
        '${data.busySlots.length} khung giữ chỗ, ${data.notifications.length} thông báo; '
        'xoá ${staleSlots.length} khung cũ, đánh dấu đã đọc ${staleNotifs.length} thông báo cũ.');
  } finally {
    client.close();
  }
}

String? _str(Map<String, dynamic> doc, String field) =>
    ((doc['fields'] as Map?)?[field] as Map?)?['stringValue'] as String?;

Map<String, Object?> _doctor(Doctor d) => {
      'name': d.name,
      'specialty': d.specialty,
      'room': d.room,
      'isDemo': true,
      'experienceYears': d.experienceYears,
      'bio': d.bio,
      'fee': d.fee,
    };

Map<String, Object?> _appointment(Appointment a) => {
      'customerId': a.customerId,
      'customerName': a.customerName,
      'serviceName': a.serviceName,
      'startAt': a.startAt,
      'endAt': a.endAt,
      'status': a.status.name,
      'isDemo': true,
      'doctorId': a.doctorId,
      'doctorName': a.doctorName,
      'createdAt': DateTime.now(),
      'updatedAt': DateTime.now(),
    };

Map<String, Object?> _busySlot(BusySlot s) => {
      'doctorId': s.doctorId,
      'startAt': s.startAt,
      'appointmentId': s.appointmentId,
      'isDemo': true,
    };

Map<String, Object?> _notification(AppNotification n) => {
      'title': n.title,
      'body': n.body,
      'createdAt': n.createdAt,
      'isRead': n.isRead,
      'appointmentId': n.appointmentId,
      'isDemo': true,
      'createdBy': 'seed',
    };

/// Gọi REST API của Firebase Auth + Firestore bằng dart:io (không cần thêm thư viện).
class _Rest {
  _Rest(this.projectId);

  final String projectId;
  final _http = HttpClient();
  late String _token;
  late String uid;

  String get _base => 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';
  String docName(String path) => 'projects/$projectId/databases/(default)/documents/$path';

  Future<void> signIn(String apiKey, String email, String password) async {
    final res = await _send('POST',
        'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$apiKey',
        {'email': email, 'password': password, 'returnSecureToken': true},
        auth: false) as Map<String, dynamic>;
    _token = res['idToken'] as String;
    uid = res['localId'] as String;
  }

  Future<Map<String, dynamic>> getDoc(String path) async =>
      await _send('GET', '$_base/$path', null) as Map<String, dynamic>;

  Future<(String, String)?> findUserByPhone(String phone) async {
    final rows = await _send('POST', '$_base:runQuery', {
      'structuredQuery': {
        'from': [{'collectionId': 'users'}],
        'where': {
          'fieldFilter': {'field': {'fieldPath': 'phone'}, 'op': 'EQUAL', 'value': {'stringValue': phone}},
        },
        'limit': 1,
      },
    }) as List;
    for (final row in rows) {
      final doc = (row as Map)['document'] as Map<String, dynamic>?;
      if (doc == null) continue;
      final id = (doc['name'] as String).split('/').last;
      return (id, _str(doc, 'fullName') ?? 'Khách hàng');
    }
    return null;
  }

  /// Id các document `isDemo == true` của [collection].
  Future<List<String>> demoIds(String collection) async {
    final rows = await _send('POST', '$_base:runQuery', {
      'structuredQuery': {
        'from': [{'collectionId': collection}],
        'where': {
          'fieldFilter': {'field': {'fieldPath': 'isDemo'}, 'op': 'EQUAL', 'value': {'booleanValue': true}},
        },
      },
    }) as List;
    return [
      for (final row in rows.cast<Map<String, dynamic>>())
        if (row['document'] case final Map<String, dynamic> doc) (doc['name'] as String).split('/').last,
    ];
  }

  Map<String, Object?> upsert(String path, Map<String, Object?> fields) => {
        'update': {
          'name': docName(path),
          'fields': {
            for (final e in fields.entries)
              if (e.value != null) e.key: _value(e.value!),
          },
        },
      };

  /// Chỉ đổi `isRead` thành true (đúng quyền "Staff đánh dấu đã đọc" trong Rules).
  Map<String, Object?> markRead(String path) => {
        'update': {
          'name': docName(path),
          'fields': {'isRead': {'booleanValue': true}},
        },
        'updateMask': {'fieldPaths': ['isRead']},
        'currentDocument': {'exists': true},
      };

  static Map<String, Object> _value(Object v) => switch (v) {
        final String s => {'stringValue': s},
        final bool b => {'booleanValue': b},
        final int i => {'integerValue': '$i'},
        final DateTime t => {'timestampValue': t.toUtc().toIso8601String()},
        _ => throw ArgumentError('Kiểu không hỗ trợ: ${v.runtimeType}'),
      };

  Future<void> commit(List<Map<String, Object?>> writes) =>
      _send('POST', '$_base:commit', {'writes': writes});

  Future<Object?> _send(String method, String url, Object? body, {bool auth = true}) async {
    final req = await _http.openUrl(method, Uri.parse(url));
    req.headers.contentType = ContentType.json;
    if (auth) req.headers.set('Authorization', 'Bearer $_token');
    if (body != null) req.add(utf8.encode(jsonEncode(body)));
    final res = await req.close();
    final text = await res.transform(utf8.decoder).join();
    if (res.statusCode >= 300) throw HttpException('$method $url -> ${res.statusCode}: $text');
    return text.isEmpty ? null : jsonDecode(text);
  }

  void close() => _http.close();
}
