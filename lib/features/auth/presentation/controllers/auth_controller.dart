import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/recovery_email.dart';
import '../../domain/repositories/auth_repository.dart';

/// Giữ phiên đăng nhập hiện tại + trạng thái gửi form Đăng nhập/Đăng ký.
/// Widget chỉ gọi các hàm và đọc state; không chứa logic Firebase.
class AuthController extends ChangeNotifier {
  AuthController(this._repository, {this.restoreTimeout = const Duration(seconds: 8)});

  final AuthRepository _repository;

  /// Giới hạn thời gian khôi phục phiên để app không treo ở màn khởi động.
  final Duration restoreTimeout;

  AppUser? _currentUser;
  bool _isLoading = false;
  String? _phoneError;
  String? _generalError;

  AppUser? get currentUser => _currentUser;

  /// Chỉ phát tín hiệu khi PHIÊN đổi (đăng nhập, đăng xuất, đổi tài khoản / vai trò),
  /// KHÔNG phát khi chỉ sửa hồ sơ. Router nghe cái này để chạy lại redirect; nếu nghe
  /// cả thay đổi hồ sơ thì việc router tải lại sẽ hoàn tác thao tác quay lại sau khi lưu.
  ValueListenable<String?> get sessionChanges => _session;
  final ValueNotifier<String?> _session = ValueNotifier<String?>(null);

  void _syncSession() {
    final user = _currentUser;
    _session.value = user == null ? null : '${user.id}|${user.role.name}';
  }
  bool get isLoading => _isLoading;

  /// Lỗi từ hệ thống gắn với ô SĐT (VD: "Số điện thoại đã được đăng ký").
  String? get phoneError => _phoneError;

  /// Lỗi chung hiển thị dạng banner (sai mật khẩu, mất mạng...).
  String? get generalError => _generalError;

  /// Tự đăng nhập lại khi mở app nếu người dùng chưa đăng xuất.
  /// Lỗi (mất mạng, hết thời gian...) không làm app dừng: coi như chưa đăng nhập.
  Future<AppUser?> restoreSession() async {
    try {
      _currentUser = await _repository.restoreSession().timeout(restoreTimeout);
    } catch (_) {
      _currentUser = null;
    }
    _syncSession();
    notifyListeners();
    return _currentUser;
  }

  Future<bool> login({required String phone, required String password}) =>
      _run(() => _repository.login(phone: phone, password: password));

  Future<bool> register({
    required String fullName,
    required String phone,
    required String password,
  }) =>
      _run(() => _repository.register(fullName: fullName, phone: phone, password: password));

  Future<bool> _run(Future<AppUser> Function() action) async {
    if (_isLoading) return false;
    _recoveryPassword = null; // đăng nhập / đăng ký mới -> bỏ mật khẩu tạm của phiên trước
    _isLoading = true;
    _phoneError = null;
    _generalError = null;
    notifyListeners();
    try {
      _currentUser = await action();
      _syncSession();
      return true;
    } on AuthFailure catch (f) {
      if (f.field == AuthField.phone) {
        _phoneError = f.message;
      } else {
        _generalError = f.message;
      }
      return false;
    } on AppFailure catch (f) {
      _generalError = f.message;
      return false;
    } catch (_) {
      // Không log chi tiết để tránh lộ dữ liệu nhạy cảm.
      _generalError = const UnknownFailure().message;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Xoá lỗi từ hệ thống khi người dùng sửa dữ liệu hoặc đổi chế độ.
  void clearErrors() {
    if (_phoneError == null && _generalError == null) return;
    _phoneError = null;
    _generalError = null;
    notifyListeners();
  }

  /// Cập nhật thông tin người dùng hiện tại sau khi sửa hồ sơ.
  void updateCurrentUser(AppUser user) {
    _currentUser = user;
    _syncSession();
    notifyListeners();
  }

  /// Đổi mật khẩu của tài khoản đang đăng nhập.
  /// Trả về `null` nếu thành công, hoặc lỗi để màn hình hiển thị
  /// (`AuthFailure` có `field == AuthField.password` = sai mật khẩu hiện tại).
  Future<AppFailure?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _repository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return null;
    } on AppFailure catch (f) {
      return f;
    } catch (_) {
      // Không log chi tiết để tránh lộ dữ liệu nhạy cảm.
      return const UnknownFailure();
    }
  }

  /// Trạng thái email khôi phục của tài khoản đang đăng nhập: (kết quả, lỗi) – đúng một cái khác null.
  Future<(RecoveryEmail?, AppFailure?)> recoveryEmailStatus() async {
    final user = _currentUser;
    if (user == null) return (null, AuthFailure.sessionExpired);
    try {
      return (await _repository.recoveryEmailStatus(phone: user.phone), null);
    } on AppFailure catch (f) {
      return (null, f);
    } catch (_) {
      return (null, const UnknownFailure());
    }
  }

