/// Vai trò tài khoản. Giá trị lưu ở Firestore; app chỉ đọc, không cho tự đổi.
enum UserRole {
  customer,
  staff;

  /// Giá trị lạ/thiếu -> customer (quyền thấp nhất, an toàn).
  static UserRole fromString(String? value) => switch (value) {
        'staff' => UserRole.staff,
        _ => UserRole.customer,
      };
}
