abstract final class NameUtils {
  /// Chữ cái đầu của TÊN (từ cuối cùng trong họ tên tiếng Việt) để hiện thay ảnh đại diện.
  /// VD: "Nguyễn Thị Mai" -> "M". Tên rỗng -> "?".
  static String initial(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts.last.substring(0, 1).toUpperCase();
  }
}
