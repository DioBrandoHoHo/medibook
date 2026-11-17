import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/domain/entities/user_gender.dart';
import '../../domain/repositories/profile_repository.dart';

class FirebaseProfileRepository implements ProfileRepository {
  FirebaseProfileRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  @override
  Future<void> updateProfile({
    required String uid,
    required String fullName,
    String email = '',
    DateTime? birthDate,
    UserGender? gender,
  }) =>
      _update(
        uid,
        UserModel.profileUpdateMap(
          fullName: fullName.trim(),
          email: email.trim(),
          birthDate: birthDate,
          gender: gender,
        ),
      );

  @override
  Future<void> dismissProfilePrompt({required String uid}) =>
      _update(uid, {'profilePromptDismissed': true});

  Future<void> _update(String uid, Map<String, Object?> fields) async {
    try {
      await _db.collection(UserModel.collection).doc(uid).update({
        ...fields,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw switch (e.code) {
        'unavailable' || 'deadline-exceeded' => const NetworkFailure(),
        'permission-denied' => const PermissionFailure(),
        _ => const UnknownFailure(),
      };
    }
  }
}
