import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/features/appointments/domain/entities/appointment_status.dart';
import 'package:medibook/features/booking/domain/entities/doctor.dart';
import 'package:medibook/features/home/domain/demo_data.dart';
import 'package:medibook/features/schedule/domain/entities/time_slot.dart';
import 'package:medibook/features/schedule/domain/schedule_builder.dart';
import 'package:medibook/features/schedule/domain/work_shift.dart';

import '../mocks/fake_clinic_repositories.dart';

/// "Bây giờ" = Thứ Bảy 14/11/2026 10:00.
final _now = DateTime(2026, 11, 14, 10);
final _today = DateTime(2026, 11, 14);
DateTime _at(int h, [int m = 0]) => DateTime(2026, 11, 14, h, m);

List<SlotState> _states(List<TimeSlot> slots) => slots.map((s) => s.state).toList();

void main() {
  group('Ca làm việc (lich_lam_viec.txt 2.1)', () {
    test('Sáng 07:30–11:30 và Chiều 13:30–17:30, mỗi buổi 8 khung 30 phút', () {
      final morning = WorkShift.morning.slotStartsOn(_today);
      final afternoon = WorkShift.afternoon.slotStartsOn(_today);
      expect(morning, hasLength(8));
      expect(afternoon, hasLength(8));
      expect(morning.first, _at(7, 30));
      expect(morning.last, _at(11)); // khung cuối 11:00–11:30
      expect(afternoon.first, _at(13, 30));
      expect(afternoon.last, _at(17));
      for (var i = 1; i < morning.length; i++) {
        expect(morning[i].difference(morning[i - 1]), const Duration(minutes: 30));
      }
    });

    test('mỗi khung dài đúng 30 phút và nối tiếp nhau', () {
      final slots = buildSlots(
        doctorId: 'd1',
        day: _today,
        shift: WorkShift.afternoon,
        appointments: const [],
        now: _now,
      );
      for (var i = 0; i < slots.length; i++) {
        expect(slots[i].end.difference(slots[i].start), const Duration(minutes: 30));
        if (i > 0) expect(slots[i].start, slots[i - 1].end);
      }
    });

    test('buổi mặc định: hôm nay sau giờ sáng -> Chiều; còn lại -> Sáng', () {
      expect(WorkShift.defaultFor(_today, _at(8)), WorkShift.morning);
      expect(WorkShift.defaultFor(_today, _at(11, 29)), WorkShift.morning);
      expect(WorkShift.defaultFor(_today, _at(11, 30)), WorkShift.afternoon);
      expect(WorkShift.defaultFor(_today, _at(20)), WorkShift.afternoon);
      // Xem ngày khác thì luôn mở Sáng.
      expect(WorkShift.defaultFor(DateTime(2026, 11, 15), _at(20)), WorkShift.morning);
    });
  });

  group('Trạng thái khung giờ (2.2)', () {
    List<TimeSlot> morning(List appointments, {DateTime? now}) => buildSlots(
          doctorId: 'd1',
          day: _today,
          shift: WorkShift.morning,
          appointments: [...appointments],
          now: now ?? _now,
        );

    test('không có lịch: khung đã kết thúc -> Đã qua, còn lại -> Trống', () {
      // 10:00: các khung tới 09:30–10:00 đã kết thúc; 10:00–10:30 đang diễn ra vẫn là Trống.
      expect(_states(morning(const [])), [
        SlotState.past, // 07:30
        SlotState.past, // 08:00
        SlotState.past, // 08:30
        SlotState.past, // 09:00
        SlotState.past, // 09:30
        SlotState.free, // 10:00
        SlotState.free, // 10:30
        SlotState.free, // 11:00
      ]);
    });

    test('Đã xác nhận -> Đã đặt; Chờ xác nhận -> Chờ; Hủy / Từ chối -> không chiếm khung', () {
      final slots = morning([
        appt('conf', _at(10), status: AppointmentStatus.confirmed, doctorId: 'd1'),
        appt('pend', _at(10, 30), doctorId: 'd1'),
        appt('canc', _at(11), status: AppointmentStatus.cancelled, doctorId: 'd1'),
        appt('rej', _at(11), status: AppointmentStatus.rejected, doctorId: 'd1'),
      ]);
      expect(_states(slots).sublist(5), [SlotState.booked, SlotState.pending, SlotState.free]);
      expect(slots[5].appointment!.id, 'conf');
      expect(slots[6].appointment!.id, 'pend');
      expect(slots[7].appointment, isNull);
    });

    test('khung đã qua nhưng có lịch vẫn giữ trạng thái của lịch', () {
      final slots = morning([
        appt('old', _at(8), status: AppointmentStatus.confirmed, doctorId: 'd1'),
      ]);
      expect(slots[1].state, SlotState.booked);
      expect(slots[0].state, SlotState.past);
    });

    test('lịch của bác sĩ khác, ngày khác hoặc không gắn bác sĩ không ảnh hưởng', () {
      final slots = morning([
        appt('other_doctor', _at(10), status: AppointmentStatus.confirmed, doctorId: 'd2'),
        appt('other_day', DateTime(2026, 11, 15, 10),
            status: AppointmentStatus.confirmed, doctorId: 'd1'),
        appt('no_doctor', _at(10, 30), status: AppointmentStatus.confirmed),
      ]);
      expect(slots.every((s) => s.appointment == null), isTrue);
    });

    test('lịch lệch lưới 30 phút chiếm mọi khung nó chạm vào', () {
      // 10:10–10:40 chạm khung 10:00 và 10:30.
      final slots = morning([
        appt('off_grid', _at(10, 10), status: AppointmentStatus.confirmed, doctorId: 'd1'),
      ]);
      expect(_states(slots).sublist(5), [SlotState.booked, SlotState.booked, SlotState.free]);
    });

    test('lịch kết thúc đúng lúc khung bắt đầu thì KHÔNG chiếm khung đó', () {
      final slots = morning([
        appt('edge', _at(10), status: AppointmentStatus.confirmed, doctorId: 'd1'),
      ]);
      expect(slots[5].state, SlotState.booked); // 10:00–10:30
      expect(slots[6].state, SlotState.free); // 10:30–11:00 không bị dính
      expect(slots[4].state, SlotState.past); // 09:30–10:00 không bị dính
    });

    test('lịch dài 60 phút chiếm 2 khung liên tiếp', () {
      final slots = morning([appt('long', _at(10), doctorId: 'd1', minutes: 60)]);
      expect(_states(slots).sublist(5), [SlotState.pending, SlotState.pending, SlotState.free]);
    });

    test('trùng lịch: ưu tiên hiện lịch Đã xác nhận và đánh dấu cảnh báo', () {
      final slots = morning([
        appt('pend', _at(10), doctorId: 'd1'),
        appt('conf', _at(10), status: AppointmentStatus.confirmed, doctorId: 'd1'),
      ]);
      expect(slots[5].state, SlotState.booked);
      expect(slots[5].appointment!.id, 'conf');
      expect(slots[5].hasConflict, isTrue);
      expect(slots[6].hasConflict, isFalse);
    });

    test('xem ngày mai: không khung nào Đã qua', () {
      final slots = buildSlots(
        doctorId: 'd1',
        day: DateTime(2026, 11, 15),
        shift: WorkShift.morning,
        appointments: const [],
        now: _now,
      );
      expect(slots.every((s) => s.state == SlotState.free), isTrue);
    });
  });

  group('Tổng hợp (mục 4)', () {
    const doctors = [
      Doctor(id: 'd1', name: 'BS. An', specialty: 'Nội'),
      Doctor(id: 'd2', name: 'BS. Bình', specialty: 'Da liễu'),
    ];

    test('số tổng hợp của ngày = cộng các lưới của mọi bác sĩ, cả hai buổi', () {
      final appointments = [
        appt('a', _at(10), status: AppointmentStatus.confirmed, doctorId: 'd1'),
        appt('b', _at(10, 30), doctorId: 'd1'),
        appt('c', _at(14), status: AppointmentStatus.confirmed, doctorId: 'd2'),
        appt('d', _at(15), status: AppointmentStatus.cancelled, doctorId: 'd2'),
      ];
      final summary =
          summarizeDay(doctors: doctors, day: _today, appointments: appointments, now: _now);

      // 2 bác sĩ × 16 khung = 32. Buổi sáng mỗi người có 5 khung đã qua.
      expect(summary.total, 32);
      expect(summary.booked, 2);
      expect(summary.pending, 1);
      expect(summary.past, 10);
      expect(summary.free, 32 - 2 - 1 - 10);

      // Khớp với từng lưới.
      var free = 0;
      for (final doctor in doctors) {
        for (final shift in WorkShift.values) {
          free += SlotSummary.of(buildSlots(
            doctorId: doctor.id,
            day: _today,
            shift: shift,
            appointments: appointments,
            now: _now,
          )).free;
        }
      }
      expect(free, summary.free);
    });

    test('đổi trạng thái lịch -> số tổng hợp đổi theo (không có biến đếm riêng)', () {
      final pending = appt('p', _at(10, 30), doctorId: 'd1');
      SlotSummary of(AppointmentStatus status) => summarizeDay(
            doctors: doctors,
            day: _today,
            appointments: [pending.copyWith(status: status)],
            now: _now,
          );

      expect(of(AppointmentStatus.pending).pending, 1);
      expect(of(AppointmentStatus.confirmed).booked, 1);
      expect(of(AppointmentStatus.confirmed).pending, 0);
      // Từ chối / hủy -> khung trở lại Trống.
      expect(of(AppointmentStatus.rejected).free, of(AppointmentStatus.pending).free + 1);
      expect(of(AppointmentStatus.cancelled).free, of(AppointmentStatus.pending).free + 1);
    });
  });

  group('Tìm kiếm + lọc chuyên khoa (filterScheduleDoctors)', () {
    const doctors = [
      Doctor(id: 'a', name: 'BS. Nguyễn Văn An', specialty: 'Nội tổng quát', room: 'Phòng 101'),
      Doctor(id: 'b', name: 'BS. Trần Thị Bình', specialty: 'Da liễu', room: 'Phòng 102'),
      Doctor(id: 'c', name: 'BS. Đặng Minh Tuấn', specialty: 'Nội tổng quát', room: 'Phòng 105'),
    ];
    List<String> ids(List<Doctor> list) => [for (final d in list) d.id];

    test('không điều kiện -> giữ nguyên danh sách và thứ tự', () {
      expect(ids(filterScheduleDoctors(doctors)), ['a', 'b', 'c']);
    });

    test('theo chuyên khoa; theo tên / khoa / phòng không dấu; kết hợp cả hai', () {
      expect(ids(filterScheduleDoctors(doctors, specialty: 'Nội tổng quát')), ['a', 'c']);
      expect(ids(filterScheduleDoctors(doctors, query: 'TUAN')), ['c']);
      expect(ids(filterScheduleDoctors(doctors, query: 'da lieu')), ['b']);
      expect(ids(filterScheduleDoctors(doctors, query: '105')), ['c']);
      expect(ids(filterScheduleDoctors(doctors, query: 'nguyen', specialty: 'Da liễu')), isEmpty);
      expect(ids(filterScheduleDoctors(doctors, query: '  ', specialty: 'Da liễu')), ['b']);
    });
  });

  group('Dữ liệu mẫu cho Lịch làm việc', () {
    test('có 5 bác sĩ mẫu; mọi lịch mẫu gắn một bác sĩ mẫu', () {
      final data = DemoData.build(_now);
      expect(data.doctors, hasLength(5));
      expect(data.doctors.every((d) => d.isDemo && d.id.startsWith('demo_d')), isTrue);
      final ids = data.doctors.map((d) => d.id).toSet();
      expect(data.appointments.every((a) => ids.contains(a.doctorId)), isTrue);
      expect(data.appointments.every((a) => a.doctorName != null), isTrue);
    });

    test('tạo vào bất kỳ lúc nào trong ngày: không bác sĩ nào bị trùng lịch còn hiệu lực', () {
      for (var hour = 0; hour < 24; hour++) {
        for (final minute in [10, 40]) {
          final seedTime = DateTime(2026, 11, 14, hour, minute);
          final active = DemoData.build(seedTime).appointments.where((a) => a.isActive).toList();
          for (var i = 0; i < active.length; i++) {
            for (var j = i + 1; j < active.length; j++) {
              final a = active[i], b = active[j];
              final clash = a.doctorId == b.doctorId &&
                  a.startAt.isBefore(b.endAt) &&
                  a.endAt.isAfter(b.startAt);
              expect(clash, isFalse, reason: '$seedTime: ${a.id} trùng ${b.id}');
            }
          }
        }
      }
    });

    test('tạo lúc tối vẫn có lịch nằm trong giờ làm việc của hôm nay', () {
      final seedTime = DateTime(2026, 11, 14, 21, 10);
      final data = DemoData.build(seedTime);
      final summary = summarizeDay(
        doctors: data.doctors,
        day: _today,
        appointments: data.appointments,
        now: seedTime,
      );
      expect(summary.booked + summary.pending, greaterThanOrEqualTo(5));
    });
  });
}
