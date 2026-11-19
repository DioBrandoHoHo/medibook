/// Tiện ích ngày giờ.
abstract final class AppDateUtils {
  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// 00:00 của ngày chứa [d].
  static DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static const _weekdays = [
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ nhật',
  ];

  static const _weekdaysShort = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  /// VD: T2, CN (dùng trên dải chọn ngày)
  static String weekdayShort(DateTime d) => _weekdaysShort[d.weekday - 1];

  /// VD: Chủ nhật, 15/11/2026
  static String weekdayDate(DateTime d) => '${_weekdays[d.weekday - 1]}, ${date(d)}';

  /// Tiêu đề ngày trong danh sách.
  static String dayLabel(DateTime d, DateTime now) {
    final days = (dayOnly(d).difference(dayOnly(now)).inHours / 24).round();
    return switch (days) {
      0 => 'Hôm nay, ${date(d)}',
      1 => 'Ngày mai, ${date(d)}',
      -1 => 'Hôm qua, ${date(d)}',
      _ => weekdayDate(d),
    };
  }

  /// Nhãn ngày gọn cho thẻ.
  static String shortDayLabel(DateTime d, DateTime now) {
    return switch (daysBetween(now, d)) {
      0 => 'Hôm nay',
      1 => 'Ngày mai',
      -1 => 'Hôm qua',
      _ =>
        d.year == now.year
            ? '${weekdayShort(d)}, ${_two(d.day)}/${_two(d.month)}'
            : '${weekdayShort(d)}, ${date(d)}',
    };
  }

  /// Thời gian còn lại tới [start] khi lịch thuộc HÔM NAY và chưa bắt đầu.
  static String? startsIn(DateTime start, DateTime now) {
    if (!isSameDay(start, now) || !start.isAfter(now)) return null;
    final minutes = (start.difference(now).inSeconds / 60).ceil();
    if (minutes < 60) return 'còn $minutes phút';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? 'còn $h giờ' : 'còn $h giờ $m phút';
  }

  /// Số ngày lịch từ [from] tới [to].
  static int daysBetween(DateTime from, DateTime to) =>
      (dayOnly(to).difference(dayOnly(from)).inHours / 24).round();

  /// [d] cộng thêm [days] ngày lịch.
  static DateTime addDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

  /// Ngày 1 của tháng chứa [d].
  static DateTime monthStart(DateTime d) => DateTime(d.year, d.month);

  /// Ngày 1 của tháng cách tháng chứa [d] đúng [months] tháng.
  static DateTime addMonths(DateTime d, int months) => DateTime(d.year, d.month + months);

  /// Số ngày của tháng chứa [d] (28–31).
  static int daysInMonth(DateTime d) => DateTime(d.year, d.month + 1, 0).day;

  static bool isSameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

  /// Các ô của bảng lịch tháng chứa [month], tuần bắt đầu từ Thứ Hai.
  static List<DateTime?> monthCells(DateTime month) {
    final first = monthStart(month);
    final cells = <DateTime?>[
      for (var i = 1; i < first.weekday; i++) null,
      for (var day = 1; day <= daysInMonth(first); day++) DateTime(first.year, first.month, day),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return cells;
  }

  /// Tên viết tắt 7 thứ, bắt đầu từ Thứ Hai (tiêu đề cột của bảng lịch tháng).
  static List<String> get weekdaysShort => _weekdaysShort;

  /// VD: Tháng 11, 2026
  static String monthLabel(DateTime d) => 'Tháng ${d.month}, ${d.year}';

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// VD: 08:30
  static String time(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

  /// VD: 14/11/2026
  static String date(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';

  /// Ngày dạng lưu trữ `yyyy-MM-dd`.
  static String isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

  /// Đọc `yyyy-MM-dd`.
  static DateTime? parseIsoDate(Object? value) {
    if (value is! String) return null;
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (m == null) return null;
    return _realDate(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }

  /// Đọc ngày người dùng gõ dạng `dd/mm/yyyy`.
  static DateTime? parseDisplayDate(String input) {
    final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(input.trim());
    if (m == null) return null;
    return _realDate(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
  }

  /// `null` nếu ngày không tồn tại (VD 31/02).
  static DateTime? _realDate(int year, int month, int day) {
    final d = DateTime(year, month, day);
    return d.year == year && d.month == month && d.day == day ? d : null;
  }

  /// VD: 08:30 – 09:00
  static String timeRange(DateTime start, DateTime end) => '${time(start)} – ${time(end)}';

  /// VD: "Vừa xong", "5 phút trước", "2 giờ trước", hoặc ngày giờ đầy đủ nếu quá 1 ngày.
  static String timeAgo(DateTime t, DateTime now) {
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return '${time(t)} ${date(t)}';
  }
}
