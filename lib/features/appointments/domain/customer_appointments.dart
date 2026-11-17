import '../../../core/constants/app_strings.dart';
import 'entities/appointment.dart';
import 'entities/appointment_status.dart';

// Hàm thuần Dart cho tab Lịch hẹn của Customer (lich_hen.txt).
// Không phụ thuộc Flutter / Firebase nên unit test được.

/// Ba nhóm hiển thị (lich_hen.txt 3.2). Không giao nhau, phủ hết mọi lịch của khách.
enum CustomerAppointmentFilter {
  /// Còn hiệu lực và chưa tới giờ bắt đầu.
  upcoming,

  /// Còn hiệu lực nhưng đã tới / qua giờ bắt đầu.
  past,

  /// Đã hủy hoặc Đã từ chối.
  cancelled,
}

/// Nhóm của một lịch tại thời điểm [now].
/// "Sắp tới" dùng ĐÚNG điều kiện của `CustomerHomeSummary` (còn hiệu lực + `startAt` sau `now`)
/// nên số lịch ở tab này luôn bằng chỉ số "Sắp tới" ở Trang chủ.
CustomerAppointmentFilter groupOf(Appointment a, DateTime now) {
  if (!a.isActive) return CustomerAppointmentFilter.cancelled;
  return a.startAt.isAfter(now)
      ? CustomerAppointmentFilter.upcoming
      : CustomerAppointmentFilter.past;
}

/// Lịch thuộc nhóm [filter], đã sắp xếp (lich_hen.txt 3.3):
/// Sắp tới tăng dần (gần nhất trên cùng); Đã qua / Đã hủy giảm dần (mới nhất trên cùng).
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

/// Lịch ĐÃ XÁC NHẬN chỉ hủy được khi còn ít nhất chừng này trước giờ khám
/// (người dùng chốt ngày 16/11/2026). Khai báo một chỗ để dễ đổi.
const cancelDeadline = Duration(hours: 2);

/// Vì sao KHÔNG hủy được lịch này (lich_hen.txt 3.4). `null` = hủy được.
/// - Chờ xác nhận: hủy được tới trước giờ bắt đầu.
/// - Đã xác nhận: hủy được khi còn ít nhất [cancelDeadline] trước giờ bắt đầu.
/// - Đã hủy / Đã từ chối / đã tới giờ: không hủy được.
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
