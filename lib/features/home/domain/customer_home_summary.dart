import '../../appointments/domain/entities/appointment.dart';
import '../../appointments/domain/entities/appointment_status.dart';

/// Số liệu Trang chủ + tab Cá nhân của Customer.
class CustomerHomeSummary {
  const CustomerHomeSummary({
    required this.upcoming,
    required this.upcomingPending,
    required this.upcomingConfirmed,
  });

  /// Mọi lịch còn hiệu lực chưa tới giờ, tăng dần theo thời gian.
  final List<Appointment> upcoming;

  /// Số lịch sắp tới đang chờ xác nhận.
  final int upcomingPending;

  /// Số lịch sắp tới đã xác nhận.
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
