import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/utils/phone_utils.dart';

void main() {
  group('PhoneUtils.normalize', () {
    test('bỏ khoảng trắng, dấu chấm, gạch ngang', () {
      expect(PhoneUtils.normalize(' 0912.345-678 '), '0912345678');
      expect(PhoneUtils.normalize('0912 345 678'), '0912345678');
    });

    test('đổi +84 và 84 thành 0', () {
      expect(PhoneUtils.normalize('+84912345678'), '0912345678');
      expect(PhoneUtils.normalize('84912345678'), '0912345678');
    });
  });

  group('PhoneUtils.isValid', () {
    test('chấp nhận số di động VN hợp lệ ở nhiều dạng nhập', () {
      for (final s in ['0912345678', '0386 123 456', '+84 701234567', '0559999999']) {
        expect(PhoneUtils.isValid(s), isTrue, reason: s);
      }
    });

    test('từ chối số sai độ dài, sai đầu số hoặc có chữ', () {
      for (final s in ['', '091234567', '09123456789', '0212345678', '09123abc78', '1912345678']) {
        expect(PhoneUtils.isValid(s), isFalse, reason: s);
      }
    });
  });

  test('toAuthEmail quy đổi về cùng một email cho mọi cách nhập', () {
    expect(PhoneUtils.toAuthEmail('+84 912 345 678'), '0912345678@medibook.local');
    expect(PhoneUtils.toAuthEmail('0912345678'), PhoneUtils.toAuthEmail('84912345678'));
  });
}
