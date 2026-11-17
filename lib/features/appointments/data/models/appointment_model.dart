import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/appointment.dart';
import '../../domain/entities/appointment_status.dart';

/// Chuyển đổi giữa document Firestore `appointments/{id}` và entity [Appointment].
abstract final class AppointmentModel {
  static const collection = 'appointments';

  /// Trả về `null` nếu document thiếu/sai kiểu trường bắt buộc
  /// (VD document nhập tay trên Firebase Console bị thiếu `startAt`) để app không crash.
  static Appointment? fromMap(String id, Map<String, dynamic> data) {
    final startAt = data['startAt'];
    final endAt = data['endAt'];
    final status = _statusFrom(data['status']);
    if (startAt is! Timestamp || status == null) return null;
    final start = startAt.toDate();
    return Appointment(
      id: id,
      customerId: data['customerId'] as String? ?? '',
      customerName: data['customerName'] as String? ?? 'Khách hàng',
      serviceName: data['serviceName'] as String? ?? 'Khám bệnh',
      startAt: start,
      endAt: endAt is Timestamp ? endAt.toDate() : start.add(const Duration(minutes: 30)),
      status: status,
      isDemo: data['isDemo'] == true,
      doctorId: _textOrNull(data['doctorId']),
      doctorName: _textOrNull(data['doctorName']),
    );
  }

  static Map<String, Object> toMap(Appointment a) => {
        'customerId': a.customerId,
        'customerName': a.customerName,
        'serviceName': a.serviceName,
        'startAt': Timestamp.fromDate(a.startAt),
        'endAt': Timestamp.fromDate(a.endAt),
        'status': a.status.name, // pending | confirmed | rejected | cancelled
        'isDemo': a.isDemo,
        // Chỉ ghi khi có -> lịch cũ / lịch chưa chọn bác sĩ giữ nguyên cấu trúc.
        if (a.doctorId != null) 'doctorId': a.doctorId!,
        if (a.doctorName != null) 'doctorName': a.doctorName!,
      };

  static String? _textOrNull(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  static AppointmentStatus? _statusFrom(Object? value) {
    for (final s in AppointmentStatus.values) {
      if (s.name == value) return s;
    }
    return null;
  }
}
