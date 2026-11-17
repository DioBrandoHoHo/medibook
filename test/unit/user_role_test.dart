import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/features/auth/domain/entities/user_role.dart';

void main() {
  group('UserRole.fromString', () {
    test('trả về staff khi giá trị là "staff"', () {
      expect(UserRole.fromString('staff'), UserRole.staff);
    });
    test('mặc định customer với giá trị lạ hoặc null (an toàn)', () {
      expect(UserRole.fromString('admin'), UserRole.customer);
      expect(UserRole.fromString(null), UserRole.customer);
    });
  });
}
