import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/utils/phone_utils.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/recovery_email.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';

/// Triển khai [AuthRepository] bằng Firebase Auth (Email/Password) + Cloud Firestore.
///
/// SĐT được chuẩn hoá rồi quy đổi sang email nội bộ `<sdt>@medibook.local`.
/// - Trùng SĐT được Firebase Auth chặn ở phía server (email là duy nhất).
/// - Vai trò đọc từ `users/{uid}.role`; Security Rules chỉ cho tự tạo role `customer`.
///
/// Quên mật khẩu (phương án "email khôi phục"): khi người dùng xác minh một email thật, email
/// đăng nhập của tài khoản Firebase đổi từ `<sdt>@medibook.local` sang email đó – nhờ vậy
/// Firebase gửi được liên kết đặt lại mật khẩu. Người dùng VẪN đăng nhập bằng SĐT: app tra
/// `login_index/{sdt}` để biết email đăng nhập hiện tại.
/// ```
/// login_index/{phone}
///   uid:       string
///   emails:    [string]   // tối đa 2: email đã xác minh (nếu có) + email đang chờ xác minh
///   updatedAt: timestamp
/// ```
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  static const loginIndexCollection = 'login_index';

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection(UserModel.collection).doc(uid);

  DocumentReference<Map<String, dynamic>> _loginIndex(String phone) =>
      _db.collection(loginIndexCollection).doc(PhoneUtils.normalize(phone));

  static bool _isInternalEmail(String? email) =>
      email == null || email.endsWith('@${PhoneUtils.authEmailDomain}');

  /// Các email thật gắn với SĐT (theo `login_index`). `null` = SĐT chưa từng đặt email khôi phục.
  Future<List<String>?> _indexedEmails(String phone) async {
    final snap = await _loginIndex(phone).get();
    final emails = snap.data()?['emails'];
    if (emails is! List) return null;
    final result = emails.whereType<String>().where((e) => e.isNotEmpty).toList();
    return result.isEmpty ? null : result;
  }

  /// Như [_indexedEmails] nhưng lỗi (mất mạng...) coi như không có – dùng ở Đăng nhập / Đăng ký
  /// để không làm hỏng luồng cũ.
  Future<List<String>?> _indexedEmailsOrNull(String phone) async {
    try {
      return await _indexedEmails(phone);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AppUser> register({
    required String fullName,
    required String phone,
    required String password,
  }) async {
    final normalized = PhoneUtils.normalize(phone);
    // SĐT đã có tài khoản dùng email khôi phục (email nội bộ không còn tồn tại nên Firebase
    // không tự chặn được) -> vẫn phải báo trùng.
    if (await _indexedEmailsOrNull(normalized) != null) throw AuthFailure.phoneAlreadyRegistered;
    final UserCredential cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(
        email: PhoneUtils.toAuthEmail(normalized),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e, isRegister: true);
    }

    final user = cred.user!;
    final data = UserModel.newCustomerMap(fullName: fullName.trim(), phone: normalized);
    try {
      await _userDoc(user.uid).set({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      // Không ghi được hồ sơ -> xoá tài khoản Auth vừa tạo để người dùng đăng ký lại được.
      await _safeDeleteUser(user);
      throw _mapFirestoreError(e);
    }
    return UserModel.fromMap(user.uid, data);
  }

  @override
  Future<AppUser> login({required String phone, required String password}) async {
    final cred = await _signIn(phone, password);

    try {
      final snap = await _userDoc(cred.user!.uid).get();
      final map = snap.data();
      if (map == null) {
        await _auth.signOut();
        throw const UnknownFailure(AppStrings.errAccountDataMissing);
      }
      return UserModel.fromMap(snap.id, map);
    } on FirebaseException catch (e) {
      await _auth.signOut();
      throw _mapFirestoreError(e);
    }
  }

  /// Đăng nhập bằng SĐT: thử email nội bộ trước (mọi tài khoản chưa đặt email khôi phục – luồng
  /// cũ không đổi); không được thì tra `login_index` và thử các email thật của SĐT đó.
  Future<UserCredential> _signIn(String phone, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: PhoneUtils.toAuthEmail(phone),
        password: password,
      );
    } on FirebaseAuthException catch (first) {
      const mayHaveRealEmail = {'user-not-found', 'invalid-credential', 'invalid-login-credentials'};
      if (!mayHaveRealEmail.contains(first.code)) throw _mapAuthError(first, isRegister: false);
      final emails = await _indexedEmailsOrNull(phone);
      if (emails == null) throw _mapAuthError(first, isRegister: false);
      for (final email in emails) {
        try {
          return await _auth.signInWithEmailAndPassword(email: email, password: password);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'too-many-requests' || e.code == 'network-request-failed') {
            throw _mapAuthError(e, isRegister: false);
          }
          // Email này chưa phải email đăng nhập / sai mật khẩu -> thử email kế tiếp.
        }
      }
      // SĐT có trong login_index nghĩa là ĐÃ đăng ký -> lỗi còn lại là sai mật khẩu.
      throw AuthFailure.wrongCredentials;
    }
  }

  @override
  Future<RecoveryEmail> recoveryEmailStatus({required String phone}) async {
    var user = _auth.currentUser;
    if (user == null) throw AuthFailure.sessionExpired;
    try {
      await user.reload(); // lấy email mới nhất (người dùng có thể vừa bấm liên kết xác minh)
      user = _auth.currentUser;
    } on FirebaseAuthException catch (e) {
      if (e.code != 'network-request-failed') throw AuthFailure.sessionExpired;
    }
    if (user == null) throw AuthFailure.sessionExpired;
    final verified = _isInternalEmail(user.email) ? null : user.email;
    String? pending;
    try {
      final emails = await _indexedEmails(phone);
      if (emails != null && emails.last != verified) pending = emails.last;
    } on FirebaseException catch (e) {
      throw _mapFirestoreError(e);
    }
    return RecoveryEmail(verified: verified, pending: pending);
  }

  @override
  Future<void> requestRecoveryEmail({
    required String phone,
    required String email,
    required String currentPassword,
  }) async {
    final user = _auth.currentUser;
    final current = user?.email;
    if (user == null || current == null) throw AuthFailure.sessionExpired;
    final target = email.trim();
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: current, password: currentPassword),
      );
      // Ghi bảng tra TRƯỚC khi gửi thư: nếu ghi sau mà thất bại, người dùng xác minh xong
      // sẽ không đăng nhập lại được bằng SĐT.
      await _loginIndex(phone).set({
        'uid': user.uid,
        'emails': [if (!_isInternalEmail(current) && current != target) current, target],
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _auth.setLanguageCode('vi');
      await user.verifyBeforeUpdateEmail(target);
    } on FirebaseAuthException catch (e) {
      throw switch (e.code) {
        'wrong-password' ||
        'invalid-credential' ||
        'invalid-login-credentials' =>
          AuthFailure.currentPasswordWrong,
        'email-already-in-use' => AuthFailure.emailInUse,
        'invalid-email' || 'invalid-new-email' || 'missing-new-email' => AuthFailure.emailInvalid,
        'too-many-requests' => AuthFailure.tooManyRequests,
        'network-request-failed' => const NetworkFailure(),
        'user-not-found' ||
        'user-disabled' ||
        'user-token-expired' ||
        'requires-recent-login' =>
          AuthFailure.sessionExpired,
        _ => const UnknownFailure(),
      };
    } on FirebaseException catch (e) {
      throw _mapFirestoreError(e);
    }
  }

  @override
  Future<String> sendPasswordReset({required String phone}) async {
    final List<String>? emails;
    try {
      emails = await _indexedEmails(phone);
    } on FirebaseException catch (e) {
      throw _mapFirestoreError(e);
    }
    if (emails == null) throw AuthFailure.noRecoveryEmail;
    await _auth.setLanguageCode('vi');
    for (final email in emails) {
      try {
        await _auth.sendPasswordResetEmail(email: email);
        return RecoveryEmail.mask(email);
      } on FirebaseAuthException catch (e) {
        // user-not-found = email này chưa được xác minh (chưa phải email đăng nhập) -> thử tiếp.
        if (e.code == 'user-not-found' || e.code == 'invalid-email') continue;
        throw switch (e.code) {
          'too-many-requests' => AuthFailure.tooManyRequests,
          'network-request-failed' => const NetworkFailure(),
          _ => const UnknownFailure(),
        };
      }
    }
    throw AuthFailure.recoveryNotVerified;
  }

  @override
  Future<AppUser?> restoreSession() async {
    // Chờ SDK nạp xong phiên đã lưu trên máy (sự kiện đầu tiên của authStateChanges).
    final user = await _auth.authStateChanges().first;
    if (user == null) return null;
    try {
      final snap = await _userDoc(user.uid).get();
      final map = snap.data();
      if (map == null) {
        // Có tài khoản Auth nhưng không có hồ sơ -> không cho vào, xoá phiên.
        await _auth.signOut();
        return null;
      }
      return UserModel.fromMap(snap.id, map);
    } on FirebaseException catch (e) {
      // Mất mạng và chưa có cache: giữ phiên, nhưng để người dùng vào từ màn Welcome.
      throw _mapFirestoreError(e);
    }
  }

  @override
  Future<void> logout() => _auth.signOut();

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) throw AuthFailure.sessionExpired;
    try {
      // Bắt buộc xác thực lại bằng mật khẩu hiện tại trước khi đổi (Firebase kiểm tra phía server).
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: currentPassword),
      );
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw switch (e.code) {
        'wrong-password' ||
        'invalid-credential' ||
        'invalid-login-credentials' =>
          AuthFailure.currentPasswordWrong,
        'too-many-requests' => AuthFailure.tooManyRequests,
        'network-request-failed' => const NetworkFailure(),
        'user-not-found' ||
        'user-disabled' ||
        'user-token-expired' ||
        'requires-recent-login' =>
          AuthFailure.sessionExpired,
        _ => const UnknownFailure(),
      };
    }
  }

  Future<void> _safeDeleteUser(User user) async {
    try {
      await user.delete();
    } on Exception {
      await _auth.signOut();
    }
  }

  /// Chuyển mã lỗi Firebase thành thông báo theo đặc tả, không lộ chi tiết kỹ thuật.
  static AppFailure _mapAuthError(FirebaseAuthException e, {required bool isRegister}) {
    switch (e.code) {
      case 'email-already-in-use':
        return AuthFailure.phoneAlreadyRegistered;
      case 'user-not-found':
        return AuthFailure.phoneNotRegistered;
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        // Lưu ý: khi bật "Email enumeration protection", Firebase trả invalid-credential
        // cho CẢ trường hợp SĐT chưa đăng ký -> không phân biệt được (xem README).
        return AuthFailure.wrongCredentials;
      case 'too-many-requests':
        return AuthFailure.tooManyRequests;
      case 'network-request-failed':
        return const NetworkFailure();
      default:
        return const UnknownFailure();
    }
  }

  static AppFailure _mapFirestoreError(FirebaseException e) => switch (e.code) {
        'unavailable' || 'deadline-exceeded' => const NetworkFailure(),
        'permission-denied' => const PermissionFailure(),
        _ => const UnknownFailure(),
      };
}
