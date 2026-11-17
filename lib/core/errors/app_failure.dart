import '../constants/app_strings.dart';

/// Lỗi nghiệp vụ/hạ tầng chuẩn hoá để UI hiển thị thông báo dễ hiểu,
/// không lộ chi tiết kỹ thuật hay dữ liệu nhạy cảm.
sealed class AppFailure implements Exception {
  const AppFailure(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

class NetworkFailure extends AppFailure {
  const NetworkFailure([super.message = AppStrings.errNetwork]);
}

/// Trường nhập liệu mà lỗi xác thực gắn vào (để hiển thị ngay dưới trường đó).
enum AuthField { phone, password, general }

class AuthFailure extends AppFailure {
  const AuthFailure(super.message, {this.field = AuthField.general});
  final AuthField field;

  static const phoneAlreadyRegistered =
      AuthFailure(AppStrings.errPhoneExists, field: AuthField.phone);
  static const phoneNotRegistered =
      AuthFailure(AppStrings.errPhoneNotRegistered, field: AuthField.phone);
  static const wrongCredentials = AuthFailure(AppStrings.errWrongCredentials);
  static const tooManyRequests = AuthFailure(AppStrings.errTooManyRequests);
  static const currentPasswordWrong =
      AuthFailure(AppStrings.errCurrentPasswordWrong, field: AuthField.password);
  static const sessionExpired = AuthFailure(AppStrings.errSessionExpired);
  static const noRecoveryEmail = AuthFailure(AppStrings.errNoRecoveryEmail, field: AuthField.phone);
  static const recoveryNotVerified =
      AuthFailure(AppStrings.errRecoveryNotVerified, field: AuthField.phone);
  static const emailInUse = AuthFailure(AppStrings.errEmailInUse);
  static const emailInvalid = AuthFailure(AppStrings.errEmailInvalid);
}

class PermissionFailure extends AppFailure {
  const PermissionFailure([super.message = AppStrings.errPermission]);
}

/// Khung giờ vừa bị người khác đặt mất (phát hiện lúc ghi dữ liệu).
class SlotTakenFailure extends AppFailure {
  const SlotTakenFailure([super.message = AppStrings.errSlotTaken]);
}

class UnknownFailure extends AppFailure {
  const UnknownFailure([super.message = AppStrings.errUnknown]);
}
