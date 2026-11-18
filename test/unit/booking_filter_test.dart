import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/app/shells/staff_nav_controller.dart';
import 'package:medibook/core/utils/app_date_utils.dart';
import 'package:medibook/core/utils/text_utils.dart';
import 'package:medibook/features/appointments/domain/booking_filter.dart';
import 'package:medibook/features/appointments/domain/entities/appointment.dart';
import 'package:medibook/features/appointments/domain/entities/appointment_status.dart';
import 'package:medibook/features/home/domain/staff_home_summary.dart';

import '../mocks/fake_clinic_repositories.dart';

/// "Bây giờ" = Thứ Bảy 14/11/2026 10:00.
final _now = DateTime(2026, 11, 14, 10);

/// Cố ý KHÔNG theo thứ tự thời gian để kiểm tra việc sắp xếp.
List<Appointment> _all() => [
      appt('tomorrow_pending', DateTime(2026, 11, 15, 8), name: 'Phạm Thị Bích'),
      appt('today_confirmed', DateTime(2026, 11, 14, 12),
          status: AppointmentStatus.confirmed, name: 'Nguyễn Thị Mai', service: 'Khám mắt'),
      appt('yesterday_rejected', DateTime(2026, 11, 13, 16),
          status: AppointmentStatus.rejected, name: 'Mai Xuân Trường'),
      appt('today_pending', DateTime(2026, 11, 14, 11), name: 'Trần Văn Minh', service: 'Khám da liễu'),
      appt('today_cancelled', DateTime(2026, 11, 14, 9),
          status: AppointmentStatus.cancelled, name: 'Đỗ Thị Lan'),
      // 02/12 đứng SAU 15/11 theo thời gian nhưng đứng TRƯỚC nếu so chuỗi "02/12" < "15/11".
      appt('next_month_pending', DateTime(2026, 12, 2, 7), name: 'Lý Gia Huy'),
      appt('today_rejected', DateTime(2026, 11, 14, 15),
          status: AppointmentStatus.rejected, name: 'Hoàng Đức Anh'),
    ];

List<String> _ids(List<Appointment> items) => items.map((a) => a.id).toList();

