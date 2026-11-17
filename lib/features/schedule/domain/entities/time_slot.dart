import '../../../appointments/domain/entities/appointment.dart';

/// Trạng thái của một khung giờ (lich_lam_viec.txt 2.2). Luôn được TÍNH, không lưu.
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

  /// Lịch hẹn chiếm khung này (null khi Trống / Đã qua). Bấm khung sẽ mở chi tiết lịch này.
  final Appointment? appointment;

  /// true khi có từ 2 lịch còn hiệu lực cùng chiếm khung (trùng lịch).
  final bool hasConflict;

  bool get isOccupied => appointment != null;
}
