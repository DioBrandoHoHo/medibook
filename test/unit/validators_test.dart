import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/constants/app_strings.dart';
import 'package:medibook/core/utils/validators.dart';

void main() {
  group('PasswordRules', () {
    test('mật khẩu rỗng không đạt điều kiện nào', () {
      final r = PasswordRules.check('');
      expect([r.hasMinLength, r.hasUppercase, r.hasDigit, r.hasSpecialChar], everyElement(isFalse));
      expect(r.allPassed, isFalse);
    });

    test('kiểm tra từng điều kiện độc lập', () {
      expect(PasswordRules.check('abcdefgh').hasMinLength, isTrue);
      expect(PasswordRules.check('abcdefg').hasMinLength, isFalse);
      expect(PasswordRules.check('aB').hasUppercase, isTrue);
      expect(PasswordRules.check('a1').hasDigit, isTrue);
      expect(PasswordRules.check('a@').hasSpecialChar, isTrue);
      expect(PasswordRules.check('a b').hasSpecialChar, isFalse, reason: 'khoảng trắng không tính');
    });

    test('đạt đủ 4 điều kiện thì allPassed = true', () {
      expect(PasswordRules.check('Medibook@1').allPassed, isTrue);
      expect(PasswordRules.check('medibook@1').allPassed, isFalse, reason: 'thiếu chữ hoa');
      expect(PasswordRules.check('Medibook@').allPassed, isFalse, reason: 'thiếu chữ số');
      expect(PasswordRules.check('Medibook12').allPassed, isFalse, reason: 'thiếu ký tự đặc biệt');
    });
  });

  group('Validators', () {
    test('confirmPassword báo đúng thông báo đặc tả khi không khớp', () {
      expect(Validators.confirmPassword('Abc@1234', 'Abc@12345'), AppStrings.errPasswordMismatch);
      expect(Validators.confirmPassword('Abc@1234', 'Abc@1234'), isNull);
    });

    test('newPassword chặn mật khẩu chưa đạt quy tắc', () {
      expect(Validators.newPassword('abc'), AppStrings.errPasswordRules);
      expect(Validators.newPassword('Abc@1234'), isNull);
    });

    test('fullName và phone bắt buộc nhập', () {
      expect(Validators.fullName('   '), AppStrings.errFullNameRequired);
      expect(Validators.phone(''), AppStrings.errPhoneRequired);
      expect(Validators.phone('123'), AppStrings.errPhoneInvalid);
      expect(Validators.phone('0912345678'), isNull);
    });
  });
}
