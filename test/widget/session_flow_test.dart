import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/constants/app_strings.dart';
import 'package:medibook/core/errors/app_failure.dart';
import 'package:medibook/features/auth/domain/entities/user_role.dart';
import 'package:medibook/features/welcome/presentation/widgets/doctor_hero_image.dart';

import '../mocks/fake_repositories.dart';
import 'test_helpers.dart';

void main() {
  testWidgets('chưa có phiên -> mở app vào Welcome có ảnh bác sĩ và nút "Bắt đầu"',
      (tester) async {
    await pumpApp(tester, FakeAuthRepository());
    expect(find.text(AppStrings.welcomeTagline, findRichText: true), findsOneWidget);
    expect(find.text('Bắt đầu'), findsOneWidget);
    expect(find.byType(DoctorHeroImage), findsOneWidget);
  });

  testWidgets('Staff chưa đăng xuất -> mở app vào thẳng khu vực Staff', (tester) async {
    final repo = FakeAuthRepository()
      ..seed(phone: '0987654321', password: 'Staff@123', role: UserRole.staff, signedIn: true);
    await pumpApp(tester, repo);

    expect(find.text(AppStrings.welcomeTagline, findRichText: true), findsNothing);
    expect(find.text(AppStrings.tabStaffBookings), findsOneWidget);
  });

  testWidgets('Customer chưa đăng xuất -> vào thẳng Customer, kể cả khi hồ sơ chưa hoàn thiện',
      (tester) async {
    final repo = FakeAuthRepository()
      ..seed(phone: '0912345678', password: 'Abc@1234', signedIn: true);
    await pumpApp(tester, repo);

    expect(find.text(AppStrings.profilePromptQuestion), findsNothing);
    expect(find.text(AppStrings.tabBooking), findsOneWidget);
  });

  testWidgets('khôi phục phiên lỗi mạng -> không crash, về Welcome', (tester) async {
    final repo = FakeAuthRepository()
      ..seed(phone: '0912345678', password: 'Abc@1234', signedIn: true)
      ..nextError = const NetworkFailure();
    await pumpApp(tester, repo);
    expect(find.text(AppStrings.welcomeTagline, findRichText: true), findsOneWidget);
  });

  testWidgets('"Để sau" được lưu: lần đăng nhập sau vào thẳng Trang chủ, không hỏi lại',
      (tester) async {
    final repo = FakeAuthRepository()..seed(phone: '0912345678', password: 'Abc@1234');
    await pumpApp(tester, repo);

    await loginFromWelcome(tester, '0912345678', 'Abc@1234');
    expect(find.text(AppStrings.profilePromptQuestion), findsOneWidget);
    await tester.tap(find.text(AppStrings.later));
    await tester.pumpAndSettle();
    expect(repo.storedUser('0912345678')!.profilePromptDismissed, isTrue);

    // Mô phỏng: đăng xuất rồi mở lại app và đăng nhập lần nữa.
    await repo.logout();
    await pumpApp(tester, repo);
    await loginFromWelcome(tester, '0912345678', 'Abc@1234');

    expect(find.text(AppStrings.profilePromptQuestion), findsNothing);
    expect(find.text(AppStrings.tabBooking), findsOneWidget);
  });
}
