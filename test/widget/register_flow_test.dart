import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/constants/app_strings.dart';

import '../mocks/fake_repositories.dart';
import 'test_helpers.dart';

void main() {
  testWidgets('checklist mật khẩu cập nhật trạng thái khi gõ', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(tester, FakeAuthRepository());
    await openAuth(tester);
    await switchToRegister(tester);

    await tester.enterText(passwordInput('register-password'), 'abc');
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('${AppStrings.ruleMinLength}: chưa đạt'), findsOneWidget);
    expect(find.bySemanticsLabel('${AppStrings.ruleUppercase}: chưa đạt'), findsOneWidget);

    await tester.enterText(passwordInput('register-password'), 'Abcdefg@1');
    await tester.pumpAndSettle();
    for (final rule in [
      AppStrings.ruleMinLength,
      AppStrings.ruleUppercase,
      AppStrings.ruleDigit,
      AppStrings.ruleSpecial,
    ]) {
      expect(find.bySemanticsLabel('$rule: đã đạt'), findsOneWidget, reason: rule);
    }
    semantics.dispose();
  });

  testWidgets('"Mật khẩu xác nhận không khớp" hiện khi lệch và biến mất khi khớp', (tester) async {
    await pumpApp(tester, FakeAuthRepository());
    await openAuth(tester);
    await switchToRegister(tester);

    await tester.enterText(passwordInput('register-password'), 'Abc@1234');
    await tester.enterText(passwordInput('register-confirm'), 'Abc@123');
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.errPasswordMismatch), findsOneWidget);

    await tester.enterText(passwordInput('register-confirm'), 'Abc@1234');
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.errPasswordMismatch), findsNothing);

    // Sửa ô mật khẩu chính -> lỗi ở ô xác nhận cũng phải cập nhật lại.
    await tester.enterText(passwordInput('register-password'), 'Abc@12345');
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.errPasswordMismatch), findsOneWidget);
  });

  testWidgets('nút con mắt của 2 ô mật khẩu hoạt động độc lập', (tester) async {
    await pumpApp(tester, FakeAuthRepository());
    await openAuth(tester);
    await switchToRegister(tester);

    bool obscured(String key) => tester.widget<TextField>(passwordInput(key)).obscureText;
    expect(obscured('register-password'), isTrue);
    expect(obscured('register-confirm'), isTrue);

    final eye = find.descendant(
      of: find.byKey(const ValueKey('register-password')),
      matching: find.byType(IconButton),
    );
    await tester.ensureVisible(eye);
    await tester.tap(eye);
    await tester.pumpAndSettle();

    expect(obscured('register-password'), isFalse);
    expect(obscured('register-confirm'), isTrue);
  });

  testWidgets('đăng ký SĐT đã tồn tại hiển thị lỗi ngay dưới ô SĐT', (tester) async {
    final repo = FakeAuthRepository()..seed(phone: '0912345678', password: 'Abc@1234');
    await pumpApp(tester, repo);
    await openAuth(tester);
    await switchToRegister(tester);

    await tester.enterText(fieldByLabel(AppStrings.fullName), 'Nguyễn An');
    await tester.enterText(fieldByLabel(AppStrings.phone), '0912 345 678');
    await tester.enterText(passwordInput('register-password'), 'Abc@1234');
    await tester.enterText(passwordInput('register-confirm'), 'Abc@1234');
    await tapButton(tester, AppStrings.register);

    expect(find.text(AppStrings.errPhoneExists), findsOneWidget);
    expect(find.text(AppStrings.profilePromptQuestion), findsNothing);
  });

  testWidgets('luồng đầy đủ: đăng ký -> hỏi hồ sơ -> Để sau -> Customer, hồ sơ tự điền',
      (tester) async {
    await pumpApp(tester, FakeAuthRepository());
    await openAuth(tester);
    await switchToRegister(tester);

    await tester.enterText(fieldByLabel(AppStrings.fullName), 'Nguyễn An');
    await tester.enterText(fieldByLabel(AppStrings.phone), '+84912345678');
    await tester.enterText(passwordInput('register-password'), 'Abc@1234');
    await tester.enterText(passwordInput('register-confirm'), 'Abc@1234');
    await tapButton(tester, AppStrings.register);

    expect(find.text(AppStrings.profilePromptQuestion), findsOneWidget);
    await tester.tap(find.text(AppStrings.later));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.tabBooking), findsOneWidget); // đang ở CustomerShell
    await tester.tap(find.text(AppStrings.tabProfile));
    await tester.pumpAndSettle();
    // Tab Cá nhân hiện họ tên / SĐT ở cả thẻ tài khoản lẫn thẻ Thông tin cá nhân.
    String textOf(String key) => tester.widget<Text>(find.byKey(ValueKey(key))).data!;
    expect(textOf('account_name'), 'Nguyễn An');
    expect(textOf('info_full_name'), 'Nguyễn An');
    expect(textOf('account_phone'), '0912345678');
    expect(textOf('info_phone'), '0912345678');
    expect(textOf('account_role'), AppStrings.roleCustomer);
  });
}
