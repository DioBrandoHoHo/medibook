import 'user_gender.dart';
import 'user_role.dart';

/// Hồ sơ tài khoản sau xác thực (KHÔNG chứa mật khẩu).
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
    this.avatar = '',
  });

  final String id;
  final String fullName;
  final String phone;
  final UserRole role;

  /// Email liên hệ.
  final String email;

  /// Ngày sinh.
  final DateTime? birthDate;

  /// Giới tính.
  final UserGender? gender;

  /// true khi người dùng đã lưu màn Cập nhật thông tin.
  final bool profileCompleted;

  /// true khi người dùng đã bấm "Để sau" ở bước hỏi cập nhật hồ sơ.
  final bool profilePromptDismissed;

  /// Ảnh đại diện.
  final String avatar;

  bool get hasAvatar => avatar.isNotEmpty;

  /// Có cần hỏi "Bạn có muốn cập nhật thông tin cá nhân không?" hay không.
  bool get shouldAskProfileUpdate => !profileCompleted && !profilePromptDismissed;

  /// Còn trường tuỳ chọn nào chưa có dữ liệu không (để nhắc hoàn thiện hồ sơ).
  bool get hasMissingInfo => email.isEmpty || birthDate == null || gender == null;

  AppUser copyWith({
    String? fullName,
    bool? profileCompleted,
    bool? profilePromptDismissed,
    String? avatar,
  }) => AppUser(
    id: id,
    fullName: fullName ?? this.fullName,
    phone: phone,
    role: role,
    email: email,
    birthDate: birthDate,
    gender: gender,
    profileCompleted: profileCompleted ?? this.profileCompleted,
    profilePromptDismissed: profilePromptDismissed ?? this.profilePromptDismissed,
    avatar: avatar ?? this.avatar,
  );

  /// Bản sao sau khi lưu màn Cập nhật thông tin.
  AppUser withProfile({
    required String fullName,
    required String email,
    required DateTime? birthDate,
    required UserGender? gender,
  }) => AppUser(
    id: id,
    fullName: fullName,
    phone: phone,
    role: role,
    email: email,
    birthDate: birthDate,
    gender: gender,
    profileCompleted: true,
    profilePromptDismissed: profilePromptDismissed,
    avatar: avatar,
  );
}
