import '../entities/app_user.dart';
import '../entities/recovery_email.dart';

/// Hợp đồng tầng dữ liệu xác thực. UI/controller chỉ phụ thuộc interface này,
/// nên có thể thay bằng Fake khi test hoặc Firebase khi chạy thật.
///
/// Mọi lỗi được ném ra dưới dạng `AppFailure` (xem core/errors/app_failure.dart).
abstract interface class AuthRepository {
  /// Tạo tài khoản Customer. Ném `AuthFailure.phoneAlreadyRegistered` nếu SĐT đã tồn tại.
  Future<AppUser> register({
    required String fullName,
    required String phone,
    required String password,
  });

  /// Ném `AuthFailure.phoneNotRegistered` hoặc `AuthFailure.wrongCredentials`.
  Future<AppUser> login({required String phone, required String password});

  /// Khôi phục phiên đã lưu trên máy (người dùng chưa đăng xuất).
  /// Trả về `null` nếu không có phiên hợp lệ.
  Future<AppUser?> restoreSession();

  /// Xoá phiên đăng nhập trên máy.
  Future<void> logout();

  /// Đổi mật khẩu của tài khoản đang đăng nhập. Mật khẩu hiện tại được kiểm tra lại
  /// ở phía máy chủ; sai thì ném `AuthFailure.currentPasswordWrong`.
  Future<void> changePassword({required String currentPassword, required String newPassword});

  /// Trạng thái email khôi phục của tài khoản đang đăng nhập (SĐT [phone]).
  /// Ném `AuthFailure.sessionExpired` nếu phiên không còn hợp lệ (VD email vừa được xác minh
  /// ở trình duyệt nên phiên cũ bị thu hồi) -> phải đăng nhập lại.
  Future<RecoveryEmail> recoveryEmailStatus({required String phone});

  /// Đặt / đổi email khôi phục: kiểm tra lại mật khẩu hiện tại rồi gửi liên kết xác minh tới
  /// [email]. Email chỉ có hiệu lực sau khi người dùng bấm liên kết.
  /// Ném `AuthFailure.currentPasswordWrong`, `AuthFailure.emailInUse`, `AuthFailure.emailInvalid`.
  Future<void> requestRecoveryEmail({
    required String phone,
    required String email,
    required String currentPassword,
  });

  /// Quên mật khẩu: gửi liên kết đặt lại mật khẩu tới email khôi phục ĐÃ xác minh của tài khoản
  /// có SĐT [phone]. Trả về email đã che bớt để hiển thị.
  /// Ném `AuthFailure.noRecoveryEmail` / `AuthFailure.recoveryNotVerified`.
  Future<String> sendPasswordReset({required String phone});
}
