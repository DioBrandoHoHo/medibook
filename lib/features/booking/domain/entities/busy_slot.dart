/// Một khung 30 phút ĐÃ CÓ NGƯỜI ĐẶT của một bác sĩ (document `busy_slots/{id}`).
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

  /// Id document.
  String get id => idOf(doctorId, startAt);

  static String idOf(String doctorId, DateTime startAt) =>
      '${doctorId}_${startAt.millisecondsSinceEpoch}';
}
