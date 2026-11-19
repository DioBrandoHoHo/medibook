/// Vai trò tài khoản.
enum UserRole {
  customer,
  staff;

  /// Giá trị lạ/thiếu.
  static UserRole fromString(String? value) => switch (value) {
        'staff' => UserRole.staff,
        _ => UserRole.customer,
      };
}
