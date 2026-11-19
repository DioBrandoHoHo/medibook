/// Trạng thái "email khôi phục mật khẩu" của tài khoản đang đăng nhập.
class RecoveryEmail {
  const RecoveryEmail({this.verified, this.pending});

  /// Email ĐÃ xác minh.
  final String? verified;

  /// Email đã yêu cầu nhưng CHƯA bấm liên kết xác minh.
  final String? pending;

  bool get isSet => verified != null;

  /// Che bớt email khi hiển thị ở màn Quên mật khẩu (người lạ không đọc được trọn email).
  static String mask(String email) {
    final at = email.indexOf('@');
    if (at <= 0) return email;
    final name = email.substring(0, at);
    final shown = name.length <= 2 ? name.substring(0, 1) : name.substring(0, 2);
    return '$shown${'•' * (name.length - shown.length).clamp(1, 8)}${email.substring(at)}';
  }
}
