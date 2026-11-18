import '../../../core/utils/app_date_utils.dart';
import '../../appointments/domain/entities/appointment.dart';
import '../../appointments/domain/entities/appointment_status.dart';

/// Toàn bộ số liệu của Trang chủ Staff, được TÍNH từ một danh sách lịch hẹn duy nhất.
/// Không có con số nào được lưu riêng hay cộng trừ thủ công.
class StaffHomeSummary {
  const StaffHomeSummary({
    required this.todayTotal,
    required this.todayPending,
    required this.todayConfirmed,
    required this.todayCancelledOrRejected,
    required this.todayRemaining,
    required this.pendingAllDays,
    required this.pendingOverdue,
    required this.nextPending,
    required this.upcoming,
  });

  /// Tất cả lịch thuộc ngày hôm nay (mọi trạng thái).
  final int todayTotal;

  /// Lịch Pending thuộc ngày hôm nay (chỉ số "Chờ xác nhận").
  final int todayPending;

  /// Lịch Confirmed thuộc ngày hôm nay.
  final int todayConfirmed;

  /// Lịch Cancelled hoặc Rejected thuộc ngày hôm nay.
  final int todayCancelledOrRejected;

  /// Lịch hôm nay còn hiệu lực (Pending / Confirmed) và CHƯA tới giờ bắt đầu.
  final int todayRemaining;

  /// Lịch Pending ở MỌI ngày (thẻ "Có X lịch đặt mới cần xử lý").
  final int pendingAllDays;

  /// Trong [pendingAllDays]: số lịch đã qua giờ bắt đầu mà vẫn chưa được xử lý.
  final int pendingOverdue;

  /// Lịch Pending CHƯA tới giờ gần nhất (cần xử lý sớm nhất), `null` nếu không có.
  final Appointment? nextPending;

  /// Tối đa 3 lịch gần nhất chưa diễn ra, chưa bị hủy / từ chối.
  final List<Appointment> upcoming;

  static const upcomingLimit = 3;

  /// Chỉ số "Chờ xác nhận" hôm nay luôn nằm trong số "cần xử lý" (mọi ngày).
  int get pendingOtherDays => pendingAllDays - todayPending;

  factory StaffHomeSummary.from(List<Appointment> all, DateTime now) {
    final today = all.where((a) => AppDateUtils.isSameDay(a.startAt, now)).toList();
    int countToday(bool Function(Appointment) test) => today.where(test).length;

    final upcoming = all.where((a) => a.isActive && a.startAt.isAfter(now)).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));

    final pending = all.where((a) => a.isPending).toList();
    final futurePending = pending.where((a) => a.startAt.isAfter(now)).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));

    return StaffHomeSummary(
      todayTotal: today.length,
      todayPending: countToday((a) => a.status == AppointmentStatus.pending),
      todayConfirmed: countToday((a) => a.status == AppointmentStatus.confirmed),
      todayCancelledOrRejected: countToday((a) => !a.isActive),
      todayRemaining: countToday((a) => a.isActive && a.startAt.isAfter(now)),
      pendingAllDays: pending.length,
      pendingOverdue: pending.length - futurePending.length,
      nextPending: futurePending.isEmpty ? null : futurePending.first,
      upcoming: upcoming.take(upcomingLimit).toList(),
    );
  }
}
