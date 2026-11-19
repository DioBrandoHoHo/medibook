import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/utils/name_utils.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/recovery_email.dart';
import '../../domain/repositories/auth_repository.dart';

/// Giữ phiên đăng nhập hiện tại + trạng thái gửi form Đăng nhập/Đăng ký.
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

  /// Phát tín hiệu khi phiên đăng nhập đổi.
  ValueListenable<String?> get sessionChanges => _session;
  final ValueNotifier<String?> _session = ValueNotifier<String?>(null);

  void _syncSession() {
    final user = _currentUser;
    _session.value = user == null ? null : '${user.id}|${user.role.name}';
  }
  bool get isLoading => _isLoading;

  /// Lỗi từ hệ thống gắn với ô SĐT.
  String? get phoneError => _phoneError;

  /// Lỗi chung hiển thị dạng banner (sai mật khẩu, mất mạng...).
  String? get generalError => _generalError;

  /// Tự đăng nhập lại khi mở app nếu người dùng chưa đăng xuất.
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
      _run(
        () => _repository.register(
          fullName: NameUtils.normalize(fullName),
          phone: phone,
          password: password,
        ),
      );

  Future<bool> _run(Future<AppUser> Function() action) async {
    if (_isLoading) return false;
    _recoveryPassword = null;
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
      return const UnknownFailure();
    }
  }

  /// Trạng thái email khôi phục của tài khoản đang đăng nhập.
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
  String? _recoveryPassword;

  /// Đang chờ người dùng bấm liên kết xác minh trong phiên này (app còn giữ mật khẩu tạm).
  bool get hasPendingRecovery => _recoveryPassword != null;

  /// Đặt / đổi email khôi phục.
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

  /// Phiên bị thu hồi vì email khôi phục vừa được xác minh.
  Future<AppFailure?> resumeAfterEmailChange({String? password}) async {
    final user = _currentUser;
    final secret = password ?? _recoveryPassword;
    if (user == null || secret == null) return AuthFailure.sessionExpired;
    try {
      final renewed = await _repository.login(phone: user.phone, password: secret);
      if (renewed.id != user.id) {
        await logout();
        return AuthFailure.sessionExpired;
      }
      _recoveryPassword = null;
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

  /// Gọi khi app quay lại từ nền.
  Future<void> checkPendingRecovery() async {
    if (_recoveryPassword == null) return;
    final (status, failure) = await recoveryEmailStatus();
    if (failure == AuthFailure.sessionExpired) {
      await resumeAfterEmailChange();
    } else if (status != null && status.pending == null) {
      _recoveryPassword = null;
    }
  }

  /// Quên mật khẩu.
  Future<(String?, AppFailure?)> sendPasswordReset(String phone) async {
    try {
      return (await _repository.sendPasswordReset(phone: phone), null);
    } on AppFailure catch (f) {
      return (null, f);
    } catch (_) {
      return (null, const UnknownFailure());
    }
  }

  /// Đăng xuất.
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