  /// Mật khẩu người dùng vừa nhập khi gửi liên kết xác minh email khôi phục.
  ///
  /// Khi người dùng bấm liên kết, Firebase đổi email đăng nhập và THU HỒI phiên đang mở (phía
  /// máy chủ, app không chặn được). Để người dùng không phải đăng nhập lại, app dùng mật khẩu
  /// này đăng nhập lại ngầm vào CHÍNH tài khoản đó. Chỉ giữ trong bộ nhớ (không ghi xuống máy),
  /// xoá ngay khi email đã xác minh xong hoặc khi đăng xuất / tắt app.
  String? _recoveryPassword;

  /// Đang chờ người dùng bấm liên kết xác minh trong phiên này (app còn giữ mật khẩu tạm).
  bool get hasPendingRecovery => _recoveryPassword != null;

  /// Đặt / đổi email khôi phục (gửi liên kết xác minh). `null` = đã gửi.
  Future<AppFailure?> requestRecoveryEmail({
    required String email,
    required String currentPassword,
  }) async {
    final user = _currentUser;
    if (user == null) return AuthFailure.sessionExpired;
    try {
      await _repository.requestRecoveryEmail(
        phone: user.phone,
        email: email,
        currentPassword: currentPassword,
      );
      _recoveryPassword = currentPassword;
      return null;
    } on AppFailure catch (f) {
      return f;
    } catch (_) {
      return const UnknownFailure();
    }
  }

  /// Phiên bị thu hồi vì email khôi phục vừa được xác minh -> đăng nhập lại ngầm vào đúng tài
  /// khoản đang dùng, người dùng ở nguyên màn hình hiện tại.
  /// [password] = mật khẩu người dùng nhập lại (khi app không còn giữ mật khẩu tạm, VD đã tắt
  /// app trước khi bấm liên kết). `null` = thành công.
  Future<AppFailure?> resumeAfterEmailChange({String? password}) async {
    final user = _currentUser;
    final secret = password ?? _recoveryPassword;
    if (user == null || secret == null) return AuthFailure.sessionExpired;
    try {
      final renewed = await _repository.login(phone: user.phone, password: secret);
      if (renewed.id != user.id) {
        // Không thể xảy ra với SĐT của chính người dùng; phòng hờ thì coi như hết phiên.
        await logout();
        return AuthFailure.sessionExpired;
      }
      _recoveryPassword = null;
      // Cùng tài khoản, cùng vai trò -> khoá phiên không đổi nên router không chuyển trang.
      _currentUser = renewed;
      _syncSession();
      notifyListeners();
      return null;
    } on AppFailure catch (f) {
      return f;
    } catch (_) {
      return const UnknownFailure();
    }
  }

  /// Gọi khi app quay lại từ nền (VD người dùng vừa bấm liên kết trong ứng dụng email):
  /// nếu đang chờ xác minh và phiên đã bị thu hồi thì đăng nhập lại ngầm ngay, trước khi các màn
  /// khác gặp lỗi không có quyền. Không chờ xác minh thì không làm gì.
  Future<void> checkPendingRecovery() async {
    if (_recoveryPassword == null) return;
    final (status, failure) = await recoveryEmailStatus();
    if (failure == AuthFailure.sessionExpired) {
      await resumeAfterEmailChange();
    } else if (status != null && status.pending == null) {
      _recoveryPassword = null; // đã xác minh (hoặc không còn email chờ) -> bỏ mật khẩu tạm
    }
  }

  /// Quên mật khẩu: (email đã che bớt, lỗi) – đúng một cái khác null.
  Future<(String?, AppFailure?)> sendPasswordReset(String phone) async {
    try {
      return (await _repository.sendPasswordReset(phone: phone), null);
    } on AppFailure catch (f) {
      return (null, f);
    } catch (_) {
      // Không log chi tiết để tránh lộ dữ liệu nhạy cảm.
      return (null, const UnknownFailure());
    }
  }

  /// Đăng xuất (nút nằm ở tab Tài khoản của Staff).
  /// Sau khi gọi, router tự chuyển người dùng khỏi các trang cần đăng nhập về /auth.
  /// Luôn xoá phiên cục bộ kể cả khi Firebase báo lỗi, để không kẹt trong khu vực đã đăng nhập.
  Future<void> logout() async {
    try {
      await _repository.logout();
    } catch (_) {
      // Bỏ qua: phiên cục bộ vẫn bị xoá bên dưới.
    }
    _currentUser = null;
    _recoveryPassword = null;
    _phoneError = null;
    _generalError = null;
    _syncSession();
    notifyListeners();
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }
}
