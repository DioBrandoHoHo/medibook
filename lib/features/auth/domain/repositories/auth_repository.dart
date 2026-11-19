import '../entities/app_user.dart';
import '../entities/recovery_email.dart';

/// Hợp đồng tầng dữ liệu xác thực.
abstract interface class AuthRepository {
  /// Tạo tài khoản Customer.
  Future<AppUser> register({
    required String fullName,
    required String phone,
    required String password,
  });

  /// Đăng nhập bằng SĐT.
  Future<AppUser> login({required String phone, required String password});

  /// Khôi phục phiên đã lưu trên máy (người dùng chưa đăng xuất).
  Future<AppUser?> restoreSession();

  /// Xoá phiên đăng nhập trên máy.
  Future<void> logout();

  /// Đổi mật khẩu của tài khoản đang đăng nhập.
  Future<void> changePassword({required String currentPassword, required String newPassword});

  /// Trạng thái email khôi phục của tài khoản đang đăng nhập (SĐT [phone]).
  Future<RecoveryEmail> recoveryEmailStatus({required String phone});

  /// Đặt / đổi email khôi phục.
  Future<void> requestRecoveryEmail({
    required String phone,
    required String email,
    required String currentPassword,
  });

  /// Quên mật khẩu.
  Future<String> sendPasswordReset({required String phone});
}
