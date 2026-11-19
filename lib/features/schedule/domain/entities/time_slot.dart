import '../../../appointments/domain/entities/appointment.dart';

/// Trạng thái của một khung giờ.
enum SlotState {
  /// Không có lịch, chưa qua.
  free,

  /// Có lịch đang chờ xác nhận.
  pending,

  /// Có lịch đã xác nhận.
  booked,

  /// Không có lịch và đã kết thúc.
  past,
}

/// Một khung 30 phút của một bác sĩ trong một ngày.
class TimeSlot {
  const TimeSlot({
    required this.start,
    required this.end,
    required this.state,
    this.appointment,
    this.hasConflict = false,
  });

  final DateTime start;
  final DateTime end;
  final SlotState state;

  /// Lịch hẹn chiếm khung này.
  final Appointment? appointment;

  /// Có từ 2 lịch cùng chiếm khung.
  final bool hasConflict;

  bool get isOccupied => appointment != null;
}
