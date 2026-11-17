import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/constants/app_strings.dart';
import 'package:medibook/core/errors/app_failure.dart';
import 'package:medibook/features/appointments/domain/customer_appointments.dart';
import 'package:medibook/features/appointments/domain/entities/appointment.dart';
import 'package:medibook/features/appointments/domain/entities/appointment_status.dart';
import 'package:medibook/features/appointments/presentation/controllers/appointments_controller.dart';
import 'package:medibook/features/booking/domain/availability.dart';
import 'package:medibook/features/home/domain/customer_home_summary.dart';

import '../mocks/fake_clinic_repositories.dart';

/// "Bây giờ" = Thứ Bảy 14/11/2026 10:00.
final _now = DateTime(2026, 11, 14, 10);
DateTime _today(int h, [int m = 0]) => DateTime(2026, 11, 14, h, m);

List<Appointment> _all() => [
      appt('up_p', _today(14)),
      appt('up_c', DateTime(2026, 12, 1, 9), status: AppointmentStatus.confirmed),
      appt('past_c', _today(8), status: AppointmentStatus.confirmed),
      appt('past_p', DateTime(2026, 10, 30, 9)),
      appt('now_c', _today(10), status: AppointmentStatus.confirmed), // đúng giờ bắt đầu
      appt('canc', _today(15), status: AppointmentStatus.cancelled),
      appt('rej', _today(9), status: AppointmentStatus.rejected),
    ];

List<String> _ids(CustomerAppointmentFilter f) =>
    customerAppointments(_all(), f, _now).map((a) => a.id).toList();

