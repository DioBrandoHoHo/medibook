import '../../../booking/domain/entities/busy_slot.dart';
import '../entities/appointment.dart';
import '../entities/appointment_status.dart';

/// Nguồn dữ liệu lịch hẹn DUY NHẤT của ứng dụng.
/// Mọi số liệu trên Trang chủ Staff đều được tính từ danh sách do [watchAll] trả về.
abstract interface class AppointmentRepository {
  /// Theo dõi toàn bộ lịch hẹn (dành cho Staff), sắp xếp theo giờ bắt đầu tăng dần.
  /// Mỗi khi dữ liệu thay đổi, stream phát ra danh sách mới.
  Stream<List<Appointment>> watchAll();

  /// Theo dõi lịch hẹn của MỘT khách hàng (dành cho Customer), tăng dần theo giờ bắt đầu.
  Stream<List<Appointment>> watchMine(String customerId);

  /// Theo dõi các khung giờ đã có người đặt từ thời điểm [from] trở đi (mọi bác sĩ).
  /// Không chứa thông tin khách hàng -> Customer dùng để biết bác sĩ còn trống khung nào.
  Stream<List<BusySlot>> watchBusySlots(DateTime from);

  /// Customer đặt lịch mới: trạng thái ban đầu luôn là Pending, đồng thời tạo một thông báo
  /// cho Staff và giữ khung giờ của bác sĩ – cả ba cùng thành công hoặc cùng thất bại.
  /// Ném [SlotTakenFailure] nếu khung giờ vừa có người khác đặt.
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
  /// Từ chối / hủy thì đồng thời trả lại khung giờ của bác sĩ.
  Future<void> updateStatus(String id, AppointmentStatus status);

  /// Customer hủy lịch của chính mình: đổi trạng thái thành Cancelled, trả lại khung giờ của
  /// bác sĩ và tạo thông báo "Lịch hẹn đã hủy" cho Staff – cả ba trong cùng một lần ghi.
  Future<void> cancelByCustomer(Appointment appointment);
}
