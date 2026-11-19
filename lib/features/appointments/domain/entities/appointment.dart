import 'appointment_status.dart';

/// Một lịch hẹn khám.
class Appointment {
  const Appointment({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.serviceName,
    required this.startAt,
    required this.endAt,
    required this.status,
    this.isDemo = false,
    this.doctorId,
    this.doctorName,
  });

  /// Mã lịch = id document Firestore.
  final String id;

  /// uid của Customer đặt lịch (dữ liệu mẫu dùng giá trị 'demo').
  final String customerId;

  /// Tên người đặt lịch / bệnh nhân (KHÔNG phải tên Staff).
  final String customerName;
  final String serviceName;
  final DateTime startAt;
  final DateTime endAt;
  final AppointmentStatus status;

  /// true = dữ liệu mẫu phục vụ demo, phân biệt với lịch thật.
  final bool isDemo;

  /// Id bác sĩ khám.
  final String? doctorId;

  /// Tên bác sĩ tại thời điểm đặt (để hiển thị ở Chi tiết lịch hẹn).
  final String? doctorName;

  /// Mã ngắn để hiển thị, VD "#K3F9QZ".
  String get shortCode {
    final tail = id.length > 8 ? id.substring(id.length - 6) : id;
    return '#${tail.toUpperCase()}';
  }

  bool get isPending => status == AppointmentStatus.pending;

  /// Lịch CHỜ XÁC NHẬN nhưng đã tới / qua giờ bắt đầu mà chưa được nhân viên xử lý.
  bool isOverdueAt(DateTime now) => isPending && !startAt.isAfter(now);

  /// Nhân viên còn thấy / xử lý lịch này không.
  bool isStaffVisibleAt(DateTime now) => !isOverdueAt(now);

  /// Lịch còn hiệu lực.
  bool get isActive => status == AppointmentStatus.pending || status == AppointmentStatus.confirmed;

  Appointment copyWith({AppointmentStatus? status}) => Appointment(
    id: id,
    customerId: customerId,
    customerName: customerName,
    serviceName: serviceName,
    startAt: startAt,
    endAt: endAt,
    status: status ?? this.status,
    isDemo: isDemo,
    doctorId: doctorId,
    doctorName: doctorName,
  );
}
