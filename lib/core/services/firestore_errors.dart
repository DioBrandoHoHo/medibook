import 'package:cloud_firestore/cloud_firestore.dart';

import '../errors/app_failure.dart';

/// Đổi lỗi Firestore thành [AppFailure] có thông báo dễ hiểu cho người dùng.
AppFailure mapFirestoreError(Object error) {
  if (error is AppFailure) return error;
  if (error is FirebaseException) {
    return switch (error.code) {
      'unavailable' || 'deadline-exceeded' => const NetworkFailure(),
      'permission-denied' => const PermissionFailure(),
      _ => const UnknownFailure(),
    };
  }
  return const UnknownFailure();
}
