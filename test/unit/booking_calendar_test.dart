import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/constants/app_strings.dart';
import 'package:medibook/core/utils/app_date_utils.dart';
import 'package:medibook/core/widgets/day_picker.dart';
import 'package:medibook/features/booking/domain/availability.dart';
import 'package:medibook/features/booking/domain/booking_window.dart';
import 'package:medibook/features/booking/domain/entities/busy_slot.dart';

import '../mocks/fake_clinic_repositories.dart';

// Chọn ngày khám qua nhiều tháng / năm (dat_lich.txt 3.2 – bổ sung 17/11/2026).

/// "Bây giờ" = Thứ Ba 17/11/2026 10:00.
final _now = DateTime(2026, 11, 17, 10);

void main() {
  group('AppDateUtils – ngày tháng', () {
    test('addDays / addMonths sang tháng và năm mới', () {
      expect(AppDateUtils.addDays(DateTime(2026, 11, 30), 1), DateTime(2026, 12, 1));
      expect(AppDateUtils.addDays(DateTime(2026, 12, 31), 1), DateTime(2027, 1, 1));
      expect(AppDateUtils.addMonths(DateTime(2026, 11, 17), 2), DateTime(2027, 1));
      expect(AppDateUtils.addMonths(DateTime(2027, 1, 31), -1), DateTime(2026, 12));
      // Ngày 31 + 1 tháng không "tràn" sang tháng kế tiếp vì luôn về ngày 1.
      expect(AppDateUtils.addMonths(DateTime(2027, 1, 31), 1), DateTime(2027, 2));
    });

    test('daysInMonth đúng cả năm nhuận', () {
      expect(AppDateUtils.daysInMonth(DateTime(2026, 11)), 30);
      expect(AppDateUtils.daysInMonth(DateTime(2026, 12)), 31);
      expect(AppDateUtils.daysInMonth(DateTime(2027, 2)), 28);
      expect(AppDateUtils.daysInMonth(DateTime(2028, 2)), 29);
    });

    test('daysBetween qua tháng / năm', () {
      expect(AppDateUtils.daysBetween(DateTime(2026, 11, 17, 23), DateTime(2026, 11, 18, 1)), 1);
      expect(AppDateUtils.daysBetween(DateTime(2026, 11, 17), DateTime(2027, 1, 1)), 45);
      expect(AppDateUtils.daysBetween(DateTime(2027, 1, 1), DateTime(2026, 11, 17)), -45);
    });

    test('monthCells: bắt đầu từ Thứ Hai, đủ ngày, thứ trong tuần đúng', () {
      // 01/11/2026 là Chủ nhật -> 6 ô trống trước (T2..T7).
      final nov = AppDateUtils.monthCells(DateTime(2026, 11, 17));
      expect(nov.take(6).every((c) => c == null), isTrue);
      expect(nov[6], DateTime(2026, 11, 1));
      expect(nov.whereType<DateTime>().length, 30);
      expect(nov.length % 7, 0);
      // 01/12/2026 là Thứ Ba -> 1 ô trống.
      final dec = AppDateUtils.monthCells(DateTime(2026, 12));
      expect(dec[0], isNull);
      expect(dec[1], DateTime(2026, 12, 1));
      expect(dec.whereType<DateTime>().length, 31);
      // Mỗi ô nằm đúng cột thứ của nó.
      for (var i = 0; i < dec.length; i++) {
        final d = dec[i];
        if (d != null) expect(d.weekday, i % 7 + 1);
      }
      // 01/02/2027 là Thứ Hai -> không có ô trống phía trước, 28 ngày = đúng 4 hàng.
      final feb = AppDateUtils.monthCells(DateTime(2027, 2));
      expect(feb.first, DateTime(2027, 2, 1));
      expect(feb.length, 28);
    });

    test('monthLabel', () {
      expect(AppDateUtils.monthLabel(DateTime(2027, 1, 5)), 'Tháng 1, 2027');
    });
  });

  group('BookingWindow – khoảng ngày được đặt', () {
    test('từ hôm nay tới ngày thứ 180 (sang năm 2027)', () {
      expect(BookingWindow.firstDay(_now), DateTime(2026, 11, 17));
      expect(BookingWindow.lastDay(_now), DateTime(2027, 5, 15));
      expect(AppDateUtils.daysBetween(BookingWindow.firstDay(_now), BookingWindow.lastDay(_now)) + 1,
          BookingWindow.days);
    });

    test('contains / clamp', () {
      expect(BookingWindow.contains(DateTime(2026, 11, 16), _now), isFalse);
      expect(BookingWindow.contains(DateTime(2026, 11, 17, 23), _now), isTrue);
      expect(BookingWindow.contains(DateTime(2027, 1, 20), _now), isTrue);
      expect(BookingWindow.contains(DateTime(2027, 5, 16), _now), isFalse);
      expect(BookingWindow.clamp(null, _now), DateTime(2026, 11, 17));
      expect(BookingWindow.clamp(DateTime(2026, 10, 1), _now), DateTime(2026, 11, 17));
      expect(BookingWindow.clamp(DateTime(2027, 3, 8, 9), _now), DateTime(2027, 3, 8));
      expect(BookingWindow.clamp(DateTime(2028, 1, 1), _now), DateTime(2027, 5, 15));
    });

    test('checkBooking chặn ngày ngoài khoảng, cho phép ngày ở tháng / năm sau', () {
      String? check(DateTime start) =>
          checkBooking(doctorId: 'd1', start: start, busyIds: const {}, mine: const [], now: _now);
      expect(check(DateTime(2027, 1, 4, 8)), isNull);
      expect(check(DateTime(2027, 5, 15, 17)), isNull);
      expect(check(DateTime(2027, 5, 16, 8)), AppStrings.errDayTooFar);
      expect(check(DateTime(2026, 11, 17, 9)), AppStrings.errSlotPast);
    });

    test('khung trống ở tháng sau tính đúng, khung bận vẫn bị loại', () {
      final day = DateTime(2027, 1, 4);
      final busy = {BusySlot.idOf('d1', DateTime(2027, 1, 4, 8))};
      final free = freeSlotStarts(doctorId: 'd1', day: day, busyIds: busy, mine: const [], now: _now);
      expect(free.length, 15);
      expect(free.contains(DateTime(2027, 1, 4, 8)), isFalse);
      // Lịch của chính khách ở ngày đó cũng làm khung không trống.
      final mine = [appt('m', DateTime(2027, 1, 4, 9), doctorId: 'd1')];
      final free2 = freeSlotStarts(doctorId: 'd1', day: day, busyIds: busy, mine: mine, now: _now);
      expect(free2.length, 14);
    });
  });

  group('Giờ mong muốn khi đổi ngày', () {
    test('wantedSlotStillValid', () {
      final today = DateTime(2026, 11, 17);
      expect(wantedSlotStillValid(today, null, _now), isTrue);
      expect(wantedSlotStillValid(today, 8 * 60, _now), isFalse); // 08:00 đã qua
      expect(wantedSlotStillValid(today, 10 * 60, _now), isFalse); // đúng giờ hiện tại
      expect(wantedSlotStillValid(today, 14 * 60, _now), isTrue);
      expect(wantedSlotStillValid(DateTime(2026, 12, 1), 8 * 60, _now), isTrue);
    });

    test('dayHasFutureSlot: hôm nay sau giờ làm thì không còn khung', () {
      final today = DateTime(2026, 11, 17);
      expect(dayHasFutureSlot(today, _now), isTrue);
      expect(dayHasFutureSlot(today, DateTime(2026, 11, 17, 17)), isFalse);
      expect(dayHasFutureSlot(DateTime(2026, 11, 18), DateTime(2026, 11, 17, 23)), isTrue);
    });
  });

  group('Nhảy tháng (DayPicker)', () {
    final first = BookingWindow.firstDay(_now);
    final last = BookingWindow.lastDay(_now);

    test('tháng sau = ngày 1 của tháng đó; tháng đầu tiên = hôm nay', () {
      expect(monthJumpTarget(DateTime(2026, 11, 20), 1, firstDay: first, lastDay: last),
          DateTime(2026, 12, 1));
      expect(monthJumpTarget(DateTime(2026, 12, 25), 1, firstDay: first, lastDay: last),
          DateTime(2027, 1, 1));
      expect(monthJumpTarget(DateTime(2027, 1, 9), -1, firstDay: first, lastDay: last),
          DateTime(2026, 12, 1));
      // Về tháng 11 thì không được chọn ngày đã qua -> về hôm nay.
      expect(monthJumpTarget(DateTime(2026, 12, 3), -1, firstDay: first, lastDay: last),
          DateTime(2026, 11, 17));
    });

    test('hết khoảng thì không nhảy được', () {
      expect(monthJumpTarget(DateTime(2026, 11, 20), -1, firstDay: first, lastDay: last), isNull);
      expect(monthJumpTarget(DateTime(2027, 5, 2), 1, firstDay: first, lastDay: last), isNull);
    });

    test('bỏ qua ngày / tháng không chọn được', () {
      // Không cho chọn Chủ nhật và cả tháng 12.
      bool enabled(DateTime d) => d.weekday != DateTime.sunday && d.month != 12;
      expect(
        monthJumpTarget(DateTime(2026, 11, 20), 1, firstDay: first, lastDay: last, isEnabled: enabled),
        DateTime(2027, 1, 1), // 01/01/2027 là Thứ Sáu
      );
      expect(
        firstSelectableInMonth(DateTime(2027, 8), firstDay: first, lastDay: last),
        isNull,
      );
    });
  });
}
