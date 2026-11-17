/// Một bác sĩ (document `doctors/{id}`). Dùng chung cho tab Lịch làm việc của Staff
/// và phần Đặt lịch của Customer – cả hai đọc cùng một danh sách.
class Doctor {
  const Doctor({
    required this.id,
    required this.name,
    required this.specialty,
    this.room = '',
    this.isDemo = false,
    this.experienceYears = 0,
    this.bio = '',
    this.fee = 0,
  });

  final String id;
  final String name;

  /// Chuyên khoa, VD "Nội tổng quát".
  final String specialty;

  /// Phòng khám, VD "Phòng 101". Rỗng = chưa có.
  final String room;

  /// true = dữ liệu mẫu.
  final bool isDemo;

  /// Số năm kinh nghiệm. 0 = chưa có thông tin.
  final int experienceYears;

  /// Giới thiệu ngắn. Rỗng = chưa có.
  final String bio;

  /// Phí khám (VND). 0 = chưa có thông tin.
  final int fee;

  /// Tên dịch vụ ghi vào lịch hẹn khi đặt bác sĩ này, VD "Khám nội tổng quát".
  /// Staff thấy đúng chuỗi này ở Lịch đặt / Chi tiết lịch hẹn.
  String get serviceName {
    final s = specialty.trim();
    if (s.isEmpty) return 'Khám bệnh';
    return 'Khám ${s[0].toLowerCase()}${s.substring(1)}';
  }
}
