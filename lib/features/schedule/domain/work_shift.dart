/// Buổi làm việc.
enum WorkShift {
  /// Sáng 07:30.
  morning(startHour: 7, startMinute: 30, endHour: 11, endMinute: 30),

  /// Chiều 13:30.
  afternoon(startHour: 13, startMinute: 30, endHour: 17, endMinute: 30);

  const WorkShift({
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });

  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  /// Độ dài một ca khám.
  static const slotMinutes = 30;

  DateTime startOn(DateTime day) => DateTime(day.year, day.month, day.day, startHour, startMinute);

  DateTime endOn(DateTime day) => DateTime(day.year, day.month, day.day, endHour, endMinute);

  /// Giờ bắt đầu của từng khung 30 phút trong buổi này vào ngày [day].
  List<DateTime> slotStartsOn(DateTime day) {
    final end = endOn(day);
    final starts = <DateTime>[];
    for (var t = startOn(day); t.isBefore(end); t = t.add(const Duration(minutes: slotMinutes))) {
      starts.add(t);
    }
    return starts;
  }

  /// Buổi nên mở sẵn khi xem ngày [day] tại thời điểm [now].
  static WorkShift defaultFor(DateTime day, DateTime now) {
    final isToday = day.year == now.year && day.month == now.month && day.day == now.day;
    return isToday && !now.isBefore(morning.endOn(day)) ? afternoon : morning;
  }
}
