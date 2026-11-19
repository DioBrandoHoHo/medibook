import '../../../core/constants/app_strings.dart';
import 'entities/appointment.dart';
import 'entities/appointment_status.dart';

// Hàm thuần Dart cho tab Lịch hẹn của Customer.

/// Ba nhóm hiển thị.
enum CustomerAppointmentFilter {
  /// Còn hiệu lực và chưa tới giờ bắt đầu.
  upcoming,

  /// Còn hiệu lực nhưng đã tới / qua giờ bắt đầu.
  past,

  /// Đã hủy hoặc Đã từ chối.
  cancelled,
}

/// Nhóm của một lịch tại thời điểm [now].
CustomerAppointmentFilter groupOf(Appointment a, DateTime now) {
  if (!a.isActive) return CustomerAppointmentFilter.cancelled;
  return a.startAt.isAfter(now)
      ? CustomerAppointmentFilter.upcoming
      : CustomerAppointmentFilter.past;
}

/// Lịch thuộc nhóm [filter], đã sắp xếp.
List<Appointment> customerAppointments(
  List<Appointment> mine,
  CustomerAppointmentFilter filter,
  DateTime now,
) {
  final result = mine.where((a) => groupOf(a, now) == filter).toList();
  if (filter == CustomerAppointmentFilter.upcoming) {
    result.sort((a, b) => a.startAt.compareTo(b.startAt));
  } else {
    result.sort((a, b) => b.startAt.compareTo(a.startAt));
  }
  return result;
}

/// Lịch ĐÃ XÁC NHẬN chỉ hủy được khi còn ít nhất chừng này trước giờ khám.
const cancelDeadline = Duration(hours: 2);

/// Vì sao KHÔNG hủy được lịch này.
String? cancelBlockReason(Appointment a, DateTime now) {
  if (!a.isActive) return AppStrings.errAlreadyHandled;
  if (!a.startAt.isAfter(now)) return AppStrings.errCancelPast;
  if (a.status == AppointmentStatus.confirmed &&
      a.startAt.difference(now) < cancelDeadline) {
    return AppStrings.errCancelTooLate;
  }
  return null;
}

bool canCancel(Appointment a, DateTime now) => cancelBlockReason(a, now) == null;

/// Dòng giải thích trạng thái cho khách hàng (thẻ lịch hẹn + màn Chi tiết).
String customerStatusNote(Appointment a, DateTime now) => switch (a.status) {
      AppointmentStatus.pending => a.startAt.isAfter(now)
          ? AppStrings.notePendingCustomer
          : AppStrings.noteNeverConfirmed,
      AppointmentStatus.confirmed => a.startAt.isAfter(now)
          ? AppStrings.noteConfirmedCustomer
          : AppStrings.noteDoneCustomer,
      AppointmentStatus.rejected => AppStrings.noteRejectedCustomer,
      AppointmentStatus.cancelled => AppStrings.noteCancelledCustomer,
    };
