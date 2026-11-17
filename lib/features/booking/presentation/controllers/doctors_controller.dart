import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../appointments/presentation/controllers/appointments_controller.dart' show LoadStatus;
import '../../domain/entities/doctor.dart';
import '../../domain/repositories/doctor_repository.dart';

/// Giữ danh sách bác sĩ: Staff dùng ở tab Lịch làm việc, Customer dùng ở Trang chủ + Đặt lịch.
/// Cùng cách hoạt động với AppointmentsController: lắng nghe stream, không tự sửa dữ liệu.
class DoctorsController extends ChangeNotifier {
  DoctorsController(this._repository);

  final DoctorRepository _repository;

  StreamSubscription<List<Doctor>>? _subscription;
  List<Doctor> _items = const [];
  LoadStatus _status = LoadStatus.loading;
  String? _errorMessage;

  List<Doctor> get items => _items;

  Doctor? byId(String id) {
    for (final d in _items) {
      if (d.id == id) return d;
    }
    return null;
  }
  LoadStatus get status => _status;
  String? get errorMessage => _errorMessage;

  void start() {
    _subscription?.cancel();
    _subscription = _repository.watchAll().listen(
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

  void retry() {
    _status = LoadStatus.loading;
    _errorMessage = null;
    notifyListeners();
    start();
  }

  /// Ngừng lắng nghe và xoá dữ liệu trong bộ nhớ (khi Staff đăng xuất).
  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _items = const [];
    _status = LoadStatus.loading;
    _errorMessage = null;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
