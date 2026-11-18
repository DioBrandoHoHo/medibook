import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/utils/app_date_utils.dart';
import 'package:medibook/features/appointments/domain/booking_filter.dart';
import 'package:medibook/features/appointments/domain/entities/appointment.dart';
import 'package:medibook/features/appointments/domain/entities/appointment_status.dart';
import 'package:medibook/features/home/domain/staff_home_summary.dart';

import '../mocks/fake_clinic_repositories.dart';

void main() {
  // "Bây giờ" = 14/11/2026 10:00
  final now = DateTime(2026, 11, 14, 10);
  DateTime today(int h, [int m = 0]) => DateTime(2026, 11, 14, h, m);
  DateTime tomorrow(int h) => DateTime(2026, 11, 15, h);
  DateTime yesterday(int h) => DateTime(2026, 11, 13, h);

  const pending = AppointmentStatus.pending;
  const confirmed = AppointmentStatus.confirmed;
  const rejected = AppointmentStatus.rejected;
  const cancelled = AppointmentStatus.cancelled;

  List<Appointment> sample() => [
    appt('t1', today(8), status: confirmed), // hôm nay, đã qua
    appt('t2', today(9), status: cancelled), // hôm nay, đã qua
    appt('t3', today(11), status: pending),
    appt('t4', today(12), status: confirmed),
    appt('t5', today(13), status: rejected),
    appt('m1', tomorrow(8), status: pending),
    appt('m2', tomorrow(9), status: confirmed),
    appt('y1', yesterday(15), status: pending), // hôm qua, vẫn chờ
  ];

  group('Tổng quan hôm nay', () {
    test('chỉ đếm lịch thuộc ngày hiện tại, phân theo trạng thái', () {
      final s = StaffHomeSummary.from(sample(), now);
      expect(s.todayTotal, 5);
      expect(s.todayPending, 1);
      expect(s.todayConfirmed, 2);
      expect(s.todayCancelledOrRejected, 2);
    });

    test('tổng hôm nay luôn bằng tổng ba nhóm trạng thái', () {
      final s = StaffHomeSummary.from(sample(), now);
      expect(s.todayTotal, s.todayPending + s.todayConfirmed + s.todayCancelledOrRejected);
    });

    test('không có lịch -> mọi chỉ số bằng 0, danh sách rỗng', () {
      final s = StaffHomeSummary.from(const [], now);
      expect(s.todayTotal, 0);
      expect(s.pendingAllDays, 0);
      expect(s.upcoming, isEmpty);
    });
  });

  group('Thẻ lịch cần xử lý', () {
    test('đếm Pending ở MỌI ngày, khác với chỉ số Chờ xác nhận hôm nay', () {
      final s = StaffHomeSummary.from(sample(), now);
      expect(s.pendingAllDays, 3); // t3 + m1 + y1
      expect(s.todayPending, 1); // chỉ t3
    });
  });

  group('Lịch hẹn sắp diễn ra', () {
    test('chỉ lấy lịch tương lai, bỏ Hủy/Từ chối, sắp xếp tăng dần, tối đa 3', () {
      final s = StaffHomeSummary.from(sample().reversed.toList(), now);
      expect(s.upcoming.map((a) => a.id), ['t3', 't4', 'm1']);
    });

    test('lịch bắt đầu đúng thời điểm hiện tại coi như đã diễn ra', () {
      final s = StaffHomeSummary.from([appt('x', now, status: confirmed)], now);
      expect(s.upcoming, isEmpty);
    });

    test('ít hơn 3 lịch phù hợp -> hiển thị đúng số đó', () {
      final s = StaffHomeSummary.from([appt('a', today(11)), appt('b', today(9))], now);
      expect(s.upcoming.map((a) => a.id), ['a']);
    });
  });

  group('Tính động (Mục 3 đặc tả)', () {
    test('Tình huống 1: Customer đặt lịch mới hôm nay', () {
      final before = StaffHomeSummary.from(sample(), now);
      final after = StaffHomeSummary.from([...sample(), appt('new', today(10, 30))], now);
      expect(after.pendingAllDays, before.pendingAllDays + 1);
      expect(after.todayPending, before.todayPending + 1);
      expect(after.todayTotal, before.todayTotal + 1);
      expect(after.upcoming.first.id, 'new');
    });

    test('Tình huống 2: Staff xác nhận lịch', () {
      final list = sample();
      final before = StaffHomeSummary.from(list, now);
      final i = list.indexWhere((a) => a.id == 't3');
      list[i] = list[i].copyWith(status: confirmed);
      final after = StaffHomeSummary.from(list, now);
      expect(after.todayPending, before.todayPending - 1);
      expect(after.pendingAllDays, before.pendingAllDays - 1);
      expect(after.todayConfirmed, before.todayConfirmed + 1);
      expect(after.todayTotal, before.todayTotal);
      expect(after.upcoming.map((a) => a.id), contains('t3'));
    });

    test('Tình huống 3: Staff từ chối lịch -> biến mất, lịch kế tiếp lên thay', () {
      final list = sample();
      final before = StaffHomeSummary.from(list, now);
      final i = list.indexWhere((a) => a.id == 't3');
      list[i] = list[i].copyWith(status: rejected);
      final after = StaffHomeSummary.from(list, now);
      expect(after.todayPending, before.todayPending - 1);
      expect(after.todayCancelledOrRejected, before.todayCancelledOrRejected + 1);
      expect(after.upcoming.map((a) => a.id), ['t4', 'm1', 'm2']);
    });

    test('Tình huống 4: Customer hủy lịch đã xác nhận', () {
      final list = sample();
      final before = StaffHomeSummary.from(list, now);
      final i = list.indexWhere((a) => a.id == 't4');
      list[i] = list[i].copyWith(status: cancelled);
      final after = StaffHomeSummary.from(list, now);
      expect(after.todayConfirmed, before.todayConfirmed - 1);
      expect(after.todayCancelledOrRejected, before.todayCancelledOrRejected + 1);
      expect(after.upcoming.map((a) => a.id), isNot(contains('t4')));
    });

    test('Tình huống 5: sang ngày mới -> tính lại theo ngày mới', () {
      final s = StaffHomeSummary.from(sample(), DateTime(2026, 11, 15, 0, 5));
      expect(s.todayTotal, 2); // m1, m2
      expect(s.todayPending, 1);
      expect(s.todayConfirmed, 1);
      expect(s.upcoming.map((a) => a.id), ['m1', 'm2']);
    });
  });

  group('Bộ lọc màn Lịch đặt', () {
    test('Hôm nay: chỉ lịch trong ngày', () {
      final r = applyBookingFilter(sample(), BookingFilter.today, now);
      expect(r.map((a) => a.id), ['t1', 't2', 't3', 't4', 't5']);
    });

    test('Chờ xác nhận: Pending ở mọi ngày, khớp với số trên thẻ', () {
      final r = applyBookingFilter(sample(), BookingFilter.pending, now);
      expect(r.length, StaffHomeSummary.from(sample(), now).pendingAllDays);
    });

    test('Tất cả: đủ danh sách, sắp xếp theo thời gian', () {
      final r = applyBookingFilter(sample().reversed.toList(), BookingFilter.all, now);
      expect(r.length, 8);
      expect(r.first.id, 'y1');
    });
  });

  group('Thẻ cần xử lý – chi tiết (Lượt 18)', () {
    test('chia số lịch chờ thành hôm nay / ngày khác; quá giờ; lịch chờ gần nhất', () {
      final s = StaffHomeSummary.from(sample(), now);
      expect(s.pendingAllDays, 3); // t3, m1, y1
      expect(s.todayPending, 1);
      expect(s.pendingOtherDays, 2);
      expect(s.todayPending + s.pendingOtherDays, s.pendingAllDays);
      expect(s.pendingOverdue, 1); // y1 đã qua giờ mà chưa xử lý
      expect(s.nextPending?.id, 't3');
    });

    test('lịch chờ vừa tới giờ thì chuyển sang "quá giờ", lịch chờ gần nhất là lịch kế tiếp', () {
      final s = StaffHomeSummary.from(sample(), today(11));
      expect(s.pendingOverdue, 2); // y1 + t3
      expect(s.nextPending?.id, 'm1');
    });

    test('xác nhận lịch chờ duy nhất còn tới -> không còn lịch chờ gần nhất', () {
      final list = sample()
          .map((a) => a.isPending && a.startAt.isAfter(now) ? a.copyWith(status: confirmed) : a)
          .toList();
      final s = StaffHomeSummary.from(list, now);
      expect(s.nextPending, isNull);
      expect(s.pendingAllDays, 1);
      expect(s.pendingOverdue, 1);
    });

    test('còn lại hôm nay = lịch hôm nay còn hiệu lực chưa tới giờ', () {
      expect(StaffHomeSummary.from(sample(), now).todayRemaining, 2); // t3, t4
      expect(StaffHomeSummary.from(sample(), today(12, 30)).todayRemaining, 0);
      expect(StaffHomeSummary.from(const [], now).todayRemaining, 0);
    });
  });

  group('Nhãn ngày gọn + thời gian còn lại', () {
    test('shortDayLabel', () {
      expect(AppDateUtils.shortDayLabel(today(11), now), 'Hôm nay');
      expect(AppDateUtils.shortDayLabel(tomorrow(8), now), 'Ngày mai');
      expect(AppDateUtils.shortDayLabel(yesterday(8), now), 'Hôm qua');
      expect(AppDateUtils.shortDayLabel(DateTime(2026, 11, 19, 8), now), 'T5, 19/11');
      expect(AppDateUtils.shortDayLabel(DateTime(2027, 1, 4, 8), now), 'T2, 04/01/2027');
    });

    test('startsIn: chỉ cho lịch hôm nay chưa bắt đầu, làm tròn lên theo phút', () {
      expect(AppDateUtils.startsIn(today(10, 25), now), 'còn 25 phút');
      expect(AppDateUtils.startsIn(today(11), now), 'còn 1 giờ');
      expect(AppDateUtils.startsIn(today(11, 30), now), 'còn 1 giờ 30 phút');
      expect(AppDateUtils.startsIn(now.add(const Duration(seconds: 20)), now), 'còn 1 phút');
      expect(AppDateUtils.startsIn(today(9), now), isNull); // đã bắt đầu
      expect(AppDateUtils.startsIn(now, now), isNull);
      expect(AppDateUtils.startsIn(tomorrow(8), now), isNull); // ngày khác
    });
  });
}