void main() {
  group('Phân nhóm lịch hẹn của khách (lich_hen 3.2–3.3)', () {
    test('Sắp tới: còn hiệu lực + chưa tới giờ, gần nhất trên cùng', () {
      expect(_ids(CustomerAppointmentFilter.upcoming), ['up_p', 'up_c']);
    });

    test('Đã qua: còn hiệu lực + đã tới / qua giờ, mới nhất trên cùng', () {
      expect(_ids(CustomerAppointmentFilter.past), ['now_c', 'past_c', 'past_p']);
    });

    test('Đã hủy: Đã hủy + Đã từ chối ở mọi thời điểm, mới nhất trên cùng', () {
      expect(_ids(CustomerAppointmentFilter.cancelled), ['canc', 'rej']);
    });

    test('ba nhóm không giao nhau và phủ hết mọi lịch', () {
      final total = CustomerAppointmentFilter.values
          .map((f) => customerAppointments(_all(), f, _now).length)
          .reduce((a, b) => a + b);
      expect(total, _all().length);
    });

    test('số lịch Sắp tới = chỉ số Sắp tới của Trang chủ', () {
      expect(
        _ids(CustomerAppointmentFilter.upcoming).length,
        CustomerHomeSummary.from(_all(), _now).upcomingTotal,
      );
    });
  });

  group('Quy tắc hủy lịch (lich_hen 3.4)', () {
    test('Chờ xác nhận: hủy được tới trước giờ khám, kể cả khi còn dưới 2 giờ', () {
      expect(canCancel(appt('a', _today(10, 30)), _now), isTrue);
      expect(canCancel(appt('a', _today(14)), _now), isTrue);
    });

    test('Đã xác nhận: còn từ 2 giờ trở lên thì hủy được', () {
      final a = appt('a', _today(12), status: AppointmentStatus.confirmed); // đúng 2 giờ
      expect(cancelBlockReason(a, _now), isNull);
      expect(canCancel(appt('b', _today(15), status: AppointmentStatus.confirmed), _now), isTrue);
    });

    test('Đã xác nhận: còn dưới 2 giờ thì KHÔNG hủy được, báo đúng lý do', () {
      final a = appt('a', _today(11, 30), status: AppointmentStatus.confirmed); // còn 1 giờ 30
      expect(cancelBlockReason(a, _now), AppStrings.errCancelTooLate);
      final b = appt('b', _today(11, 59), status: AppointmentStatus.confirmed);
      expect(canCancel(b, _now), isFalse);
    });

    test('lịch đã tới giờ / đã qua không hủy được', () {
      expect(cancelBlockReason(appt('a', _today(10)), _now), AppStrings.errCancelPast);
      expect(
        cancelBlockReason(appt('a', _today(8), status: AppointmentStatus.confirmed), _now),
        AppStrings.errCancelPast,
      );
    });

    test('lịch Đã hủy / Đã từ chối không hủy được nữa', () {
      for (final s in [AppointmentStatus.cancelled, AppointmentStatus.rejected]) {
        expect(cancelBlockReason(appt('a', _today(15), status: s), _now), AppStrings.errAlreadyHandled);
      }
    });

    test('hạn hủy khai báo một chỗ = 2 giờ', () {
      expect(cancelDeadline, const Duration(hours: 2));
    });
  });

  group('AppointmentsController.cancel', () {
    Future<(AppointmentsController, FakeAppointmentRepository, FakeNotificationRepository)> setUp(
      List<Appointment> initial,
    ) async {
      final notifications = FakeNotificationRepository();
      final repo = FakeAppointmentRepository(initial: initial, notifications: notifications);
      final controller = AppointmentsController(repo, clock: () => _now)..start(customerId: 'me');
      await Future<void>.delayed(Duration.zero);
      return (controller, repo, notifications);
    }

    test('hủy thành công: trạng thái Đã hủy, khung giờ được trả lại, có thông báo cho nhân viên',
        () async {
      final (controller, repo, notifications) = await setUp([
        appt('a', _today(15), status: AppointmentStatus.confirmed, doctorId: 'd1', customerId: 'me', name: 'Nguyễn Văn Bình', service: 'Khám da liễu'),
      ]);
      expect(busySlotsOf(repo.items), hasLength(1));

      expect(await controller.cancel('a'), isNull);
      await Future<void>.delayed(Duration.zero);

      expect(repo.items.single.status, AppointmentStatus.cancelled);
      expect(controller.items.single.status, AppointmentStatus.cancelled);
      expect(busySlotsOf(repo.items), isEmpty);
      final n = notifications.items.single;
      expect(n.title, AppStrings.notifCancelledTitle);
      expect(n.body, 'Nguyễn Văn Bình đã hủy lịch Khám da liễu lúc 15:00 ngày 14/11/2026.');
      expect(n.appointmentId, 'a');
      expect(n.isRead, isFalse);
      controller.dispose();
    });

    test('lịch đã xác nhận còn dưới 2 giờ: từ chối hủy, không ghi gì, không có thông báo', () async {
      final (controller, repo, notifications) = await setUp([
        appt('a', _today(11), status: AppointmentStatus.confirmed, doctorId: 'd1', customerId: 'me'),
      ]);
      expect(await controller.cancel('a'), AppStrings.errCancelTooLate);
      expect(repo.items.single.status, AppointmentStatus.confirmed);
      expect(notifications.items, isEmpty);
      controller.dispose();
    });

    test('nhân viên vừa từ chối trước khi khách bấm hủy: báo đã được xử lý', () async {
      final (controller, repo, notifications) = await setUp([
        appt('a', _today(15), doctorId: 'd1', customerId: 'me'),
      ]);
      await repo.updateStatus('a', AppointmentStatus.rejected);
      await Future<void>.delayed(Duration.zero);
      expect(await controller.cancel('a'), AppStrings.errAlreadyHandled);
      expect(notifications.items, isEmpty);
      controller.dispose();
    });

    test('mất mạng khi hủy: trả về thông báo lỗi, lịch giữ nguyên', () async {
      final (controller, repo, _) = await setUp([
        appt('a', _today(15), doctorId: 'd1', customerId: 'me'),
      ]);
      repo.nextUpdateError = const NetworkFailure();
      expect(await controller.cancel('a'), AppStrings.errNetwork);
      expect(repo.items.single.status, AppointmentStatus.pending);
      controller.dispose();
    });

    test('lịch không tồn tại', () async {
      final (controller, _, _) = await setUp(const []);
      expect(await controller.cancel('x'), AppStrings.appointmentNotFound);
      controller.dispose();
    });
  });
}