void main() {
  group('Ba bộ lọc chính (lich_dat.txt 3.2)', () {
    test('Tất cả: đủ mọi lịch, đủ 4 trạng thái', () {
      final result = applyBookingFilter(_all(), BookingFilter.all, _now);
      expect(result, hasLength(7));
      expect(result.map((a) => a.status).toSet(), AppointmentStatus.values.toSet());
    });

    test('Hôm nay: chỉ lịch trong ngày hiện tại, vẫn đủ mọi trạng thái', () {
      final result = applyBookingFilter(_all(), BookingFilter.today, _now);
      expect(_ids(result),
          ['today_cancelled', 'today_pending', 'today_confirmed', 'today_rejected']);
      expect(result.map((a) => a.status).toSet(), AppointmentStatus.values.toSet());
    });

    test('Chờ xác nhận: Pending ở MỌI ngày, kể cả tương lai xa', () {
      final result = applyBookingFilter(_all(), BookingFilter.pending, _now);
      expect(_ids(result), ['today_pending', 'tomorrow_pending', 'next_month_pending']);
    });

    test('Hôm nay đổi theo ngày hiện tại', () {
      final tomorrow = DateTime(2026, 11, 15, 0, 5);
      expect(_ids(applyBookingFilter(_all(), BookingFilter.today, tomorrow)), ['tomorrow_pending']);
    });
  });

  group('Sắp xếp (lich_dat.txt 3.4)', () {
    test('theo thời điểm diễn ra tăng dần, đúng cả khi khác ngày / khác tháng', () {
      final result = applyBookingFilter(_all(), BookingFilter.all, _now);
      expect(_ids(result), [
        'yesterday_rejected',
        'today_cancelled',
        'today_pending',
        'today_confirmed',
        'today_rejected',
        'tomorrow_pending',
        'next_month_pending',
      ]);
      for (var i = 1; i < result.length; i++) {
        expect(result[i].startAt.isBefore(result[i - 1].startAt), isFalse);
      }
    });

    test('không làm thay đổi danh sách gốc', () {
      final source = _all();
      final before = _ids(source);
      applyBookingFilter(source, BookingFilter.all, _now);
      expect(_ids(source), before);
    });
  });

  group('Lọc trạng thái + tìm kiếm', () {
    test('lọc trạng thái kết hợp với Hôm nay', () {
      final result = applyBookingFilter(_all(), BookingFilter.today, _now,
          statuses: {AppointmentStatus.cancelled, AppointmentStatus.rejected});
      expect(_ids(result), ['today_cancelled', 'today_rejected']);
    });

    test('tìm theo tên không phân biệt hoa thường và dấu', () {
      expect(_ids(applyBookingFilter(_all(), BookingFilter.all, _now, query: 'MAI')),
          ['yesterday_rejected', 'today_confirmed']); // "Mai Xuân Trường" và "Nguyễn Thị Mai"
      expect(_ids(applyBookingFilter(_all(), BookingFilter.all, _now, query: 'tran van')),
          ['today_pending']);
      expect(_ids(applyBookingFilter(_all(), BookingFilter.all, _now, query: 'Đỗ')),
          ['today_cancelled']);
    });

    test('tìm theo dịch vụ và mã lịch', () {
      expect(_ids(applyBookingFilter(_all(), BookingFilter.all, _now, query: 'da lieu')),
          ['today_pending']);
      expect(_ids(applyBookingFilter(_all(), BookingFilter.all, _now, query: 'next_month')),
          ['next_month_pending']);
    });

    test('từ khoá chỉ có khoảng trắng coi như không tìm; không khớp -> rỗng', () {
      expect(applyBookingFilter(_all(), BookingFilter.all, _now, query: '   '), hasLength(7));
      expect(applyBookingFilter(_all(), BookingFilter.all, _now, query: 'zzz'), isEmpty);
    });

    test('TextUtils.normalize bỏ dấu tiếng Việt', () {
      expect(TextUtils.normalize('  Nguyễn  Thị MAI '), 'nguyen thi mai');
      expect(TextUtils.normalize('Đặng Quốc Bảo'), 'dang quoc bao');
    });
  });

  group('Khớp số liệu với Trang tổng quan (lich_dat.txt 4.2)', () {
    test('số lịch của từng bộ lọc bằng đúng chỉ số trên Tổng quan', () {
      final all = _all();
      final summary = StaffHomeSummary.from(all, _now);
      int today([Set<AppointmentStatus> s = const {}]) =>
          applyBookingFilter(all, BookingFilter.today, _now, statuses: s).length;

      expect(today(), summary.todayTotal);
      expect(today({AppointmentStatus.pending}), summary.todayPending);
      expect(today({AppointmentStatus.confirmed}), summary.todayConfirmed);
      expect(today({AppointmentStatus.cancelled, AppointmentStatus.rejected}),
          summary.todayCancelledOrRejected);
      expect(applyBookingFilter(all, BookingFilter.pending, _now).length, summary.pendingAllDays);
      // Hai phép đếm Pending có phạm vi khác nhau.
      expect(summary.todayPending, 1);
      expect(summary.pendingAllDays, 3);
    });

    test('lịch Hủy / Từ chối không nằm trong danh sách sắp diễn ra', () {
      final summary = StaffHomeSummary.from(_all(), _now);
      expect(_ids(summary.upcoming), ['today_pending', 'today_confirmed', 'tomorrow_pending']);
      expect(summary.upcoming.every((a) => a.isActive), isTrue);
    });
  });

  group('Gom theo ngày + nhãn ngày', () {
    test('giữ nguyên thứ tự, mỗi ngày một nhóm', () {
      final groups = groupBookingsByDay(applyBookingFilter(_all(), BookingFilter.all, _now));
      expect(groups.map((g) => g.items.length), [1, 4, 1, 1]);
      expect(groups.map((g) => g.day), [
        DateTime(2026, 11, 13),
        DateTime(2026, 11, 14),
        DateTime(2026, 11, 15),
        DateTime(2026, 12, 2),
      ]);
    });

    test('nhãn ngày: Hôm qua / Hôm nay / Ngày mai / thứ trong tuần', () {
      expect(AppDateUtils.dayLabel(DateTime(2026, 11, 13, 16), _now), 'Hôm qua, 13/11/2026');
      expect(AppDateUtils.dayLabel(DateTime(2026, 11, 14, 23, 59), _now), 'Hôm nay, 14/11/2026');
      expect(AppDateUtils.dayLabel(DateTime(2026, 11, 15, 0, 1), _now), 'Ngày mai, 15/11/2026');
      expect(AppDateUtils.dayLabel(DateTime(2026, 12, 2, 7), _now), 'Thứ Tư, 02/12/2026');
      expect(AppDateUtils.weekdayDate(_now), 'Thứ Bảy, 14/11/2026');
    });
  });

  group('StaffNavController – điều kiện lọc', () {
    test('mở Lịch đặt từ Tổng quan: đặt bộ lọc, xoá từ khoá cũ, chuyển tab', () {
      final nav = StaffNavController()..setQuery('mai');
      nav.openBookings(BookingFilter.today, statuses: {AppointmentStatus.confirmed});
      expect(nav.index, StaffNavController.bookingsTab);
      expect(nav.filter, BookingFilter.today);
      expect(nav.statuses, {AppointmentStatus.confirmed});
      expect(nav.query, isEmpty);
    });

    test('chọn Chờ xác nhận thì bỏ lọc trạng thái; lọc trạng thái khi đang Chờ xác nhận -> Tất cả', () {
      final nav = StaffNavController()..setStatuses({AppointmentStatus.confirmed});
      nav.setFilter(BookingFilter.pending);
      expect(nav.statuses, isEmpty);

      nav.setStatuses({AppointmentStatus.rejected});
      expect(nav.filter, BookingFilter.all);
      expect(nav.statuses, {AppointmentStatus.rejected});
    });
  });

  test('mã ngắn của lịch hẹn', () {
    expect(appt('demo_05', _now).shortCode, '#DEMO_05');
    // id tự sinh của Firestore (20 ký tự) -> lấy 6 ký tự cuối, viết hoa.
    expect(appt('k3F9qZ1aB2cD3eF4gH5i', _now).shortCode, '#F4GH5I');
  });

  group('Lượt 19: bác sĩ, đếm theo trạng thái, quá giờ', () {
    test('tìm theo tên bác sĩ, không dấu, không phân biệt hoa thường', () {
      final list = [
        appt('a', DateTime(2026, 11, 14, 11), doctorId: 'Hoàng Thu Giang'),
        appt('b', DateTime(2026, 11, 14, 12)), // chưa gắn bác sĩ -> không lỗi
      ];
      expect(_ids(applyBookingFilter(list, BookingFilter.all, _now, query: 'hoang thu')), ['a']);
      expect(_ids(applyBookingFilter(list, BookingFilter.all, _now, query: 'BS. HOÀNG')), ['a']);
    });

    test('countByStatus đếm đủ 4 trạng thái, tổng bằng số lịch', () {
      final today = applyBookingFilter(_all(), BookingFilter.today, _now);
      final c = countByStatus(today);
      expect(c[AppointmentStatus.pending], 1);
      expect(c[AppointmentStatus.confirmed], 1);
      expect(c[AppointmentStatus.cancelled], 1);
      expect(c[AppointmentStatus.rejected], 1);
      expect(c.values.fold<int>(0, (a, b) => a + b), today.length);
      expect(countByStatus(const []).values.every((v) => v == 0), isTrue);
    });

    test('isOverdueAt: chỉ lịch Chờ xác nhận đã tới / qua giờ bắt đầu', () {
      final past = DateTime(2026, 11, 14, 9);
      expect(appt('p', past).isOverdueAt(_now), isTrue);
      expect(appt('p', _now).isOverdueAt(_now), isTrue); // đúng giờ bắt đầu
      expect(appt('p', DateTime(2026, 11, 14, 11)).isOverdueAt(_now), isFalse);
      for (final s in [
        AppointmentStatus.confirmed,
        AppointmentStatus.cancelled,
        AppointmentStatus.rejected,
      ]) {
        expect(appt('x', past, status: s).isOverdueAt(_now), isFalse);
      }
    });

    test('lịch chờ đã quá giờ bị bỏ khỏi MỌI bộ lọc và mọi số liệu Trang chủ (quy tắc 18/11)', () {
      final list = [
        ..._all(),
        appt('late', DateTime(2026, 11, 12, 8)),
        appt('late_today', DateTime(2026, 11, 14, 8)),
      ];
      for (final f in BookingFilter.values) {
        final ids = _ids(applyBookingFilter(list, f, _now));
        expect(ids, isNot(contains('late')), reason: '$f');
        expect(ids, isNot(contains('late_today')), reason: '$f');
      }
      // Tìm đích danh hay lọc trạng thái Chờ xác nhận cũng không ra.
      expect(applyBookingFilter(list, BookingFilter.all, _now, query: 'late'), isEmpty);
      expect(
        _ids(applyBookingFilter(list, BookingFilter.all, _now,
            statuses: {AppointmentStatus.pending})),
        ['today_pending', 'tomorrow_pending', 'next_month_pending'],
      );
      final s = StaffHomeSummary.from(list, _now);
      expect(s.pendingAllDays, applyBookingFilter(list, BookingFilter.pending, _now).length);
      expect(s.todayTotal, applyBookingFilter(list, BookingFilter.today, _now).length);
      // Lịch đã xác nhận / hủy / từ chối đã qua giờ vẫn hiện bình thường.
      expect(_ids(applyBookingFilter(list, BookingFilter.all, _now)), contains('yesterday_rejected'));
    });

    test('StaffNavController.openBookings tăng openRequest; đổi bộ lọc tại chỗ thì không', () {
      final nav = StaffNavController();
      final before = nav.openRequest;
      nav.openBookings(BookingFilter.pending);
      expect(nav.openRequest, before + 1);
      nav.setFilter(BookingFilter.all);
      nav.setQuery('abc');
      expect(nav.openRequest, before + 1);
    });
  });
}
