import '../../../booking/domain/entities/busy_slot.dart';
import '../entities/appointment.dart';
import '../entities/appointment_status.dart';

/// Nguồn dữ liệu lịch hẹn DUY NHẤT của ứng dụng.
abstract interface class AppointmentRepository {
  /// Theo dõi toàn bộ lịch hẹn (dành cho Staff), sắp xếp theo giờ bắt đầu tăng dần.
  Stream<List<Appointment>> watchAll();

  /// Theo dõi lịch hẹn của MỘT khách hàng (dành cho Customer), tăng dần theo giờ bắt đầu.
  Stream<List<Appointment>> watchMine(String customerId);

  /// Theo dõi các khung giờ đã có người đặt từ thời điểm [from] trở đi (mọi bác sĩ).
  Stream<List<BusySlot>> watchBusySlots(DateTime from);

  /// Customer đặt lịch mới.
  Future<void> create({
    required String customerId,
    required String customerName,
    required String serviceName,
    required DateTime startAt,
    required DateTime endAt,
    String? doctorId,
    String? doctorName,
  });

  /// Đổi trạng thái lịch (Staff xác nhận / từ chối, Customer hủy).
  Future<void> updateStatus(String id, AppointmentStatus status);

  /// Customer hủy lịch của chính mình.
  Future<void> cancelByCustomer(Appointment appointment);
}
