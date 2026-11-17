import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/services/firestore_errors.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';
import '../models/notification_model.dart';

/// Thông báo của Staff lưu trên Cloud Firestore, collection `notifications`.
class FirestoreNotificationRepository implements NotificationRepository {
  FirestoreNotificationRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Số thông báo mới nhất hiển thị trong popup.
  static const latestLimit = 50;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(NotificationModel.collection);

  @override
  Stream<List<AppNotification>> watchLatest() {
    return _col
        .orderBy('createdAt', descending: true)
        .limit(latestLimit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => NotificationModel.fromMap(doc.id, doc.data()))
              .toList(),
        )
        .handleError((Object e) => throw mapFirestoreError(e));
  }

  @override
  Future<void> markRead(List<String> ids) {
    final batch = _db.batch();
    for (final id in ids) {
      batch.update(_col.doc(id), {'isRead': true});
    }
    return _guard(batch.commit);
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      throw mapFirestoreError(e);
    }
  }
}
