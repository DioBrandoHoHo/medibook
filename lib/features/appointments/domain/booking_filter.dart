import '../../../core/utils/app_date_utils.dart';
import '../../../core/utils/text_utils.dart';
import 'entities/appointment.dart';
import 'entities/appointment_status.dart';

/// Ba bộ lọc chính của màn Lịch đặt (lich_dat.txt 3.2).
enum BookingFilter { all, today, pending }

/// Lọc + sắp xếp danh sách lịch cho màn Lịch đặt. Hàm thuần Dart để unit test.
///
/// - [filter]: Tất cả / Hôm nay (mọi trạng thái) / Chờ xác nhận (mọi ngày).
/// - [statuses]: lọc nâng cao theo trạng thái; rỗng = không lọc thêm.
/// - [query]: tìm theo tên khách, dịch vụ, tên bác sĩ hoặc mã lịch (không phân biệt hoa thường / dấu).
///
/// Lịch chờ đã quá giờ (`isOverdueAt`) bị bỏ khỏi MỌI bộ lọc (quy tắc chốt 18/11/2026).
///
/// Kết quả luôn sắp theo thời điểm bắt đầu (kiểu DateTime, không so chuỗi) tăng dần.
List<Appointment> applyBookingFilter(
  List<Appointment> all,
  BookingFilter filter,
  DateTime now, {
  Set<AppointmentStatus> statuses = const {},
  String query = '',
}) {
  final needle = TextUtils.normalize(query);
  bool matchesFilter(Appointment a) => switch (filter) {
    BookingFilter.all => true,
    BookingFilter.today => AppDateUtils.isSameDay(a.startAt, now),
    BookingFilter.pending => a.isPending,
  };
  bool matchesQuery(Appointment a) =>
      needle.isEmpty ||
      TextUtils.normalize(a.customerName).contains(needle) ||
      TextUtils.normalize(a.serviceName).contains(needle) ||
      TextUtils.normalize(a.doctorName ?? '').contains(needle) ||
      a.id.toLowerCase().contains(needle) ||
      a.shortCode.toLowerCase().contains(needle);

  return all
      .where(
        (a) =>
            // Lịch chờ đã quá giờ đã hết hiệu lực phía nhân viên -> không hiện ở bộ lọc nào.
            a.isStaffVisibleAt(now) &&
            matchesFilter(a) &&
            (statuses.isEmpty || statuses.contains(a.status)) &&
            matchesQuery(a),
      )
      .toList()
    ..sort((a, b) => a.startAt.compareTo(b.startAt));
}

/// Các lịch của cùng một ngày (để hiện tiêu đề ngày trong danh sách).
class BookingDayGroup {
  const BookingDayGroup(this.day, this.items);

  /// 00:00 của ngày đó.
  final DateTime day;
  final List<Appointment> items;
}

/// Gom danh sách ĐÃ sắp xếp thành từng ngày, giữ nguyên thứ tự.
List<BookingDayGroup> groupBookingsByDay(List<Appointment> sorted) {
  final groups = <BookingDayGroup>[];
  for (final a in sorted) {
    if (groups.isEmpty || !AppDateUtils.isSameDay(groups.last.day, a.startAt)) {
      groups.add(BookingDayGroup(AppDateUtils.dayOnly(a.startAt), [a]));
    } else {
      groups.last.items.add(a);
    }
  }
  return groups;
}

/// Đếm số lịch theo từng trạng thái trong [items] (VD danh sách sau bộ lọc chính) –
/// để bảng "Lọc theo trạng thái" hiện số lịch bên cạnh mỗi lựa chọn.
Map<AppointmentStatus, int> countByStatus(Iterable<Appointment> items) {
  final counts = {for (final s in AppointmentStatus.values) s: 0};
  for (final a in items) {
    counts[a.status] = counts[a.status]! + 1;
  }
  return counts;
}
