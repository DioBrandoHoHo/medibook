/// Giới tính trong hồ sơ.
enum UserGender {
  male,
  female,
  other;

  /// Giá trị lạ hoặc thiếu.
  static UserGender? fromString(String? value) {
    for (final g in values) {
      if (g.name == value) return g;
    }
    return null;
  }
}
