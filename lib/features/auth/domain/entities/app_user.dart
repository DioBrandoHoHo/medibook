import 'user_gender.dart';
import 'user_role.dart';

/// Hồ sơ tài khoản sau xác thực (KHÔNG chứa mật khẩu).
///
/// Đây là bản trong bộ nhớ của document `users/{uid}`. Mọi màn hình (Trang thông tin,
/// Cập nhật thông tin, lời chào ở Trang tổng quan...) đọc cùng một đối tượng này qua
/// `AuthController.currentUser`, nên thông tin lúc tạo tài khoản và ở Trang thông tin luôn là một.
class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.role,
    this.email = '',
    this.birthDate,
    this.gender,
    this.profileCompleted = false,
    this.profilePromptDismissed = false,
  });

  final String id; // = Firebase Auth uid
  final String fullName;
  final String phone; // đã chuẩn hoá dạng 0xxxxxxxxx – là tên đăng nhập, không sửa được
  final UserRole role;

  /// Email LIÊN HỆ (không phải tên đăng nhập). Rỗng = chưa cập nhật.
  final String email;

  /// Ngày sinh (chỉ ngày, không có giờ). `null` = chưa cập nhật.
  final DateTime? birthDate;

  /// `null` = chưa cập nhật.
  final UserGender? gender;

  /// true khi người dùng đã lưu màn Cập nhật thông tin.
  final bool profileCompleted;

  /// true khi người dùng đã bấm "Để sau" ở bước hỏi cập nhật hồ sơ.
  final bool profilePromptDismissed;

  /// Có cần hỏi "Bạn có muốn cập nhật thông tin cá nhân không?" hay không.
  bool get shouldAskProfileUpdate => !profileCompleted && !profilePromptDismissed;

  /// Còn trường tuỳ chọn nào chưa có dữ liệu không (để nhắc hoàn thiện hồ sơ).
  bool get hasMissingInfo => email.isEmpty || birthDate == null || gender == null;

  AppUser copyWith({String? fullName, bool? profileCompleted, bool? profilePromptDismissed}) =>
      AppUser(
        id: id,
        fullName: fullName ?? this.fullName,
        phone: phone,
        role: role,
        email: email,
        birthDate: birthDate,
        gender: gender,
        profileCompleted: profileCompleted ?? this.profileCompleted,
        profilePromptDismissed: profilePromptDismissed ?? this.profilePromptDismissed,
      );

  /// Bản sao sau khi lưu màn Cập nhật thông tin. Khác [copyWith]: các trường tuỳ chọn
  /// được GHI ĐÈ kể cả khi rỗng / null (người dùng xoá dữ liệu đã nhập).
  AppUser withProfile({
    required String fullName,
    required String email,
    required DateTime? birthDate,
    required UserGender? gender,
  }) =>
      AppUser(
        id: id,
        fullName: fullName,
        phone: phone,
        role: role,
        email: email,
        birthDate: birthDate,
        gender: gender,
        profileCompleted: true,
        profilePromptDismissed: profilePromptDismissed,
      );
}
