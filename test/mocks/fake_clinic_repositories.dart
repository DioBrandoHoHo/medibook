import 'dart:async';

import 'package:medibook/core/constants/app_strings.dart';
import 'package:medibook/core/errors/app_failure.dart';
import 'package:medibook/features/appointments/domain/entities/appointment.dart';
import 'package:medibook/features/appointments/domain/entities/appointment_status.dart';
import 'package:medibook/features/appointments/domain/repositories/appointment_repository.dart';
import 'package:medibook/features/booking/domain/availability.dart';
import 'package:medibook/features/booking/domain/entities/busy_slot.dart';
import 'package:medibook/features/booking/domain/entities/doctor.dart';
import 'package:medibook/features/booking/domain/repositories/doctor_repository.dart';
import 'package:medibook/features/home/domain/demo_data.dart';
import 'package:medibook/features/notifications/domain/entities/app_notification.dart';
import 'package:medibook/features/notifications/domain/repositories/notification_repository.dart';

/// Phát lại danh sách hiện tại cho mọi người đang lắng nghe – mô phỏng `snapshots()` của Firestore.
class _LiveList<T> {
  final List<StreamController<List<T>>> _listeners = [];

  Stream<List<T>> watch(List<T> Function() current, AppFailure? Function() error) {
    late final StreamController<List<T>> controller;
    controller = StreamController<List<T>>(
      onListen: () {
        final e = error();
        if (e != null) {
          controller.addError(e);
        } else {
          controller.add(current());
        }
        _listeners.add(controller);
      },
      onCancel: () => _listeners.remove(controller),
    );
    return controller.stream;
  }

  void emit(List<T> items) {
    for (final c in _listeners.toList()) {
      c.add(items);
    }
  }
}

/// Lịch hẹn lưu trong bộ nhớ – CHỈ dùng cho test.
class FakeAppointmentRepository implements AppointmentRepository {
  FakeAppointmentRepository({List<Appointment> initial = const [], this.notifications})
      : _items = [...initial];

  final List<Appointment> _items;
  final FakeNotificationRepository? notifications;
  final _live = _LiveList<Appointment>();
  int _seq = 0;

  /// Ép lỗi khi bắt đầu lắng nghe (VD mất mạng). Đặt lại `null` để "có mạng trở lại".
  AppFailure? watchError;

  /// Ép lỗi cho lần đổi trạng thái kế tiếp.
  AppFailure? nextUpdateError;

  /// Ép lỗi cho lần đặt lịch kế tiếp (VD mất mạng).
  AppFailure? nextCreateError;

  List<Appointment> get items => _sorted();

  List<Appointment> _sorted() =>
      [..._items]..sort((a, b) => a.startAt.compareTo(b.startAt));

  void _emit() => _live.emit(_sorted());

  @override
  Stream<List<Appointment>> watchAll() => _live.watch(_sorted, () => watchError);

  @override
  Stream<List<Appointment>> watchMine(String customerId) => watchAll()
      .map((items) => items.where((a) => a.customerId == customerId).toList());

  /// Khung bận luôn được SUY RA từ danh sách lịch hẹn (như cách Firestore ghi hai nơi
  /// trong cùng một lần ghi), nên không bao giờ lệch.
  @override
  Stream<List<BusySlot>> watchBusySlots(DateTime from) => watchAll().map(busySlotsOf);

  /// Thay một lịch bằng bản mới cùng id (VD dữ liệu bị sửa trên Console – đổi giờ).
  Future<void> replace(Appointment appointment) async {
    final i = _items.indexWhere((a) => a.id == appointment.id);
    _items[i] = appointment;
    _emit();
  }

  /// Thêm một lịch từ "bên ngoài" (VD một khách hàng khác vừa đặt).
  void addExternal(Appointment appointment) {
    _items.add(appointment);
    _emit();
  }

