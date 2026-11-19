import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/constants/app_strings.dart';
import 'package:medibook/features/appointments/domain/entities/appointment.dart';
import 'package:medibook/features/appointments/domain/entities/appointment_status.dart';
import 'package:medibook/features/appointments/presentation/controllers/appointments_controller.dart';
import 'package:medibook/features/notifications/domain/appointment_alerts.dart';
import 'package:medibook/features/notifications/presentation/controllers/customer_alerts_controller.dart';

import '../mocks/fake_alerts.dart';
import '../mocks/fake_clinic_repositories.dart';

/// "Bây giờ" = Thứ Tư 18/11/2026 10:00.
final _now = DateTime(2026, 11, 18, 10);
const _uid = 'cust';

Appointment _a(
  String id,
  DateTime start, {
  AppointmentStatus status = AppointmentStatus.pending,
  String? doctorId = 'd1',
}) =>
    appt(id, start, status: status, doctorId: doctorId, customerId: _uid, service: 'Khám nhi');

void main() {
  group('id + payload', () {
    test('id ổn định, không âm, khác nhau theo loại và theo lịch', () {
      final a = notificationIdFor('abc', AlertKind.status);
      expect(a, notificationIdFor('abc', AlertKind.status));
      expect(a, isNonNegative);
      expect(a, isNot(notificationIdFor('abc', AlertKind.dayBefore)));
      expect(a, isNot(notificationIdFor('abd', AlertKind.status)));
      final ids = {
        for (var i = 0; i < 500; i++)
          for (final k in AlertKind.values) notificationIdFor('seed_$i', k),
      };
      expect(ids.length, 1500); // không trùng trong 500 lịch
    });

    test('payload -> id lịch hẹn; payload lạ -> null', () {
      expect(appointmentIdFromPayload(payloadFor('x1')), 'x1');
      expect(appointmentIdFromPayload('khác'), isNull);
      expect(appointmentIdFromPayload(null), isNull);
      expect(appointmentIdFromPayload('appointment:'), isNull);
    });
  });

  group('detectStatusChanges', () {
    test('Chờ -> Đã xác nhận / Đã từ chối thì báo; còn lại không báo', () {
      final previous = {'p1': 'pending', 'p2': 'pending', 'c1': 'confirmed', 'p3': 'pending'};
      final current = [
        _a('p1', DateTime(2026, 11, 19, 8, 30), status: AppointmentStatus.confirmed),
        _a('p2', DateTime(2026, 11, 20, 9), status: AppointmentStatus.rejected),
        _a('c1', DateTime(2026, 11, 21, 9), status: AppointmentStatus.cancelled), // khách tự huỷ
        _a('p3', DateTime(2026, 11, 22, 9)), // vẫn chờ
        _a('new', DateTime(2026, 11, 23, 9), status: AppointmentStatus.confirmed), // lịch mới
      ];
      final alerts = detectStatusChanges(previous, current);
      expect(alerts.map((a) => a.appointmentId), ['p1', 'p2']);
      expect(alerts[0].title, AppStrings.alertConfirmedTitle);
      expect(alerts[0].body, contains('BS. d1'));
      expect(alerts[0].body, contains('08:30 Thứ Năm, 19/11/2026'));
      expect(alerts[1].title, AppStrings.alertRejectedTitle);
      expect(alerts[1].body, contains('Khám nhi'));
      expect(alerts[0].payload, payloadFor('p1'));
    });
  });

  group('planReminders', () {
    test('lịch đã xác nhận còn 3 ngày -> nhắc trước 1 ngày và 1 giờ, đúng giờ', () {
      final start = DateTime(2026, 11, 21, 9);
      final plans = planReminders([_a('c', start, status: AppointmentStatus.confirmed)], _now);
      expect(plans.map((p) => p.kind), [AlertKind.dayBefore, AlertKind.hourBefore]);
      expect(plans[0].fireAt, DateTime(2026, 11, 20, 9));
      expect(plans[1].fireAt, DateTime(2026, 11, 21, 8));
      expect(plans[0].title, AppStrings.reminderDayTitle);
      expect(plans[1].title, AppStrings.reminderHourTitle);
      expect(plans[1].body, contains('09:00'));
    });

    test('còn 5 giờ -> chỉ nhắc 1 giờ; còn 30 phút / đã qua -> không nhắc', () {
      expect(
        planReminders([_a('c', DateTime(2026, 11, 18, 15), status: AppointmentStatus.confirmed)],
                _now)
            .map((p) => p.kind),
        [AlertKind.hourBefore],
      );
      expect(
        planReminders([
          _a('c', DateTime(2026, 11, 18, 10, 30), status: AppointmentStatus.confirmed),
          _a('d', DateTime(2026, 11, 17, 10), status: AppointmentStatus.confirmed),
        ], _now),
        isEmpty,
      );
    });

    test('chỉ lịch ĐÃ XÁC NHẬN mới được nhắc; sắp xếp theo giờ nhắc', () {
      final plans = planReminders([
        _a('late', DateTime(2026, 11, 25, 9), status: AppointmentStatus.confirmed),
        _a('pend', DateTime(2026, 11, 20, 9)),
        _a('rej', DateTime(2026, 11, 20, 9), status: AppointmentStatus.rejected),
        _a('can', DateTime(2026, 11, 20, 9), status: AppointmentStatus.cancelled),
        _a('soon', DateTime(2026, 11, 20, 9), status: AppointmentStatus.confirmed),
      ], _now);
      expect(plans.map((p) => p.appointmentId).toSet(), {'late', 'soon'});
      final times = plans.map((p) => p.fireAt!).toList();
      expect(times, [...times]..sort());
    });

    test('lịch chưa gắn bác sĩ -> nội dung dùng tên dịch vụ', () {
      final plans = planReminders(
        [_a('c', DateTime(2026, 11, 21, 9), status: AppointmentStatus.confirmed, doctorId: null)],
        _now,
      );
      expect(plans.first.body, 'Khám nhi với Khám nhi lúc 09:00. Vui lòng đến trước 10–15 phút.');
    });
  });

  group('CustomerAlertsController', () {
    late FakeAppointmentRepository repo;
    late AppointmentsController appointments;
    late FakeLocalNotifications notifications;
    late MemoryAlertStore store;
    late CustomerAlertsController alerts;

    Future<void> settle() async {
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      await alerts.idle;
    }

    Future<void> open({List<Appointment>? initial}) async {
      if (initial != null) repo = FakeAppointmentRepository(initial: initial);
      appointments = AppointmentsController(repo, clock: () => _now)..start(customerId: _uid);
      alerts = CustomerAlertsController(notifications, store);
      await alerts.start(_uid, appointments);
      await settle();
    }

    setUp(() {
      notifications = FakeLocalNotifications();
      store = MemoryAlertStore();
    });

    test('lần đầu: chỉ ghi nhận (không báo), hẹn nhắc cho lịch đã xác nhận; xin quyền 1 lần',
        () async {
      await open(initial: [
        _a('p', DateTime(2026, 11, 20, 9)),
        _a('c', DateTime(2026, 11, 21, 9), status: AppointmentStatus.confirmed),
      ]);
      expect(notifications.shown, isEmpty);
      expect(notifications.scheduled.keys.toSet(), {
        notificationIdFor('c', AlertKind.dayBefore),
        notificationIdFor('c', AlertKind.hourBefore),
      });
      expect(alerts.scheduledCount, 2);
      expect(notifications.permissionRequests, 1);
    });

    test('nhân viên xác nhận -> báo + hẹn nhắc; từ chối -> báo, không nhắc', () async {
      await open(initial: [
        _a('p1', DateTime(2026, 11, 20, 9)),
        _a('p2', DateTime(2026, 11, 22, 9)),
      ]);
      await repo.updateStatus('p1', AppointmentStatus.confirmed);
      await settle();
      expect(notifications.shown.single.title, AppStrings.alertConfirmedTitle);
      expect(notifications.shown.single.payload, payloadFor('p1'));
      expect(notifications.scheduled, hasLength(2));

      await repo.updateStatus('p2', AppointmentStatus.rejected);
      await settle();
      expect(notifications.shown.last.title, AppStrings.alertRejectedTitle);
      expect(notifications.scheduled, hasLength(2)); // vẫn chỉ nhắc p1
    });

    test('lịch đã xác nhận bị huỷ -> huỷ lời nhắc, không báo cho chính khách', () async {
      await open(initial: [
        _a('c', DateTime(2026, 11, 21, 9), status: AppointmentStatus.confirmed),
      ]);
      expect(notifications.scheduled, hasLength(2));
      await repo.updateStatus('c', AppointmentStatus.cancelled);
      await settle();
      expect(notifications.scheduled, isEmpty);
      expect(notifications.shown, isEmpty);
      expect(alerts.scheduledCount, 0);
    });

    test('nhân viên xác nhận lúc app đang tắt -> mở lại app thì báo', () async {
      await open(initial: [_a('p', DateTime(2026, 11, 20, 9))]);
      alerts.stop(cancelReminders: false);
      appointments.stop();
      await repo.updateStatus('p', AppointmentStatus.confirmed); // app đang tắt

      await open(); // mở lại app, cùng bộ nhớ trên máy
      expect(notifications.shown.single.title, AppStrings.alertConfirmedTitle);
      expect(notifications.permissionRequests, 1); // không hỏi quyền lần nữa
    });

    test('tắt công tắc -> huỷ mọi lời nhắc, không báo; bật lại -> hẹn lại', () async {
      await open(initial: [
        _a('c', DateTime(2026, 11, 21, 9), status: AppointmentStatus.confirmed),
        _a('p', DateTime(2026, 11, 22, 9)),
      ]);
      await alerts.setEnabled(false);
      await settle();
      expect(notifications.scheduled, isEmpty);
      expect(store.enabled[_uid], isFalse);
      await repo.updateStatus('p', AppointmentStatus.confirmed);
      await settle();
      expect(notifications.shown, isEmpty);

      await alerts.setEnabled(true);
      await settle();
      expect(notifications.scheduled, hasLength(4)); // c + p, mỗi lịch 2 lời nhắc
    });

    test('đăng xuất -> huỷ lời nhắc của tài khoản (người khác dùng máy không nhận nhầm)',
        () async {
      await open(initial: [
        _a('c', DateTime(2026, 11, 21, 9), status: AppointmentStatus.confirmed),
      ]);
      alerts.stop();
      await settle();
      expect(notifications.scheduled, isEmpty);
      expect(store.scheduledIds[_uid], isEmpty);
    });

    test('đổi giờ lịch đã xác nhận -> lời nhắc dời theo', () async {
      await open(initial: [
        _a('c', DateTime(2026, 11, 21, 9), status: AppointmentStatus.confirmed),
      ]);
      await repo.replace(_a('c', DateTime(2026, 11, 21, 14), status: AppointmentStatus.confirmed));
      await settle();
      expect(notifications.scheduled[notificationIdFor('c', AlertKind.hourBefore)]!.at,
          DateTime(2026, 11, 21, 13));
    });

    test('bấm thông báo / mở app từ thông báo -> yêu cầu mở đúng lịch', () async {
      notifications.launchPayload = payloadFor('from_launch');
      appointments = AppointmentsController(FakeAppointmentRepository(), clock: () => _now)
        ..start(customerId: _uid);
      alerts = CustomerAlertsController(notifications, store);
      final opened = <String>[];
      final sub = alerts.openRequests.listen(opened.add);
      await alerts.start(_uid, appointments);
      notifications.tap(payloadFor('tapped'));
      notifications.tap('rác');
      await settle();
      expect(opened, ['from_launch', 'tapped']);
      await sub.cancel();
    });

    test('hệ điều hành chặn thông báo -> systemEnabled = false', () async {
      notifications.granted = false;
      await open(initial: const []);
      expect(alerts.systemEnabled, isFalse);
      notifications.granted = true;
      await alerts.refreshSystemStatus();
      expect(alerts.systemEnabled, isTrue);
    });
  });
}
