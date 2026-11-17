import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/constants/app_strings.dart';
import 'package:medibook/features/auth/domain/entities/user_role.dart';

import '../mocks/fake_repositories.dart';
import 'test_helpers.dart';

void main() {
  testWidgets('bỏ trống/sai định dạng -> báo lỗi tại chỗ, không gửi yêu cầu', (tester) async {
    await pumpApp(tester, FakeAuthRepository());
    await openAuth(tester);

    await tapButton(tester, AppStrings.login);
    expect(find.text(AppStrings.errPhoneRequired), findsOneWidget);
    expect(find.text(AppStrings.errPasswordRequired), findsOneWidget);

    await tester.enterText(fieldByLabel(AppStrings.phone), '12345');
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.errPhoneInvalid), findsOneWidget);
  });

  testWidgets('sai mật khẩu hiển thị đúng thông báo đặc tả', (tester) async {
    final repo = FakeAuthRepository()..seed(phone: '0912345678', password: 'Abc@1234');
    await pumpApp(tester, repo);
    await openAuth(tester);

    await tester.enterText(fieldByLabel(AppStrings.phone), '0912345678');
    await tester.enterText(fieldByLabel(AppStrings.password), 'Sai@0000');
    await tapButton(tester, AppStrings.login);

    expect(find.text(AppStrings.errWrongCredentials), findsOneWidget);
  });

  testWidgets('Staff đã hoàn thiện hồ sơ đăng nhập -> vào thẳng khu vực Staff', (tester) async {
    final repo = FakeAuthRepository()
      ..seed(
        phone: '0987654321',
        password: 'Staff@123',
        fullName: 'Lễ tân',
        role: UserRole.staff,
        profileCompleted: true,
      );
    await pumpApp(tester, repo);
    await openAuth(tester);

    await tester.enterText(fieldByLabel(AppStrings.phone), '0987654321');
    await tester.enterText(fieldByLabel(AppStrings.password), 'Staff@123');
    await tapButton(tester, AppStrings.login);

    expect(find.text(AppStrings.profilePromptQuestion), findsNothing);
    expect(find.text(AppStrings.tabStaffBookings), findsOneWidget);
    expect(find.text(AppStrings.tabSchedule), findsOneWidget);
  });
}