  @override
  Future<void> create({
    required String customerId,
    required String customerName,
    required String serviceName,
    required DateTime startAt,
    required DateTime endAt,
    String? doctorId,
    String? doctorName,
  }) async {
    final e = nextCreateError;
    if (e != null) {
      nextCreateError = null;
      throw e;
    }
    // Khung đã có người giữ -> từ chối, giống giao dịch trên Firestore.
    if (doctorId != null) {
      final taken = {for (final slot in busySlotsOf(_items)) slot.id};
      for (final start in occupiedSlotStarts(startAt, endAt)) {
        if (taken.contains(BusySlot.idOf(doctorId, start))) throw const SlotTakenFailure();
      }
    }
    final id = 'a${_seq++}';
    _items.add(
      Appointment(
        id: id,
        customerId: customerId,
        customerName: customerName,
        serviceName: serviceName,
        startAt: startAt,
        endAt: endAt,
        status: AppointmentStatus.pending,
        doctorId: doctorId,
        doctorName: doctorName,
      ),
    );
    notifications?.add(
      AppNotification(
        id: 'n_$id',
        title: 'Lịch đặt mới',
        body: DemoData.newBookingBody(customerName, serviceName, startAt),
        createdAt: startAt,
        appointmentId: id,
      ),
    );
    _emit();
  }

  @override
  Future<void> updateStatus(String id, AppointmentStatus status) async {
    final e = nextUpdateError;
    if (e != null) {
      nextUpdateError = null;
      throw e;
    }
    final i = _items.indexWhere((a) => a.id == id);
    if (i < 0) throw const UnknownFailure();
    _items[i] = _items[i].copyWith(status: status);
    _emit();
  }

  @override
  Future<void> cancelByCustomer(Appointment appointment) async {
    await updateStatus(appointment.id, AppointmentStatus.cancelled);
    notifications?.add(
      AppNotification(
        id: 'nc_${appointment.id}',
        title: AppStrings.notifCancelledTitle,
        body: DemoData.cancelledBody(
          appointment.customerName,
          appointment.serviceName,
          appointment.startAt,
        ),
        createdAt: appointment.startAt,
        appointmentId: appointment.id,
      ),
    );
  }
}

/// Thông báo lưu trong bộ nhớ – CHỈ dùng cho test.
class FakeNotificationRepository implements NotificationRepository {
  FakeNotificationRepository({List<AppNotification> initial = const []})
      : _items = [...initial];

  final List<AppNotification> _items;
  final _live = _LiveList<AppNotification>();
  AppFailure? watchError;

  List<AppNotification> get items => _sorted();

  List<AppNotification> _sorted() =>
      [..._items]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  void add(AppNotification n) {
    _items.add(n);
    _live.emit(_sorted());
  }

  @override
  Stream<List<AppNotification>> watchLatest() => _live.watch(_sorted, () => watchError);

  @override
  Future<void> markRead(List<String> ids) async {
    for (var i = 0; i < _items.length; i++) {
      if (ids.contains(_items[i].id)) _items[i] = _items[i].copyWith(isRead: true);
    }
    _live.emit(_sorted());
  }
}

/// Bác sĩ lưu trong bộ nhớ – CHỈ dùng cho test.
class FakeDoctorRepository implements DoctorRepository {
  FakeDoctorRepository({List<Doctor> initial = const []}) : _items = [...initial];

  final List<Doctor> _items;
  final _live = _LiveList<Doctor>();

  /// Ép lỗi khi bắt đầu lắng nghe. Đặt lại `null` để "có mạng trở lại".
  AppFailure? watchError;

  List<Doctor> get items => _sorted();

  List<Doctor> _sorted() => [..._items]..sort((a, b) => a.name.compareTo(b.name));

  @override
  Stream<List<Doctor>> watchAll() => _live.watch(_sorted, () => watchError);
}

/// Tạo nhanh một lịch hẹn cho test.
Appointment appt(
  String id,
  DateTime startAt, {
  AppointmentStatus status = AppointmentStatus.pending,
  String name = 'Khách',
  String service = 'Khám tổng quát',
  String? doctorId,
  int minutes = 30,
  String? customerId,
}) =>
    Appointment(
      id: id,
      customerId: customerId ?? 'c_$id',
      customerName: name,
      serviceName: service,
      startAt: startAt,
      endAt: startAt.add(Duration(minutes: minutes)),
      status: status,
      doctorId: doctorId,
      doctorName: doctorId == null ? null : 'BS. $doctorId',
    );
