import 'package:flutter/foundation.dart';

import '../../features/appointments/domain/customer_appointments.dart';

/// Tab đang chọn của khu vực Customer + điều kiện lọc của tab Đặt lịch.
class CustomerNavController extends ChangeNotifier {
  static const homeTab = 0;
  static const bookingTab = 1;
  static const appointmentsTab = 2;
  static const profileTab = 3;

  int _index = homeTab;
  String _query = '';
  String? _specialty;
  DateTime? _day;
  int? _slotMinutes;
  bool _onlyFree = false;
  CustomerAppointmentFilter _appointmentFilter = CustomerAppointmentFilter.upcoming;

  int get index => _index;

  /// Nhóm đang xem ở tab Lịch hẹn.
  CustomerAppointmentFilter get appointmentFilter => _appointmentFilter;

  void setAppointmentFilter(CustomerAppointmentFilter value) {
    if (value == _appointmentFilter) return;
    _appointmentFilter = value;
    notifyListeners();
  }

  /// Mở tab Lịch hẹn ở nhóm Sắp tới (từ Trang chủ / tab Cá nhân).
  void openAppointments() {
    _appointmentFilter = CustomerAppointmentFilter.upcoming;
    _index = appointmentsTab;
    notifyListeners();
  }

  /// Từ khoá tìm bác sĩ.
  String get query => _query;

  /// Chuyên khoa đang lọc (`null` = tất cả).
  String? get specialty => _specialty;

  /// Ngày khám mong muốn (`null` = hôm nay).
  DateTime? get day => _day;

  /// Giờ khám mong muốn = phút trong ngày của khung (`null` = giờ bất kỳ).
  int? get slotMinutes => _slotMinutes;

  bool get onlyFree => _onlyFree;

  bool get hasFilters =>
      _query.isNotEmpty || _specialty != null || _slotMinutes != null || _onlyFree;

  void selectTab(int index) {
    if (index == _index) return;
    _index = index;
    notifyListeners();
  }

  /// Mở tab Đặt lịch.
  void openBooking({String? specialty}) {
    if (specialty != null) {
      _specialty = specialty;
      _query = '';
      _slotMinutes = null;
      _onlyFree = false;
    }
    _index = bookingTab;
    notifyListeners();
  }

  void setQuery(String value) {
    if (value == _query) return;
    _query = value;
    notifyListeners();
  }

  void setSpecialty(String? value) {
    _specialty = value;
    notifyListeners();
  }

  void setDay(DateTime value) {
    _day = DateTime(value.year, value.month, value.day);
    notifyListeners();
  }

  void setSlotMinutes(int? value) {
    _slotMinutes = value;
    notifyListeners();
  }

  void setOnlyFree(bool value) {
    _onlyFree = value;
    notifyListeners();
  }

  /// Xoá tìm kiếm và bộ lọc (giữ nguyên ngày đang chọn).
  void clearFilters() {
    _query = '';
    _specialty = null;
    _slotMinutes = null;
    _onlyFree = false;
    notifyListeners();
  }
}
