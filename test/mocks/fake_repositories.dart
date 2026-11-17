import 'package:medibook/core/errors/app_failure.dart';
import 'package:medibook/core/utils/phone_utils.dart';
import 'package:medibook/features/auth/domain/entities/app_user.dart';
import 'package:medibook/features/auth/domain/entities/recovery_email.dart';
import 'package:medibook/features/auth/domain/entities/user_gender.dart';
import 'package:medibook/features/auth/domain/entities/user_role.dart';
import 'package:medibook/features/auth/domain/repositories/auth_repository.dart';
import 'package:medibook/features/profile/domain/repositories/profile_repository.dart';

/// Repository giả lập trong bộ nhớ – CHỈ dùng cho test.
/// Mô phỏng cả "phiên đăng nhập lưu trên máy" để test tự đăng nhập lại.
class FakeAuthRepository implements AuthRepository {
  final Map<String, ({AppUser user, String password})> _accounts = {};
  AppFailure? nextError; // ép lỗi cho lần gọi kế tiếp (VD mất mạng)
  String? _sessionPhone; // SĐT của phiên đang lưu (null = đã đăng xuất)
  int _seq = 0;
  int logoutCalls = 0;

  // ----- Email khôi phục / quên mật khẩu (mô phỏng Firebase) -----
  final Map<String, String> _verifiedEmail = {}; // SĐT -> email đã xác minh
  final Map<String, String> _pendingEmail = {}; // SĐT -> email đang chờ bấm liên kết

  /// Các email đã được gửi liên kết xác minh / liên kết đặt lại mật khẩu.
  final List<String> verifyEmailsSent = [];
  final List<String> resetEmailsSent = [];

  /// Mô phỏng người dùng bấm liên kết xác minh trong thư. Giống Firebase: email đổi xong thì
  /// phiên đang mở hết hiệu lực ([expireSession]).
  void clickVerifyLink(String phone, {bool expireSession = true}) {
    final p = PhoneUtils.normalize(phone);
    final email = _pendingEmail.remove(p);
    if (email == null) return;
    _verifiedEmail[p] = email;
    if (expireSession && _sessionPhone == p) _sessionExpired = true;
  }

  /// Mô phỏng người dùng bấm liên kết đặt lại mật khẩu và nhập mật khẩu mới trên trang Firebase.
  void resetPasswordFromEmail(String phone, String newPassword) {
    final p = PhoneUtils.normalize(phone);
    final acc = _accounts[p]!;
    _accounts[p] = (user: acc.user, password: newPassword);
  }

  bool _sessionExpired = false;

  @override
  Future<RecoveryEmail> recoveryEmailStatus({required String phone}) async {
    _throwIfForced();
    final p = PhoneUtils.normalize(phone);
    if (_sessionPhone != p || _sessionExpired) throw AuthFailure.sessionExpired;
    return RecoveryEmail(verified: _verifiedEmail[p], pending: _pendingEmail[p]);
  }

  @override
  Future<void> requestRecoveryEmail({
    required String phone,
    required String email,
    required String currentPassword,
  }) async {
    _throwIfForced();
    final p = PhoneUtils.normalize(phone);
    final acc = _accounts[p];
    if (acc == null || _sessionPhone != p || _sessionExpired) throw AuthFailure.sessionExpired;
    if (acc.password != currentPassword) throw AuthFailure.currentPasswordWrong;
    final usedByOther =
        _verifiedEmail.entries.any((e) => e.key != p && e.value == email);
    if (usedByOther) throw AuthFailure.emailInUse;
    _pendingEmail[p] = email;
    verifyEmailsSent.add(email);
  }

  @override
  Future<String> sendPasswordReset({required String phone}) async {
    _throwIfForced();
    final p = PhoneUtils.normalize(phone);
    final verified = _verifiedEmail[p];
    if (verified == null) {
      throw _pendingEmail.containsKey(p)
          ? AuthFailure.recoveryNotVerified
          : AuthFailure.noRecoveryEmail;
    }
    resetEmailsSent.add(verified);
    return RecoveryEmail.mask(verified);
  }

