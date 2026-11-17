import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/constants/app_strings.dart';
import 'package:medibook/core/utils/text_utils.dart';
import 'package:medibook/features/appointments/domain/entities/appointment_status.dart';
import 'package:medibook/features/booking/domain/availability.dart';
import 'package:medibook/features/booking/domain/entities/busy_slot.dart';
import 'package:medibook/features/booking/domain/entities/doctor.dart';
import 'package:medibook/features/home/domain/customer_home_summary.dart';
import 'package:medibook/features/home/domain/demo_data.dart';
import 'package:medibook/features/schedule/domain/schedule_builder.dart';
import 'package:medibook/features/schedule/domain/work_shift.dart';

import '../mocks/fake_clinic_repositories.dart';

/// "Bây giờ" = Thứ Bảy 14/11/2026 10:00.
final _now = DateTime(2026, 11, 14, 10);
final _day = DateTime(2026, 11, 14);
DateTime _today(int h, [int m = 0]) => DateTime(2026, 11, 14, h, m);
DateTime _tomorrow(int h, [int m = 0]) => DateTime(2026, 11, 15, h, m);

const _doctors = [
  Doctor(id: 'd1', name: 'BS. Nguyễn Văn An', specialty: 'Nội tổng quát'),
  Doctor(id: 'd2', name: 'BS. Trần Thị Bình', specialty: 'Da liễu'),
  Doctor(id: 'd3', name: 'BS. Lê Minh Châu', specialty: 'Nội tổng quát'),
];

Set<String> _ids(List<BusySlot> slots) => {for (final s in slots) s.id};

