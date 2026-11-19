import '../../../core/utils/app_date_utils.dart';

/// Khoảng ngày khách hàng được đặt lịch.
abstract final class BookingWindow {
  /// Số ngày được đặt trước, tính cả hôm nay.
  static const days = 180;

  /// Ngày đầu tiên chọn được = hôm nay (00:00).
  static DateTime firstDay(DateTime now) => AppDateUtils.dayOnly(now);

  /// Ngày cuối cùng chọn được (00:00).
  static DateTime lastDay(DateTime now) => AppDateUtils.addDays(now, days - 1);

  /// [day] có nằm trong khoảng được đặt không (không xét giờ).
  static bool contains(DateTime day, DateTime now) {
    final d = AppDateUtils.dayOnly(day);
    return !d.isBefore(firstDay(now)) && !d.isAfter(lastDay(now));
  }

  /// Đưa [day] về trong khoảng được đặt.
  static DateTime clamp(DateTime? day, DateTime now) {
    final first = firstDay(now);
    if (day == null) return first;
    final d = AppDateUtils.dayOnly(day);
    if (d.isBefore(first)) return first;
    final last = lastDay(now);
    return d.isAfter(last) ? last : d;
  }
}
