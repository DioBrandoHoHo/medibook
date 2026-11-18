import 'package:flutter/foundation.dart';

import '../../features/appointments/domain/booking_filter.dart';
import '../../features/appointments/domain/entities/appointment_status.dart';

/// Tab đang chọn của khu vực Staff + điều kiện lọc của màn Lịch đặt.
/// Nhờ đó Trang chủ có thể "chuyển sang tab Lịch đặt và lọc sẵn" khi bấm các nút tắt.
///
/// Controller này CHỈ giữ điều kiện lọc (trạng thái giao diện), không giữ lịch hẹn:
/// dữ liệu vẫn lấy từ AppointmentsController.
class StaffNavController extends ChangeNotifier {
  static const homeTab = 0;
  static const bookingsTab = 1;
  static const scheduleTab = 2;
  static const accountTab = 3;

  int _index = homeTab;
  BookingFilter _filter = BookingFilter.all;
  Set<AppointmentStatus> _statuses = const {};
  String _query = '';

  int get index => _index;

  /// Tăng mỗi lần nơi khác (Tổng quan) mở Lịch đặt với bộ lọc mới -> màn Lịch đặt cuộn về
  /// vị trí mở đầu (đầu danh sách, hoặc mốc hôm nay của "Tất cả") thay vì giữ chỗ cuộn cũ.
  int get openRequest => _openRequest;
  int _openRequest = 0;
  BookingFilter get filter => _filter;

  /// Lọc nâng cao theo trạng thái (rỗng = mọi trạng thái).
  Set<AppointmentStatus> get statuses => _statuses;

  /// Từ khoá tìm kiếm.
  String get query => _query;

  void selectTab(int index) {
    _index = index;
    notifyListeners();
  }

  /// Mở tab Lịch đặt với điều kiện lọc cho trước (xoá từ khoá tìm kiếm cũ).
  void openBookings(BookingFilter filter, {Set<AppointmentStatus> statuses = const {}}) {
    _filter = filter;
    _statuses = filter == BookingFilter.pending ? const {} : Set.unmodifiable(statuses);
    _query = '';
    _index = bookingsTab;
    _openRequest++;
    notifyListeners();
  }

  void setFilter(BookingFilter filter) {
    _filter = filter;
    // "Chờ xác nhận" đã cố định trạng thái Pending nên bỏ lọc trạng thái nâng cao.
    if (filter == BookingFilter.pending) _statuses = const {};
    notifyListeners();
  }

  void setStatuses(Set<AppointmentStatus> statuses) {
    _statuses = Set.unmodifiable(statuses);
    // Lọc trạng thái khác Pending không có nghĩa trong "Chờ xác nhận" -> về "Tất cả".
    if (statuses.isNotEmpty && _filter == BookingFilter.pending) _filter = BookingFilter.all;
    notifyListeners();
  }

  void setQuery(String query) {
    if (query == _query) return;
    _query = query;
    notifyListeners();
  }
}
