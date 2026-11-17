import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/utils/app_date_utils.dart';
import 'package:medibook/core/utils/name_utils.dart';
import 'package:medibook/features/appointments/domain/entities/appointment_status.dart';
import 'package:medibook/features/home/domain/demo_data.dart';
import 'package:medibook/features/home/domain/staff_home_summary.dart';

void main() {
  final now = DateTime(2026, 11, 14, 10, 10);

  group('DemoData', () {
    test('mọi bản ghi đều đánh dấu isDemo và có id không trùng', () {
      final data = DemoData.build(now);
      expect(data.appointments.every((a) => a.isDemo), isTrue);
      expect(data.notifications.every((n) => n.isDemo), isTrue);
      expect(data.appointments.map((a) => a.id).toSet().length, data.appointments.length);
      expect(data.appointments.every((a) => a.id.startsWith('demo_')), isTrue);
    });

    test('có đủ 4 trạng thái và trải trên nhiều ngày theo thời điểm hiện tại', () {
      final data = DemoData.build(now);
      expect(data.appointments.map((a) => a.status).toSet(), AppointmentStatus.values.toSet());
      final days = data.appointments
          .map((a) => DateTime(a.startAt.year, a.startAt.month, a.startAt.day))
          .toSet();
      expect(days.length, greaterThanOrEqualTo(3));
      expect(data.appointments.any((a) => AppDateUtils.isSameDay(a.startAt, now)), isTrue);
    });

    test('lúc 10:10 có lịch sắp diễn ra và có lịch chờ xử lý', () {
      final s = StaffHomeSummary.from(DemoData.build(now).appointments, now);
      expect(s.upcoming.length, 3);
      expect(s.pendingAllDays, greaterThan(0));
      expect(s.todayTotal, s.todayPending + s.todayConfirmed + s.todayCancelledOrRejected);
    });
  });

  group('Tiện ích', () {
    test('định dạng giờ, ngày, khoảng giờ', () {
      final d = DateTime(2026, 4, 2, 8, 5);
      expect(AppDateUtils.time(d), '08:05');
      expect(AppDateUtils.date(d), '02/04/2026');
      expect(AppDateUtils.timeRange(d, d.add(const Duration(minutes: 30))), '08:05 – 08:35');
    });

    test('thời gian tương đối của thông báo', () {
      expect(AppDateUtils.timeAgo(now, now), 'Vừa xong');
      expect(AppDateUtils.timeAgo(now.subtract(const Duration(minutes: 5)), now), '5 phút trước');
      expect(AppDateUtils.timeAgo(now.subtract(const Duration(hours: 2)), now), '2 giờ trước');
    });

    test('chữ cái đầu của tên', () {
      expect(NameUtils.initial('Nguyễn Thị Mai'), 'M');
      expect(NameUtils.initial('  an '), 'A');
      expect(NameUtils.initial(''), '?');
    });
  });
}
