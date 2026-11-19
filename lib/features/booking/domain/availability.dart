import '../../../core/constants/app_strings.dart';
import '../../../core/utils/app_date_utils.dart';
import '../../../core/utils/text_utils.dart';
import '../../appointments/domain/entities/appointment.dart';
import '../../schedule/domain/work_shift.dart';
import 'booking_window.dart';
import 'entities/busy_slot.dart';
import 'entities/doctor.dart';

// Các hàm thuần Dart cho phần Đặt lịch của Customer.

const _slot = Duration(minutes: WorkShift.slotMinutes);

/// Các khung (giờ bắt đầu, đúng lưới ca làm việc) mà một lịch hẹn chiếm.
List<DateTime> occupiedSlotStarts(DateTime startAt, DateTime endAt) {
  final result = <DateTime>[];
  for (var day = AppDateUtils.dayOnly(startAt);
      day.isBefore(endAt);
      day = DateTime(day.year, day.month, day.day + 1)) {
    for (final shift in WorkShift.values) {
      for (final s in shift.slotStartsOn(day)) {
        if (startAt.isBefore(s.add(_slot)) && endAt.isAfter(s)) result.add(s);
      }
    }
  }
  return result;
}

/// Các khung bận sinh ra từ danh sách lịch hẹn.
List<BusySlot> busySlotsOf(Iterable<Appointment> appointments) => [
      for (final a in appointments)
        if (a.isActive && a.doctorId != null)
          for (final s in occupiedSlotStarts(a.startAt, a.endAt))
            BusySlot(doctorId: a.doctorId!, startAt: s, appointmentId: a.id, isDemo: a.isDemo),
    ];

/// Trạng thái một khung giờ dưới góc nhìn của Customer.
enum BookSlotState {
  /// Còn trống, đặt được.
  free,

  /// Đã có người khác đặt (chờ xác nhận hoặc đã xác nhận).
  taken,

  /// Chính khách hàng này đang có lịch ở khung này với bác sĩ này.
  mine,

  /// Đã tới giờ / đã qua.
  past,
}

class BookSlot {
  const BookSlot({required this.start, required this.state});

  final DateTime start;
  final BookSlotState state;

  DateTime get end => start.add(_slot);
  bool get isFree => state == BookSlotState.free;
}

/// Trạng thái của MỘT khung của bác sĩ [doctorId].
BookSlotState slotStateAt({
  required String doctorId,
  required DateTime start,
  required Set<String> busyIds,
  required List<Appointment> mine,
  required DateTime now,
}) {
  final end = start.add(_slot);
  final isMine = mine.any(
    (a) => a.isActive && a.doctorId == doctorId && a.startAt.isBefore(end) && a.endAt.isAfter(start),
  );
  if (isMine) return BookSlotState.mine;
  if (busyIds.contains(BusySlot.idOf(doctorId, start))) return BookSlotState.taken;
  if (!start.isAfter(now)) return BookSlotState.past;
  return BookSlotState.free;
}

/// Các khung của một bác sĩ trong MỘT buổi của ngày [day].
List<BookSlot> buildBookSlots({
  required String doctorId,
  required DateTime day,
  required WorkShift shift,
  required Set<String> busyIds,
  required List<Appointment> mine,
  required DateTime now,
}) =>
    [
      for (final start in shift.slotStartsOn(day))
        BookSlot(
          start: start,
          state: slotStateAt(
            doctorId: doctorId,
            start: start,
            busyIds: busyIds,
            mine: mine,
            now: now,
          ),
        ),
    ];

/// Các khung CÒN TRỐNG của bác sĩ trong cả ngày [day] (cả hai buổi), tăng dần theo giờ.
List<DateTime> freeSlotStarts({
  required String doctorId,
  required DateTime day,
  required Set<String> busyIds,
  required List<Appointment> mine,
  required DateTime now,
}) =>
    [
      for (final shift in WorkShift.values)
        for (final slot in buildBookSlots(
          doctorId: doctorId,
          day: day,
          shift: shift,
          busyIds: busyIds,
          mine: mine,
          now: now,
        ))
          if (slot.isFree) slot.start,
    ];

/// Khung giờ mong muốn [slotMinutes] còn chọn được vào ngày [day] không (chưa tới giờ).
bool wantedSlotStillValid(DateTime day, int? slotMinutes, DateTime now) =>
    slotMinutes == null || slotStartOn(day, slotMinutes).isAfter(now);

