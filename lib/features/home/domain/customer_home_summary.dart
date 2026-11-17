import '../../appointments/domain/entities/appointment.dart';
import '../../appointments/domain/entities/appointment_status.dart';

/// Số liệu Trang chủ + tab Cá nhân của Customer, TÍNH từ danh sách lịch hẹn của chính
/// khách hàng (trang_chu.txt phần 2). Không có con số nào được lưu riêng.
class CustomerHomeSummary {
  const CustomerHomeSummary({
    required this.upcoming,
    required this.upcomingPending,
    required this.upcomingConfirmed,
  });

  /// Mọi lịch còn hiệu lực chưa tới giờ, tăng dần theo thời gian.
  final List<Appointment> upcoming;

  /// Trong số sắp tới: đang chờ nhân viên xác nhận.
  final int upcomingPending;

  /// Trong số sắp tới: đã được xác nhận.
  final int upcomingConfirmed;

  int get upcomingTotal => upcoming.length;

  /// Lịch gần nhất (thẻ nổi bật ở Trang chủ).
  Appointment? get next => upcoming.isEmpty ? null : upcoming.first;

  /// Tối đa [otherLimit] lịch tiếp theo sau lịch gần nhất.
  List<Appointment> get others => upcoming.skip(1).take(otherLimit).toList();

  static const otherLimit = 2;

  factory CustomerHomeSummary.from(List<Appointment> mine, DateTime now) {
    final upcoming = mine.where((a) => a.isActive && a.startAt.isAfter(now)).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    return CustomerHomeSummary(
      upcoming: upcoming,
      upcomingPending: upcoming.where((a) => a.status == AppointmentStatus.pending).length,
      upcomingConfirmed: upcoming.where((a) => a.status == AppointmentStatus.confirmed).length,
    );
  }
}
