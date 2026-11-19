/// Xử lý số điện thoại Việt Nam.
abstract final class PhoneUtils {
  /// Miền email nội bộ dùng để quy đổi SĐT sang tài khoản Email/Password của Firebase.
  static const authEmailDomain = 'medibook.local';

  static final _vnMobile = RegExp(r'^0[35789]\d{8}$');

  /// Chuẩn hoá về dạng `0xxxxxxxxx`.
  static String normalize(String input) {
    var s = input.trim().replaceAll(RegExp(r'[\s.\-()]'), '');
    if (s.startsWith('+84')) {
      s = '0${s.substring(3)}';
    } else if (s.startsWith('84') && s.length == 11) {
      s = '0${s.substring(2)}';
    }
    return s;
  }

  /// SĐT (sau chuẩn hoá) có đúng định dạng di động Việt Nam không.
  static bool isValid(String input) => _vnMobile.hasMatch(normalize(input));

  /// Quy đổi SĐT sang email nội bộ.
  static String toAuthEmail(String input) => '${normalize(input)}@$authEmailDomain';
}
