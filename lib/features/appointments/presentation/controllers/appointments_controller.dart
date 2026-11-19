import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/app_failure.dart';
import '../../domain/customer_appointments.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/entities/appointment_status.dart';
import '../../domain/repositories/appointment_repository.dart';

enum LoadStatus { loading, ready, error }

/// Giữ MỘT danh sách lịch hẹn duy nhất cho khu vực đang đăng nhập.
class AppointmentsController extends ChangeNotifier {
  AppointmentsController(this._repository, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final AppointmentRepository _repository;
  final DateTime Function() _clock;

  StreamSubscription<List<Appointment>>? _subscription;
  List<Appointment> _items = const [];
  LoadStatus _status = LoadStatus.loading;
  String? _errorMessage;

  List<Appointment> get items => _items;
  LoadStatus get status => _status;
  String? get errorMessage => _errorMessage;

  /// Thời điểm hiện tại.
  DateTime get now => _clock();

  Appointment? byId(String id) {
    for (final a in _items) {
      if (a.id == id) return a;
    }
    return null;
  }

  String? _customerId;

  /// Bắt đầu lắng nghe dữ liệu (gọi khi người dùng vào khu vực của mình).
  void start({String? customerId}) {
    _customerId = customerId;
    _subscription?.cancel();
    final stream =
        customerId == null ? _repository.watchAll() : _repository.watchMine(customerId);
    _subscription = stream.listen(
      (items) {
        _items = items;
        _status = LoadStatus.ready;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (Object e) {
        _status = LoadStatus.error;
        _errorMessage = e is AppFailure ? e.message : AppStrings.errUnknown;
        notifyListeners();
      },
    );
  }

  /// Thử tải lại sau khi gặp lỗi.
  void retry() {
    _status = LoadStatus.loading;
    _errorMessage = null;
    notifyListeners();
    start(customerId: _customerId);
  }

  /// Ngừng lắng nghe và xoá dữ liệu trong bộ nhớ (khi đăng xuất).
  void stop() {
    _customerId = null;
    _subscription?.cancel();
    _subscription = null;
    _items = const [];
    _status = LoadStatus.loading;
    _errorMessage = null;
  }

  /// Tính lại theo thời điểm hiện tại (quay lại Trang chủ, mở lại app, sang ngày mới).
  void refreshClock() => notifyListeners();

  /// Staff xác nhận lịch.
  Future<String?> confirm(String id) => _changeStatus(id, AppointmentStatus.confirmed);

  /// Staff từ chối lịch.
  Future<String?> reject(String id) => _changeStatus(id, AppointmentStatus.rejected);

  /// Customer đặt lịch với bác sĩ.
  Future<String?> book({
    required String customerId,
    required String customerName,
    required String serviceName,
    required String doctorId,
    required String doctorName,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    try {
      await _repository.create(
        customerId: customerId,
        customerName: customerName,
        serviceName: serviceName,
        startAt: startAt,
        endAt: endAt,
        doctorId: doctorId,
        doctorName: doctorName,
      );
      return null;
    } on AppFailure catch (e) {
      return e.message;
    } catch (_) {
      return AppStrings.errUnknown;
    }
  }

  /// Customer hủy lịch của mình.
  Future<String?> cancel(String id) async {
    final current = byId(id);
    if (current == null) return AppStrings.appointmentNotFound;
    final blocked = cancelBlockReason(current, now);
    if (blocked != null) return blocked;
    try {
      await _repository.cancelByCustomer(current);
      return null;
    } on AppFailure catch (e) {
      return e.message;
    } catch (_) {
      return AppStrings.errUnknown;
    }
  }

  Future<String?> _changeStatus(String id, AppointmentStatus status) async {
    final current = byId(id);
    if (current != null && !current.isPending) return AppStrings.errAlreadyHandled;
    if (current != null && current.isOverdueAt(now)) return AppStrings.errExpired;
    try {
      await _repository.updateStatus(id, status);
      return null;
    } on AppFailure catch (e) {
      return e.message;
    } catch (_) {
      return AppStrings.errUnknown;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
