import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/utils/name_utils.dart';
import '../../../auth/domain/entities/user_gender.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/repositories/profile_repository.dart';

/// Lưu hồ sơ và đồng bộ lại người dùng trong [AuthController].
class ProfileController extends ChangeNotifier {
  ProfileController(this._repository, this._auth, {this.saveTimeout = const Duration(seconds: 10)});

  final ProfileRepository _repository;
  final AuthController _auth;
  final Duration saveTimeout;

  bool _isSaving = false;
  String? _error;

  bool get isSaving => _isSaving;
  String? get error => _error;

  /// Lưu màn Cập nhật thông tin. Ghi Firestore TRƯỚC; chỉ khi thành công mới cập nhật
  /// người dùng trong [AuthController] -> mọi màn hình đang hiển thị hồ sơ đổi theo.
  /// Thất bại thì dữ liệu trong app giữ nguyên.
  Future<bool> save({
    required String fullName,
    String email = '',
    DateTime? birthDate,
    UserGender? gender,
  }) async {
    final user = _auth.currentUser;
    if (user == null || _isSaving) return false;
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      await _repository
          .updateProfile(
            uid: user.id,
            fullName: NameUtils.normalize(fullName),
            email: email.trim(),
            birthDate: birthDate,
            gender: gender,
          )
          .timeout(saveTimeout, onTimeout: () => throw const NetworkFailure());
      _auth.updateCurrentUser(
        user.withProfile(
          fullName: NameUtils.normalize(fullName),
          email: email.trim(),
          birthDate: birthDate,
          gender: gender,
        ),
      );
      return true;
    } on AppFailure catch (f) {
      _error = f.message;
      return false;
    } catch (_) {
      _error = const UnknownFailure().message;
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Lưu ảnh đại diện (chuỗi base64 đã xử lý; `''` = xoá ảnh). Cùng nguyên tắc với [save]:
  /// ghi Firestore TRƯỚC, thành công mới cập nhật [AuthController] -> mọi nơi hiển thị ảnh
  /// (thẻ tài khoản, phần đầu Trang chủ, màn Cập nhật thông tin) đổi ngay. Thất bại giữ ảnh cũ.
  Future<bool> saveAvatar(String avatar) async {
    final user = _auth.currentUser;
    if (user == null || _isSaving) return false;
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      await _repository
          .updateAvatar(uid: user.id, avatar: avatar)
          .timeout(saveTimeout, onTimeout: () => throw const NetworkFailure());
      // Đọc lại người dùng hiện tại: trong lúc chờ ghi, hồ sơ có thể đã đổi ở nơi khác.
      final latest = _auth.currentUser;
      if (latest != null && latest.id == user.id) {
        _auth.updateCurrentUser(latest.copyWith(avatar: avatar));
      }
      return true;
    } on AppFailure catch (f) {
      _error = f.message;
      return false;
    } catch (_) {
      _error = const UnknownFailure().message;
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Người dùng bấm "Để sau": cập nhật ngay trên app để không chặn việc chuyển trang,
  /// ghi `profilePromptDismissed = true` lên Firestore ở nền.
  /// (Firestore tự đồng bộ lại khi có mạng; nếu ghi thất bại thì lần đăng nhập sau
  /// câu hỏi sẽ xuất hiện lại – không gây lỗi.)
  void dismissPrompt() {
    final user = _auth.currentUser;
    if (user == null) return;
    _auth.updateCurrentUser(user.copyWith(profilePromptDismissed: true));
    unawaited(_repository.dismissProfilePrompt(uid: user.id).catchError((Object _) {}));
  }
}
