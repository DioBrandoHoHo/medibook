import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/services/firestore_errors.dart';
import '../../../booking/domain/availability.dart';
import '../../../booking/domain/entities/busy_slot.dart';
import '../../../home/domain/demo_data.dart';
import '../../../notifications/data/models/notification_model.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/entities/appointment_status.dart';
import '../../domain/repositories/appointment_repository.dart';
import '../models/appointment_model.dart';

/// Lịch hẹn lưu trên Cloud Firestore, collection `appointments`.
class FirestoreAppointmentRepository implements AppointmentRepository {
  FirestoreAppointmentRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  static const busyCollection = 'busy_slots';

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(AppointmentModel.collection);

  CollectionReference<Map<String, dynamic>> get _busy => _db.collection(busyCollection);

  static List<Appointment> _parse(QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.docs
      .map((doc) => AppointmentModel.fromMap(doc.id, doc.data()))
      .whereType<Appointment>()
      .toList();

  @override
  Stream<List<Appointment>> watchAll() {
    return _col
        .orderBy('startAt')
        .snapshots()
        .map(_parse)
        .handleError((Object e) => throw mapFirestoreError(e));
  }

  @override
  Stream<List<Appointment>> watchMine(String customerId) {
    return _col
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map((snapshot) => _parse(snapshot)..sort((a, b) => a.startAt.compareTo(b.startAt)))
        .handleError((Object e) => throw mapFirestoreError(e));
  }

  @override
  Stream<List<BusySlot>> watchBusySlots(DateTime from) {
    return _busy
        .where('startAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) => _busyFrom(doc.data())).whereType<BusySlot>().toList(),
        )
        .handleError((Object e) => throw mapFirestoreError(e));
  }

  static BusySlot? _busyFrom(Map<String, dynamic> data) {
    final doctorId = data['doctorId'];
    final startAt = data['startAt'];
    if (doctorId is! String || startAt is! Timestamp) return null;
    return BusySlot(
      doctorId: doctorId,
      startAt: startAt.toDate(),
      appointmentId: data['appointmentId'] as String? ?? '',
      isDemo: data['isDemo'] == true,
    );
  }

  static Map<String, Object> _busyMap(BusySlot slot) => {
        'doctorId': slot.doctorId,
        'startAt': Timestamp.fromDate(slot.startAt),
        'appointmentId': slot.appointmentId,
        'isDemo': slot.isDemo,
      };

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
    final doc = _col.doc();
    final appointment = Appointment(
      id: doc.id,
      customerId: customerId,
      customerName: customerName,
      serviceName: serviceName,
      startAt: startAt,
      endAt: endAt,
      status: AppointmentStatus.pending,
      doctorId: doctorId,
      doctorName: doctorName,
    );
    final locks = busySlotsOf([appointment]);
    await _guard(
      () => _db.runTransaction((tx) async {
        for (final lock in locks) {
          final existing = await tx.get(_busy.doc(lock.id));
          if (existing.exists) throw const SlotTakenFailure();
        }
        tx.set(doc, {
          ...AppointmentModel.toMap(appointment),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        tx.set(_db.collection(NotificationModel.collection).doc(), {
          'title': 'Lịch đặt mới',
          'body': DemoData.newBookingBody(customerName, serviceName, startAt),
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
          'appointmentId': doc.id,
          'isDemo': false,
          'createdBy': customerId,
        });
        for (final lock in locks) {
          tx.set(_busy.doc(lock.id), _busyMap(lock));
        }
      }),
    );
  }

  @override
  Future<void> updateStatus(String id, AppointmentStatus status) => _guard(() async {
        final batch = _db.batch()
          ..update(_col.doc(id), {
            'status': status.name,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        if (status == AppointmentStatus.rejected || status == AppointmentStatus.cancelled) {
          final locks = await _busy.where('appointmentId', isEqualTo: id).get();
          for (final lock in locks.docs) {
            batch.delete(lock.reference);
          }
        }
        await batch.commit();
      });

  @override
  Future<void> cancelByCustomer(Appointment appointment) => _guard(() async {
        final batch = _db.batch()
          ..update(_col.doc(appointment.id), {
            'status': AppointmentStatus.cancelled.name,
            'updatedAt': FieldValue.serverTimestamp(),
          })
          ..set(_db.collection(NotificationModel.collection).doc(), {
            'title': AppStrings.notifCancelledTitle,
            'body': DemoData.cancelledBody(
              appointment.customerName,
              appointment.serviceName,
              appointment.startAt,
            ),
            'createdAt': FieldValue.serverTimestamp(),
            'isRead': false,
            'appointmentId': appointment.id,
            'isDemo': false,
            'createdBy': appointment.customerId,
          });
        final locks = await _busy.where('appointmentId', isEqualTo: appointment.id).get();
        for (final lock in locks.docs) {
          batch.delete(lock.reference);
        }
        await batch.commit();
      });

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      throw mapFirestoreError(e);
    }
  }
}
