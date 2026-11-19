/// Một bác sĩ.
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

  /// Chuyên khoa.
  final String specialty;

  /// Phòng khám.
  final String room;

  /// true = dữ liệu mẫu.
  final bool isDemo;

  /// Số năm kinh nghiệm.
  final int experienceYears;

  /// Giới thiệu ngắn.
  final String bio;

  /// Phí khám.
  final int fee;

  /// Tên dịch vụ ghi vào lịch hẹn.
  String get serviceName {
    final s = specialty.trim();
    if (s.isEmpty) return 'Khám bệnh';
    return 'Khám ${s[0].toLowerCase()}${s.substring(1)}';
  }
}