  /// Tạo sẵn tài khoản (VD tài khoản Staff do quản trị cấp).
  /// [signedIn] = true mô phỏng người dùng chưa đăng xuất từ lần trước.
  void seed({
    required String phone,
    required String password,
    String fullName = 'Người dùng',
    UserRole role = UserRole.customer,
    bool profileCompleted = false,
    bool profilePromptDismissed = false,
    bool signedIn = false,
    String email = '',
    DateTime? birthDate,
    UserGender? gender,
  }) {
    final p = PhoneUtils.normalize(phone);
    _accounts[p] = (
      user: AppUser(
        id: 'u${_seq++}',
        fullName: fullName,
        phone: p,
        role: role,
        email: email,
        birthDate: birthDate,
        gender: gender,
        profileCompleted: profileCompleted,
        profilePromptDismissed: profilePromptDismissed,
      ),
      password: password,
    );
    if (signedIn) _sessionPhone = p;
  }

  /// Đọc tài khoản đã lưu (như đọc document Firestore).
  AppUser? storedUser(String phone) => _accounts[PhoneUtils.normalize(phone)]?.user;

  /// Sửa dữ liệu đã lưu theo uid (như FakeProfileRepository ghi vào Firestore).
  void updateStored(String uid, AppUser Function(AppUser) change) {
    final key = _accounts.keys.firstWhere((k) => _accounts[k]!.user.id == uid);
    final acc = _accounts[key]!;
    _accounts[key] = (user: change(acc.user), password: acc.password);
  }

  void _throwIfForced() {
    final e = nextError;
    if (e != null) {
      nextError = null;
      throw e;
    }
  }

  @override
  Future<AppUser> register({
    required String fullName,
    required String phone,
    required String password,
  }) async {
    _throwIfForced();
    final p = PhoneUtils.normalize(phone);
    if (_accounts.containsKey(p)) throw AuthFailure.phoneAlreadyRegistered;
    seed(phone: p, password: password, fullName: fullName.trim(), signedIn: true);
    return _accounts[p]!.user;
  }

  @override
  Future<AppUser> login({required String phone, required String password}) async {
    _throwIfForced();
    final p = PhoneUtils.normalize(phone);
    final acc = _accounts[p];
    if (acc == null) throw AuthFailure.phoneNotRegistered;
    if (acc.password != password) throw AuthFailure.wrongCredentials;
    _sessionPhone = p;
    _sessionExpired = false;
    return acc.user;
  }

  @override
  Future<AppUser?> restoreSession() async {
    _throwIfForced();
    final p = _sessionPhone;
    return p == null ? null : _accounts[p]?.user;
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
    _throwIfForced();
    _sessionPhone = null;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _throwIfForced();
    final acc = _accounts[_sessionPhone];
    if (acc == null) throw AuthFailure.sessionExpired;
    if (acc.password != currentPassword) throw AuthFailure.currentPasswordWrong;
    _accounts[_sessionPhone!] = (user: acc.user, password: newPassword);
  }
}

/// Ghi hồ sơ vào [FakeAuthRepository] (nếu có) để mô phỏng dữ liệu Firestore dùng chung.
class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository([this.auth]);

  final FakeAuthRepository? auth;
  final List<String> savedNames = [];
  final List<String> dismissedUids = [];

  /// Ép lỗi cho lần lưu kế tiếp (VD mất mạng).
  AppFailure? nextError;

  @override
  Future<void> updateProfile({
    required String uid,
    required String fullName,
    String email = '',
    DateTime? birthDate,
    UserGender? gender,
  }) async {
    final e = nextError;
    if (e != null) {
      nextError = null;
      throw e;
    }
    savedNames.add(fullName);
    auth?.updateStored(
      uid,
      (u) => u.withProfile(fullName: fullName, email: email, birthDate: birthDate, gender: gender),
    );
  }

  @override
  Future<void> dismissProfilePrompt({required String uid}) async {
    dismissedUids.add(uid);
    auth?.updateStored(uid, (u) => u.copyWith(profilePromptDismissed: true));
  }
}
