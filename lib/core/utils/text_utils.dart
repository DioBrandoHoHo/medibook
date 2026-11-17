/// Tiện ích văn bản phục vụ tìm kiếm và hiển thị.
abstract final class TextUtils {
  /// Số tiền VND có dấu chấm ngăn cách hàng nghìn. VD: 150000 -> "150.000 đ".
  static String money(int amount) {
    final digits = amount.abs().toString();
    final buffer = StringBuffer(amount < 0 ? '-' : '');
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return '$buffer đ';
  }

  static const _groups = <String, String>{
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  };

  static final Map<String, String> _plain = {
    for (final group in _groups.entries)
      for (final ch in group.value.split('')) ch: group.key,
  };

  /// Chữ thường, bỏ dấu tiếng Việt, bỏ khoảng trắng thừa.
  /// VD: "  Nguyễn Thị MAI " -> "nguyen thi mai". Nhờ vậy gõ "mai" hay "Mai" đều tìm ra.
  static String normalize(String input) => input
      .toLowerCase()
      .split('')
      .map((ch) => _plain[ch] ?? ch)
      .join()
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}
