import '../constants/app_strings.dart';
import 'app_date_utils.dart';
import 'phone_utils.dart';

/// Trạng thái từng điều kiện mật khẩu (Mục 4.2) – UI dùng để hiển thị checklist.
class PasswordRules {
  const PasswordRules({
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasDigit,
    required this.hasSpecialChar,
  });

  factory PasswordRules.check(String password) => PasswordRules(
        hasMinLength: password.length >= minLength,
        hasUppercase: RegExp('[A-Z]').hasMatch(password),
        hasDigit: RegExp('[0-9]').hasMatch(password),
        // Ký tự đặc biệt: mọi ký tự không phải chữ cái, chữ số hay khoảng trắng.
        hasSpecialChar: RegExp(r'[^A-Za-z0-9\s]').hasMatch(password),
      );

  static const minLength = 8;

  final bool hasMinLength;
  final bool hasUppercase;
  final bool hasDigit;
  final bool hasSpecialChar;

  bool get allPassed => hasMinLength && hasUppercase && hasDigit && hasSpecialChar;
}

/// Các hàm validate trả về `null` khi hợp lệ, hoặc thông báo lỗi.
/// Dùng trực tiếp làm `validator` của TextFormField.
abstract final class Validators {
  static String? fullName(String? value) {
    if (value == null || value.trim().isEmpty) return AppStrings.errFullNameRequired;
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return AppStrings.errPhoneRequired;
    if (!PhoneUtils.isValid(value)) return AppStrings.errPhoneInvalid;
    return null;
  }

  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');
  static const emailMaxLength = 100;

  /// Email liên hệ: KHÔNG bắt buộc; nếu nhập thì phải đúng định dạng.
  static String? optionalEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (v.length > emailMaxLength || !_email.hasMatch(v)) return AppStrings.errEmailInvalid;
    return null;
  }

  /// Email khôi phục mật khẩu: BẮT BUỘC và phải đúng định dạng.
  static String? requiredEmail(String? value) {
    if (value == null || value.trim().isEmpty) return AppStrings.errEmailRequired;
    return optionalEmail(value);
  }

  /// Ngày sinh dd/mm/yyyy: KHÔNG bắt buộc; nếu nhập phải là ngày có thật,
  /// không ở tương lai và không quá 120 năm trước [now].
  static String? optionalBirthDate(String? value, DateTime now) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    final date = AppDateUtils.parseDisplayDate(v);
    if (date == null ||
        date.isAfter(AppDateUtils.dayOnly(now)) ||
        date.isBefore(DateTime(now.year - 120, now.month, now.day))) {
      return AppStrings.errBirthDateInvalid;
    }
    return null;
  }

  /// Mật khẩu mới ở màn Đổi mật khẩu: đủ 4 điều kiện và khác mật khẩu hiện tại.
  static String? changedPassword(String? value, String currentPassword) {
    final error = newPassword(value);
    if (error != null) return error;
    if (value == currentPassword) return AppStrings.errNewPasswordSame;
    return null;
  }

  /// Dùng cho màn Đăng nhập: chỉ bắt buộc nhập, không kiểm tra quy tắc.
  static String? loginPassword(String? value) {
    if (value == null || value.isEmpty) return AppStrings.errPasswordRequired;
    return null;
  }

  /// Dùng cho màn Đăng ký: phải đạt đủ 4 điều kiện.
  static String? newPassword(String? value) {
    if (value == null || value.isEmpty) return AppStrings.errPasswordRequired;
    if (!PasswordRules.check(value).allPassed) return AppStrings.errPasswordRules;
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) return AppStrings.errConfirmRequired;
    if (value != password) return AppStrings.errPasswordMismatch;
    return null;
  }
}
