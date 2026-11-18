import '../../../../core/utils/app_date_utils.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_gender.dart';
import '../../domain/entities/user_role.dart';

/// Ánh xạ giữa document Firestore `users/{uid}` và entity [AppUser].
///
/// Cấu trúc document:
/// ```
/// users/{uid}
///   fullName:               string
///   phone:                  string   (0xxxxxxxxx – đã chuẩn hoá)
///   role:                   'customer' | 'staff'
///   email:                  string   (email liên hệ; thiếu hoặc '' = chưa cập nhật)
///   birthDate:              string   ('yyyy-MM-dd'; thiếu hoặc null = chưa cập nhật)
///   gender:                 'male' | 'female' | 'other' (thiếu hoặc null = chưa cập nhật)
///   profileCompleted:       bool     (đã lưu màn Cập nhật thông tin)
///   profilePromptDismissed: bool     (đã bấm "Để sau")
///   avatar:                 string   (ảnh đại diện JPEG 256x256 base64; thiếu hoặc '' = chưa có)
///   createdAt:              timestamp
///   updatedAt:              timestamp
/// ```
/// Document cũ chưa có các trường mới được hiểu là "chưa cập nhật".
abstract final class UserModel {
  static const collection = 'users';

  static AppUser fromMap(String id, Map<String, dynamic> map) => AppUser(
    id: id,
    fullName: _string(map['fullName']),
    phone: _string(map['phone']),
    role: UserRole.fromString(map['role'] is String ? map['role'] as String : null),
    email: _string(map['email']).trim(),
    birthDate: AppDateUtils.parseIsoDate(map['birthDate']),
    gender: UserGender.fromString(map['gender'] is String ? map['gender'] as String : null),
    profileCompleted: map['profileCompleted'] == true,
    profilePromptDismissed: map['profilePromptDismissed'] == true,
    avatar: _avatar(map['avatar']),
  );

  /// Dữ liệu khi tạo tài khoản Customer mới (timestamp do caller thêm).
  static Map<String, dynamic> newCustomerMap({required String fullName, required String phone}) => {
    'fullName': fullName,
    'phone': phone,
    'role': UserRole.customer.name,
    'profileCompleted': false,
    'profilePromptDismissed': false,
  };

  /// Các trường ghi khi lưu màn Cập nhật thông tin (không có phone / role).
  static Map<String, Object?> profileUpdateMap({
    required String fullName,
    required String email,
    required DateTime? birthDate,
    required UserGender? gender,
  }) => {
    'fullName': fullName,
    'email': email,
    'birthDate': birthDate == null ? null : AppDateUtils.isoDate(birthDate),
    'gender': gender?.name,
    'profileCompleted': true,
  };

  /// Giới hạn độ dài chuỗi ảnh (khớp Security Rules). Dữ liệu lạ / quá lớn -> coi như chưa có ảnh.
  static const maxAvatarLength = 200000;

  static String _avatar(Object? value) =>
      value is String && value.length <= maxAvatarLength ? value : '';

  // Document nhập tay trên Console có thể sai kiểu -> không để app crash.
  static String _string(Object? value) => value is String ? value : '';
}
