/// Một khung 30 phút ĐÃ CÓ NGƯỜI ĐẶT của một bác sĩ (document `busy_slots/{id}`).
///
/// Customer không được đọc lịch hẹn của người khác (quyền riêng tư), nên để biết bác sĩ
/// còn trống khung nào, app đọc collection này: nó chỉ chứa bác sĩ + giờ, KHÔNG chứa
/// tên hay thông tin của khách. Bản ghi được tạo / xoá trong CÙNG một lần ghi với lịch hẹn
/// nên không lệch với danh sách lịch hẹn mà Staff nhìn thấy.
class BusySlot {
  const BusySlot({
    required this.doctorId,
    required this.startAt,
    this.appointmentId = '',
    this.isDemo = false,
  });

  final String doctorId;

  /// Giờ bắt đầu của khung (đúng lưới 30 phút của ca làm việc).
  final DateTime startAt;

  /// Lịch hẹn đang giữ khung này.
  final String appointmentId;
  final bool isDemo;

  /// Id document = khoá duy nhất của (bác sĩ, khung giờ). Vì id là duy nhất nên hai người
  /// không thể cùng giữ một khung: người đến sau sẽ bị từ chối ở phía máy chủ.
  String get id => idOf(doctorId, startAt);

  static String idOf(String doctorId, DateTime startAt) =>
      '${doctorId}_${startAt.millisecondsSinceEpoch}';
}
