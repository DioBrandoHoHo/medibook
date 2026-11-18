abstract final class NameUtils {
  /// Bỏ khoảng trắng thừa: "  nguyễn   văn  bình " -> "nguyễn văn bình". Dùng trước khi lưu họ tên.
  static String normalize(String fullName) => fullName.trim().split(RegExp(r'\s+')).join(' ');

  /// Chữ cái đầu của TÊN (từ cuối cùng trong họ tên tiếng Việt) để hiện thay ảnh đại diện.
  /// VD: "Nguyễn Thị Mai" -> "M". Tên rỗng -> "?".
  static String initial(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts.last.substring(0, 1).toUpperCase();
  }
}
