/// Xử lý số điện thoại Việt Nam (logic thuần Dart, không phụ thuộc UI/Firebase).
abstract final class PhoneUtils {
  /// Miền email nội bộ dùng để quy đổi SĐT sang tài khoản Email/Password của Firebase.
  static const authEmailDomain = 'medibook.local';

  // Di động VN sau khi chuẩn hoá: 0 + đầu số 3/5/7/8/9 + 8 chữ số = 10 chữ số.
  static final _vnMobile = RegExp(r'^0[35789]\d{8}$');

  /// Chuẩn hoá về dạng `0xxxxxxxxx`:
  /// bỏ khoảng trắng, dấu chấm, gạch, ngoặc; đổi tiền tố `+84`/`84` thành `0`.
  /// Trả về chuỗi đã làm sạch (có thể vẫn chưa hợp lệ – dùng [isValid] để kiểm tra).
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

  /// `0912 345 678` -> `0912345678@medibook.local`.
  static String toAuthEmail(String input) => '${normalize(input)}@$authEmailDomain';
}
