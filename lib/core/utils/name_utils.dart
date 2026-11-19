abstract final class NameUtils {
  /// Bỏ khoảng trắng thừa.
  static String normalize(String fullName) => fullName.trim().split(RegExp(r'\s+')).join(' ');

  /// Chữ cái đầu của tên để hiện thay ảnh đại diện.
  static String initial(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts.last.substring(0, 1).toUpperCase();
  }
}
