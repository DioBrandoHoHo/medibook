import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../appointments/domain/repositories/appointment_repository.dart';
import '../../../appointments/presentation/controllers/appointments_controller.dart' show LoadStatus;
import '../../domain/entities/busy_slot.dart';

/// Giữ danh sách khung giờ ĐÃ CÓ NGƯỜI ĐẶT của mọi bác sĩ, cho khu vực Customer.
class BusySlotsController extends ChangeNotifier {
  BusySlotsController(this._repository);

  final AppointmentRepository _repository;

  StreamSubscription<List<BusySlot>>? _subscription;
  Set<String> _ids = const {};
  LoadStatus _status = LoadStatus.loading;
  String? _errorMessage;
  DateTime? _from;

  /// Id (`BusySlot.id`) của các khung đang bận.
  Set<String> get ids => _ids;
  LoadStatus get status => _status;
  String? get errorMessage => _errorMessage;

  /// Lắng nghe các khung bận từ [from] (thường là 00:00 hôm nay) trở đi.
  void start(DateTime from) {
    _from = from;
    _subscription?.cancel();
    _subscription = _repository.watchBusySlots(from).listen(
      (items) {
        _ids = {for (final slot in items) slot.id};
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
    final from = _from;
    if (from == null) return;
    _status = LoadStatus.loading;
    _errorMessage = null;
    notifyListeners();
    start(from);
  }

  /// Ngừng lắng nghe và xoá dữ liệu trong bộ nhớ (khi Customer đăng xuất).
  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _ids = const {};
    _status = LoadStatus.loading;
    _errorMessage = null;
    _from = null;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
