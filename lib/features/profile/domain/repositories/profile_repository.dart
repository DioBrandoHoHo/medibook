import '../../../auth/domain/entities/user_gender.dart';

/// Hợp đồng cập nhật hồ sơ người dùng (document `users/{uid}` – cùng document tạo lúc đăng ký).
/// SĐT và vai trò KHÔNG được cập nhật qua đây (Security Rules cũng chặn).
abstract interface class ProfileRepository {
  /// Ghi họ tên + các trường tuỳ chọn và đánh dấu `profileCompleted = true`.
  /// Trường tuỳ chọn rỗng / null nghĩa là xoá dữ liệu đã nhập trước đó.
  Future<void> updateProfile({
    required String uid,
    required String fullName,
    String email = '',
    DateTime? birthDate,
    UserGender? gender,
  });

  /// Ghi ảnh đại diện (chuỗi base64 của ảnh JPEG đã xử lý). `''` = xoá ảnh.
  Future<void> updateAvatar({required String uid, required String avatar});

  /// Ghi nhận người dùng đã bấm "Để sau": `profilePromptDismissed = true`.
  Future<void> dismissProfilePrompt({required String uid});
}
