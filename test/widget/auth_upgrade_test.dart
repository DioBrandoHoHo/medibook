import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/constants/app_strings.dart';
import 'package:medibook/core/utils/name_utils.dart';
import 'package:medibook/core/utils/validators.dart';

import '../mocks/fake_repositories.dart';
import 'test_helpers.dart';

/// Nâng cấp Đăng ký / Đăng nhập (dang_ky_dang_nhap.txt – Phần bổ sung C, Lượt 22).
void main() {
  group('Kiểm tra họ tên (Đăng ký + Cập nhật thông tin)', () {
    test('hợp lệ: tiếng Việt có dấu, nhiều từ, có dấu nháy / gạch nối / chấm', () {
      for (final name in [
        'Nguyễn Văn Bình',
        'Lê Thị Ánh Tuyết',
        "O'Neil",
        'Trần-Lê Minh',
        'Ng. Văn A',
        'An',
        '  nguyễn   văn   bình  ',
      ]) {
        expect(Validators.fullName(name), isNull, reason: name);
      }
    });

    test('không hợp lệ: rỗng, 1 ký tự, quá 50 ký tự, có số / ký hiệu, toàn dấu câu', () {
      expect(Validators.fullName(''), AppStrings.errFullNameRequired);
      expect(Validators.fullName('   '), AppStrings.errFullNameRequired);
      expect(Validators.fullName('A'), AppStrings.errFullNameLength);
      expect(Validators.fullName('A' * 51), AppStrings.errFullNameLength);
      expect(Validators.fullName('Nguyễn Văn 2'), AppStrings.errFullNameChars);
      expect(Validators.fullName('123'), AppStrings.errFullNameChars);
      expect(Validators.fullName('Bình @@'), AppStrings.errFullNameChars);
      expect(Validators.fullName("'.-"), AppStrings.errFullNameChars);
    });

    test('NameUtils.normalize bỏ khoảng trắng thừa', () {
      expect(NameUtils.normalize('  nguyễn   văn \t bình  '), 'nguyễn văn bình');
      expect(NameUtils.normalize('An'), 'An');
    });
  });

  testWidgets('đăng ký: họ tên có số bị chặn; họ tên thừa khoảng trắng được lưu gọn',
      (tester) async {
    final repo = FakeAuthRepository();
    await pumpApp(tester, repo);
    await openAuth(tester);
    await switchToRegister(tester);

    await tester.enterText(fieldByLabel(AppStrings.fullName), 'Nguyễn An 99');
    await tester.enterText(fieldByLabel(AppStrings.phone), '0912345678');
    await tester.enterText(passwordInput('register-password'), 'Abc@1234');
    await tester.enterText(passwordInput('register-confirm'), 'Abc@1234');
    await tapButton(tester, AppStrings.register);
    expect(find.text(AppStrings.errFullNameChars), findsOneWidget);
    expect(find.text(AppStrings.profilePromptQuestion), findsNothing);

    await tester.enterText(fieldByLabel(AppStrings.fullName), '  Nguyễn    An ');
    await tapButton(tester, AppStrings.register);
    expect(find.text(AppStrings.profilePromptQuestion), findsOneWidget);
    expect(repo.storedUser('0912345678')!.fullName, 'Nguyễn An');
  });

  testWidgets('chuyển Đăng nhập <-> Đăng ký giữ số điện thoại đang gõ (không giữ mật khẩu)',
      (tester) async {
    await pumpApp(tester, FakeAuthRepository());
    await openAuth(tester);
    await tester.enterText(fieldByLabel(AppStrings.phone), '0987 654 321');
    await tester.enterText(fieldByLabel(AppStrings.password), 'Abc@1234');
    await switchToRegister(tester);

    String phoneText() =>
        tester.widget<TextFormField>(fieldByLabel(AppStrings.phone)).controller!.text;
    expect(phoneText(), '0987 654 321');
    expect(
      tester.widget<TextField>(passwordInput('register-password')).controller!.text,
      isEmpty,
    );

    await tester.enterText(fieldByLabel(AppStrings.phone), '0911111111');
    await tester.tap(find.text(AppStrings.login).first);
    await tester.pumpAndSettle();
    expect(phoneText(), '0911111111');
  });

  testWidgets('đăng ký số đã có tài khoản -> "Đăng nhập bằng số này" -> sang Đăng nhập, số điền sẵn',
      (tester) async {
    final repo = FakeAuthRepository()
      ..seed(phone: '0912345678', password: 'Abc@1234', fullName: 'Nguyễn An');
    await pumpApp(tester, repo);
    await openAuth(tester);
    await switchToRegister(tester);
    expect(find.byKey(const ValueKey('goto_login')), findsNothing);

    await tester.enterText(fieldByLabel(AppStrings.fullName), 'Nguyễn An');
    await tester.enterText(fieldByLabel(AppStrings.phone), '0912345678');
    await tester.enterText(passwordInput('register-password'), 'Abc@1234');
    await tester.enterText(passwordInput('register-confirm'), 'Abc@1234');
    await tapButton(tester, AppStrings.register);
    expect(find.text(AppStrings.errPhoneExists), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('goto_login')));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.forgotPassword), findsOneWidget); // đang ở form Đăng nhập
    expect(tester.widget<TextFormField>(fieldByLabel(AppStrings.phone)).controller!.text,
        '0912345678');
    expect(find.text(AppStrings.errPhoneExists), findsNothing); // lỗi cũ đã xoá

    await tester.enterText(fieldByLabel(AppStrings.password), 'Abc@1234');
    await tapButton(tester, AppStrings.login);
    expect(find.text(AppStrings.profilePromptQuestion), findsOneWidget);
  });

  testWidgets('đăng nhập số chưa đăng ký -> "Tạo tài khoản với số này" -> sang Đăng ký, số điền sẵn',
      (tester) async {
    await pumpApp(tester, FakeAuthRepository());
    await openAuth(tester);
    await tester.enterText(fieldByLabel(AppStrings.phone), '0900000009');
    await tester.enterText(fieldByLabel(AppStrings.password), 'Abc@1234');
    await tapButton(tester, AppStrings.login);
    expect(find.text(AppStrings.errPhoneNotRegistered), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('goto_register')));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.confirmPassword), findsOneWidget); // đang ở form Đăng ký
    expect(tester.widget<TextFormField>(fieldByLabel(AppStrings.phone)).controller!.text,
        '0900000009');
    expect(find.text(AppStrings.errPhoneNotRegistered), findsNothing);
  });

  testWidgets('sai mật khẩu -> không hiện lối tắt (không tiết lộ thêm gì)', (tester) async {
    final repo = FakeAuthRepository()..seed(phone: '0912345678', password: 'Abc@1234');
    await pumpApp(tester, repo);
    await openAuth(tester);
    await tester.enterText(fieldByLabel(AppStrings.phone), '0912345678');
    await tester.enterText(fieldByLabel(AppStrings.password), 'Sai@1234');
    await tapButton(tester, AppStrings.login);
    expect(find.text(AppStrings.errWrongCredentials), findsOneWidget);
    expect(find.byKey(const ValueKey('goto_register')), findsNothing);
    expect(find.byKey(const ValueKey('goto_login')), findsNothing);
  });

  testWidgets('Cập nhật thông tin dùng cùng quy tắc họ tên', (tester) async {
    final repo = FakeAuthRepository()
      ..seed(phone: '0912345678', password: 'Abc@1234', fullName: 'Nguyễn An', signedIn: true,
          profilePromptDismissed: true);
    final profile = FakeProfileRepository(repo);
    await pumpApp(tester, repo, profileRepo: profile);
    await tester.tap(find.text(AppStrings.tabProfile));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit_profile')));
    await tester.pumpAndSettle();
    await tester.enterText(fieldByLabel(AppStrings.fullName), 'X');
    await tapButton(tester, AppStrings.save);
    expect(find.text(AppStrings.errFullNameLength), findsOneWidget);
    expect(profile.savedNames, isEmpty);

    await tester.enterText(fieldByLabel(AppStrings.fullName), ' Nguyễn   Bình  An ');
    await tapButton(tester, AppStrings.save);
    expect(profile.savedNames, ['Nguyễn Bình An']);
  });
}