void main() {
  group('Khung bận sinh từ lịch hẹn (busySlotsOf)', () {
    test('lịch Chờ xác nhận / Đã xác nhận giữ khung; Đã hủy / Đã từ chối thì không', () {
      final busy = busySlotsOf([
        appt('p', _today(14), doctorId: 'd1'),
        appt('c', _today(15), status: AppointmentStatus.confirmed, doctorId: 'd1'),
        appt('x', _today(16), status: AppointmentStatus.cancelled, doctorId: 'd1'),
        appt('r', _today(16, 30), status: AppointmentStatus.rejected, doctorId: 'd1'),
      ]);
      expect(_ids(busy), {BusySlot.idOf('d1', _today(14)), BusySlot.idOf('d1', _today(15))});
    });

    test('lịch không gắn bác sĩ không giữ khung nào', () {
      expect(busySlotsOf([appt('n', _today(14))]), isEmpty);
    });

    test('lịch lệch lưới chiếm mọi khung nó chạm vào', () {
      final busy = busySlotsOf([appt('o', _today(8, 10), doctorId: 'd1')]); // 08:10–08:40
      expect(_ids(busy), {BusySlot.idOf('d1', _today(8)), BusySlot.idOf('d1', _today(8, 30))});
    });

    test('id khung khác nhau theo bác sĩ và theo giờ', () {
      expect(BusySlot.idOf('d1', _today(14)), isNot(BusySlot.idOf('d2', _today(14))));
      expect(BusySlot.idOf('d1', _today(14)), isNot(BusySlot.idOf('d1', _today(14, 30))));
    });
  });

  group('Trạng thái khung của Customer (buildBookSlots)', () {
    test('buổi chiều có 8 khung; khung có người đặt = taken, còn lại = free', () {
      final slots = buildBookSlots(
        doctorId: 'd1',
        day: _day,
        shift: WorkShift.afternoon,
        busyIds: {BusySlot.idOf('d1', _today(14))},
        mine: const [],
        now: _now,
      );
      expect(slots.length, 8);
      expect(slots.firstWhere((s) => s.start == _today(14)).state, BookSlotState.taken);
      expect(slots.where((s) => s.isFree).length, 7);
    });

    test('khung đã tới giờ bắt đầu = past (không đặt được), khung kế tiếp vẫn free', () {
      final slots = buildBookSlots(
        doctorId: 'd1',
        day: _day,
        shift: WorkShift.morning,
        busyIds: const {},
        mine: const [],
        now: _now, // 10:00
      );
      expect(slots.firstWhere((s) => s.start == _today(9, 30)).state, BookSlotState.past);
      expect(slots.firstWhere((s) => s.start == _today(10)).state, BookSlotState.past);
      expect(slots.firstWhere((s) => s.start == _today(10, 30)).state, BookSlotState.free);
    });

    test('lịch của chính khách hiện là mine; lịch đã hủy của khách thì khung trống lại', () {
      final mine = [
        appt('m', _today(14), doctorId: 'd1', customerId: 'me'),
        appt('mx', _today(15), status: AppointmentStatus.cancelled, doctorId: 'd1', customerId: 'me'),
      ];
      final slots = buildBookSlots(
        doctorId: 'd1',
        day: _day,
        shift: WorkShift.afternoon,
        busyIds: _ids(busySlotsOf(mine)),
        mine: mine,
        now: _now,
      );
      expect(slots.firstWhere((s) => s.start == _today(14)).state, BookSlotState.mine);
      expect(slots.firstWhere((s) => s.start == _today(15)).state, BookSlotState.free);
    });

    test('khung bận của bác sĩ khác / ngày khác không ảnh hưởng', () {
      final free = freeSlotStarts(
        doctorId: 'd1',
        day: _day,
        busyIds: {BusySlot.idOf('d2', _today(14)), BusySlot.idOf('d1', _tomorrow(14))},
        mine: const [],
        now: _now,
      );
      // 10:30, 11:00 buổi sáng + 8 khung buổi chiều.
      expect(free.length, 10);
      expect(free.first, _today(10, 30));
    });

    test('số ca trống Customer thấy khớp số khung Trống ở tab Lịch làm việc của Staff', () {
      final all = [
        appt('a', _today(14), status: AppointmentStatus.confirmed, doctorId: 'd1'),
        appt('b', _today(15, 30), doctorId: 'd1'),
        appt('c', _today(16), status: AppointmentStatus.rejected, doctorId: 'd1'),
      ];
      final staffFree = SlotSummary.of(
        buildSlots(
          doctorId: 'd1',
          day: _day,
          shift: WorkShift.afternoon,
          appointments: all,
          now: _now,
        ),
      ).free;
      final customerFree = buildBookSlots(
        doctorId: 'd1',
        day: _day,
        shift: WorkShift.afternoon,
        busyIds: _ids(busySlotsOf(all)),
        mine: const [],
        now: _now,
      ).where((s) => s.isFree).length;
      expect(customerFree, staffFree);
      expect(customerFree, 6);
    });
  });

  group('Lọc bác sĩ (applyDoctorFilter)', () {
    final busy = {
      BusySlot.idOf('d1', _today(14)),
      // d2 kín cả ngày còn lại.
      for (final s in [...WorkShift.morning.slotStartsOn(_day), ...WorkShift.afternoon.slotStartsOn(_day)])
        BusySlot.idOf('d2', s),
    };

    List<String> run(DoctorFilter filter) => applyDoctorFilter(
          doctors: _doctors,
          filter: filter,
          busyIds: busy,
          mine: const [],
          now: _now,
        ).map((e) => e.doctor.id).toList();

    test('không lọc: đủ bác sĩ, bác sĩ còn trống xếp trước bác sĩ hết ca', () {
      expect(run(DoctorFilter(day: _day)), ['d3', 'd1', 'd2']);
    });

    test('chọn giờ mong muốn: chỉ còn bác sĩ trống đúng khung đó', () {
      expect(run(DoctorFilter(day: _day, slotMinutes: 14 * 60)), ['d3']);
      expect(run(DoctorFilter(day: _day, slotMinutes: 14 * 60 + 30)), ['d3', 'd1']);
    });

    test('chọn giờ đã qua trong hôm nay: không bác sĩ nào phù hợp', () {
      expect(run(DoctorFilter(day: _day, slotMinutes: 8 * 60)), isEmpty);
    });

    test('đổi sang ngày khác: bác sĩ kín hôm nay lại trống', () {
      expect(run(DoctorFilter(day: DateTime(2026, 11, 15), slotMinutes: 14 * 60)), ['d3', 'd1', 'd2']);
    });

    test('lọc chuyên khoa, tìm không dấu, chỉ bác sĩ còn trống', () {
      expect(run(DoctorFilter(day: _day, specialty: 'Nội tổng quát')), ['d3', 'd1']);
      expect(run(DoctorFilter(day: _day, query: 'binh')), ['d2']);
      expect(run(DoctorFilter(day: _day, query: 'da lieu')), ['d2']);
      expect(run(DoctorFilter(day: _day, onlyFree: true)), ['d3', 'd1']);
      expect(run(DoctorFilter(day: _day, query: 'khong co')), isEmpty);
    });

    test('số ca trống và ca gần nhất đi kèm từng bác sĩ', () {
      final items = applyDoctorFilter(
        doctors: _doctors,
        filter: DoctorFilter(day: _day),
        busyIds: busy,
        mine: const [],
        now: _now,
      );
      final d1 = items.firstWhere((e) => e.doctor.id == 'd1');
      expect(d1.freeCount, 9);
      expect(d1.nextFree, _today(10, 30));
      expect(items.firstWhere((e) => e.doctor.id == 'd2').nextFree, isNull);
    });

    test('danh sách chuyên khoa không trùng, theo ABC', () {
      expect(specialtiesOf(_doctors), ['Da liễu', 'Nội tổng quát']);
    });
  });

  group('Kiểm tra trước khi đặt (checkBooking)', () {
    test('khung trống trong tương lai -> đặt được', () {
      expect(
        checkBooking(doctorId: 'd1', start: _today(14), busyIds: const {}, mine: const [], now: _now),
        isNull,
      );
    });

    test('khung đã qua / đã có người đặt / trùng lịch của chính mình -> báo đúng lỗi', () {
      expect(
        checkBooking(doctorId: 'd1', start: _today(9), busyIds: const {}, mine: const [], now: _now),
        AppStrings.errSlotPast,
      );
      expect(
        checkBooking(
          doctorId: 'd1',
          start: _today(14),
          busyIds: {BusySlot.idOf('d1', _today(14))},
          mine: const [],
          now: _now,
        ),
        AppStrings.errSlotTaken,
      );
      // Khách đã có lịch 14:00 với bác sĩ KHÁC -> không được đặt thêm cùng giờ.
      expect(
        checkBooking(
          doctorId: 'd1',
          start: _today(14),
          busyIds: const {},
          mine: [appt('m', _today(14), doctorId: 'd2', customerId: 'me')],
          now: _now,
        ),
        AppStrings.errOwnOverlap,
      );
    });

    test('lịch đã hủy của chính mình không chặn việc đặt lại', () {
      expect(
        checkBooking(
          doctorId: 'd1',
          start: _today(14),
          busyIds: const {},
          mine: [appt('m', _today(14), status: AppointmentStatus.cancelled, customerId: 'me')],
          now: _now,
        ),
        isNull,
      );
    });
  });

  group('Số liệu Trang chủ Customer (CustomerHomeSummary)', () {
    test('chỉ tính lịch còn hiệu lực chưa tới giờ, sắp tăng dần', () {
      final s = CustomerHomeSummary.from(
        [
          appt('late', _tomorrow(9), status: AppointmentStatus.confirmed),
          appt('past', _today(8), status: AppointmentStatus.confirmed),
          appt('soon', _today(14)),
          appt('canc', _today(15), status: AppointmentStatus.cancelled),
          appt('rej', _today(16), status: AppointmentStatus.rejected),
          appt('far', DateTime(2026, 11, 20, 9)),
        ],
        _now,
      );
      expect(s.upcoming.map((a) => a.id), ['soon', 'late', 'far']);
      expect(s.next!.id, 'soon');
      expect(s.others.map((a) => a.id), ['late', 'far']);
      expect(s.upcomingTotal, 3);
      expect(s.upcomingPending, 2);
      expect(s.upcomingConfirmed, 1);
      expect(s.upcomingTotal, s.upcomingPending + s.upcomingConfirmed);
    });

    test('không có lịch -> mọi số bằng 0, không có lịch gần nhất', () {
      final s = CustomerHomeSummary.from(const [], _now);
      expect(s.next, isNull);
      expect(s.others, isEmpty);
      expect(s.upcomingTotal, 0);
    });
  });

  group('Dữ liệu dùng chung', () {
    test('tên dịch vụ ghi vào lịch hẹn lấy từ chuyên khoa của bác sĩ', () {
      expect(_doctors[0].serviceName, 'Khám nội tổng quát');
      expect(const Doctor(id: 'x', name: 'BS. X', specialty: '').serviceName, 'Khám bệnh');
    });

    test('định dạng phí khám', () {
      expect(TextUtils.money(150000), '150.000 đ');
      expect(TextUtils.money(1250000), '1.250.000 đ');
      expect(TextUtils.money(900), '900 đ');
    });

    test('bác sĩ mẫu có đủ thông tin cho trang bác sĩ; lịch mẫu không giữ trùng khung', () {
      expect(DemoData.demoDoctors.every((d) => d.bio.isNotEmpty && d.fee > 0), isTrue);
      final busy = busySlotsOf(DemoData.build(_now).appointments);
      expect(_ids(busy).length, busy.length);
    });
  });
}
