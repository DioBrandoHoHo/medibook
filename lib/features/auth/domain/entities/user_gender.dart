/// Giới tính trong hồ sơ (tuỳ chọn). Lưu trên Firestore bằng `name`: male | female | other.
enum UserGender {
  male,
  female,
  other;

  /// Giá trị lạ hoặc thiếu -> `null` (chưa cập nhật).
  static UserGender? fromString(String? value) {
    for (final g in values) {
      if (g.name == value) return g;
    }
    return null;
  }
}
