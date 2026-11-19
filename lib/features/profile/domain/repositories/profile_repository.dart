import '../../../auth/domain/entities/user_gender.dart';

/// Hợp đồng cập nhật hồ sơ người dùng.
abstract interface class ProfileRepository {
  /// Ghi họ tên + các trường tuỳ chọn và đánh dấu `profileCompleted = true`.
  Future<void> updateProfile({
    required String uid,
    required String fullName,
    String email = '',
    DateTime? birthDate,
    UserGender? gender,
  });

  /// Ghi ảnh đại diện.
  Future<void> updateAvatar({required String uid, required String avatar});

  /// Ghi nhận người dùng đã bấm "Để sau".
  Future<void> dismissProfilePrompt({required String uid});
}