/// Ngày [day] còn ít nhất một khung chưa tới giờ.
bool dayHasFutureSlot(DateTime day, DateTime now) => WorkShift.values.any(
      (shift) => shift.slotStartsOn(day).any((s) => s.isAfter(now)),
    );

/// Phút trong ngày của mọi khung trong ca làm việc.
List<int> allSlotMinutes() {
  final day = DateTime(2000);
  return [
    for (final shift in WorkShift.values)
      for (final s in shift.slotStartsOn(day)) s.hour * 60 + s.minute,
  ];
}

DateTime slotStartOn(DateTime day, int minutes) =>
    DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);

/// Điều kiện lọc danh sách bác sĩ ở tab Đặt lịch.
class DoctorFilter {
  const DoctorFilter({
    required this.day,
    this.slotMinutes,
    this.query = '',
    this.specialty,
    this.onlyFree = false,
  });

  /// Ngày khám mong muốn (00:00).
  final DateTime day;

  /// Giờ khám mong muốn (phút trong ngày).
  final int? slotMinutes;

  /// Từ khoá tìm kiếm.
  final String query;

  /// Chuyên khoa.
  final String? specialty;

  /// Ẩn bác sĩ không còn khung trống nào trong ngày.
  final bool onlyFree;
}

/// Một bác sĩ kèm tình trạng trống trong ngày đang lọc.
class DoctorAvailability {
  const DoctorAvailability({required this.doctor, required this.freeStarts});

  final Doctor doctor;

  /// Các khung còn trống trong ngày, tăng dần.
  final List<DateTime> freeStarts;

  int get freeCount => freeStarts.length;
  DateTime? get nextFree => freeStarts.isEmpty ? null : freeStarts.first;
}

/// Lọc + sắp xếp bác sĩ theo [filter].
List<DoctorAvailability> applyDoctorFilter({
  required List<Doctor> doctors,
  required DoctorFilter filter,
  required Set<String> busyIds,
  required List<Appointment> mine,
  required DateTime now,
}) {
  final query = TextUtils.normalize(filter.query);
  final wanted =
      filter.slotMinutes == null ? null : slotStartOn(filter.day, filter.slotMinutes!);

  final result = <DoctorAvailability>[];
  for (final doctor in doctors) {
    if (filter.specialty != null && doctor.specialty != filter.specialty) continue;
    if (query.isNotEmpty &&
        !TextUtils.normalize(doctor.name).contains(query) &&
        !TextUtils.normalize(doctor.specialty).contains(query)) {
      continue;
    }
    final free = freeSlotStarts(
      doctorId: doctor.id,
      day: filter.day,
      busyIds: busyIds,
      mine: mine,
      now: now,
    );
    if (wanted != null && !free.contains(wanted)) continue;
    if (filter.onlyFree && free.isEmpty) continue;
    result.add(DoctorAvailability(doctor: doctor, freeStarts: free));
  }
  result.sort((a, b) {
    final byFree = (a.freeCount == 0 ? 1 : 0) - (b.freeCount == 0 ? 1 : 0);
    return byFree != 0 ? byFree : a.doctor.name.compareTo(b.doctor.name);
  });
  return result;
}

/// Danh sách chuyên khoa (không trùng, theo ABC) lấy từ chính danh sách bác sĩ.
List<String> specialtiesOf(List<Doctor> doctors) =>
    ({for (final d in doctors) if (d.specialty.isNotEmpty) d.specialty}.toList()..sort());

/// Kiểm tra trước khi đặt.
String? checkBooking({
  required String doctorId,
  required DateTime start,
  required Set<String> busyIds,
  required List<Appointment> mine,
  required DateTime now,
}) {
  final end = start.add(_slot);
  if (!start.isAfter(now)) return AppStrings.errSlotPast;
  if (!BookingWindow.contains(start, now)) return AppStrings.errDayTooFar;
  if (mine.any((a) => a.isActive && a.startAt.isBefore(end) && a.endAt.isAfter(start))) {
    return AppStrings.errOwnOverlap;
  }
  if (busyIds.contains(BusySlot.idOf(doctorId, start))) return AppStrings.errSlotTaken;
  return null;
}
