import '../../../core/utils/text_utils.dart';
import '../../appointments/domain/entities/appointment.dart';
import '../../appointments/domain/entities/appointment_status.dart';
import '../../booking/domain/entities/doctor.dart';
import 'entities/time_slot.dart';
import 'work_shift.dart';

/// Tính các khung giờ của MỘT bác sĩ trong MỘT buổi của ngày [day].
List<TimeSlot> buildSlots({
  required String doctorId,
  required DateTime day,
  required WorkShift shift,
  required List<Appointment> appointments,
  required DateTime now,
}) {
  final mine = appointments.where((a) => a.doctorId == doctorId && a.isActive).toList()
    ..sort((a, b) => a.startAt.compareTo(b.startAt));

  return [
    for (final start in shift.slotStartsOn(day)) _slotAt(start, mine, now),
  ];
}

TimeSlot _slotAt(DateTime start, List<Appointment> mine, DateTime now) {
  final end = start.add(const Duration(minutes: WorkShift.slotMinutes));
  final overlapping =
      mine.where((a) => a.startAt.isBefore(end) && a.endAt.isAfter(start)).toList();

  if (overlapping.isEmpty) {
    return TimeSlot(
      start: start,
      end: end,
      state: end.isAfter(now) ? SlotState.free : SlotState.past,
    );
  }
  final shown = overlapping.firstWhere(
    (a) => a.status == AppointmentStatus.confirmed,
    orElse: () => overlapping.first,
  );
  return TimeSlot(
    start: start,
    end: end,
    state: shown.status == AppointmentStatus.confirmed ? SlotState.booked : SlotState.pending,
    appointment: shown,
    hasConflict: overlapping.length > 1,
  );
}

/// Số khung theo trạng thái.
class SlotSummary {
  const SlotSummary({
    required this.free,
    required this.pending,
    required this.booked,
    required this.past,
  });

  factory SlotSummary.of(Iterable<TimeSlot> slots) {
    var free = 0, pending = 0, booked = 0, past = 0;
    for (final slot in slots) {
      switch (slot.state) {
        case SlotState.free:
          free++;
        case SlotState.pending:
          pending++;
        case SlotState.booked:
          booked++;
        case SlotState.past:
          past++;
      }
    }
    return SlotSummary(free: free, pending: pending, booked: booked, past: past);
  }

  final int free;
  final int pending;
  final int booked;
  final int past;

  int get total => free + pending + booked + past;
}

/// Toàn bộ khung (cả hai buổi) của một bác sĩ trong ngày [day].
List<TimeSlot> buildDaySlots({
  required String doctorId,
  required DateTime day,
  required List<Appointment> appointments,
  required DateTime now,
}) =>
    [
      for (final shift in WorkShift.values)
        ...buildSlots(
          doctorId: doctorId,
          day: day,
          shift: shift,
          appointments: appointments,
          now: now,
        ),
    ];

/// Lọc bác sĩ ở tab Lịch làm việc.
List<Doctor> filterScheduleDoctors(
  List<Doctor> doctors, {
  String query = '',
  String? specialty,
}) {
  final q = TextUtils.normalize(query);
  return [
    for (final d in doctors)
      if ((specialty == null || d.specialty == specialty) &&
          (q.isEmpty ||
              TextUtils.normalize(d.name).contains(q) ||
              TextUtils.normalize(d.specialty).contains(q) ||
              TextUtils.normalize(d.room).contains(q)))
        d,
  ];
}

/// Tổng hợp của MỌI bác sĩ trong ngày [day] (cả hai buổi).
SlotSummary summarizeDay({
  required List<Doctor> doctors,
  required DateTime day,
  required List<Appointment> appointments,
  required DateTime now,
}) =>
    SlotSummary.of([
      for (final doctor in doctors)
        ...buildDaySlots(doctorId: doctor.id, day: day, appointments: appointments, now: now),
    ]);
