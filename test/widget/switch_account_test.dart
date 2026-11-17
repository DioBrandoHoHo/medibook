import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/constants/app_strings.dart';
import 'package:medibook/features/auth/domain/entities/user_role.dart';

import '../mocks/fake_clinic_repositories.dart';
import '../mocks/fake_repositories.dart';
import 'test_helpers.dart';

/// Hai tài khoản giống tài khoản thử trên Firebase.
FakeAuthRepository _repo({bool customerSignedIn = false}) => FakeAuthRepository()
  ..seed(
    phone: '0901234567',
    password: 'Staff@123',
    fullName: 'Trần Thu Trang',
    role: UserRole.staff,
    profilePromptDismissed: true,
  )
  ..seed(
    phone: '0912345678',
    password: 'Khach@123',
    fullName: 'Nguyễn Văn Bình',
    profilePromptDismissed: true,
    signedIn: customerSignedIn,
  );

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
  await tester.pumpAndSettle();
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key), skipOffstage: false));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('khách hàng đăng xuất ở tab Cá nhân (có hỏi lại) rồi đăng nhập bằng tài khoản nhân viên',
      (tester) async {
    final auth = _repo(customerSignedIn: true);
    await pumpApp(tester, auth, appointmentRepo: FakeAppointmentRepository());

    // Đang ở khu vực khách hàng.
    expect(find.text(AppStrings.tabProfile), findsOneWidget);
    await _openTab(tester, AppStrings.tabProfile);
    expect(tester.widget<Text>(find.byKey(const ValueKey('account_name'))).data, 'Nguyễn Văn Bình');

    await _tapKey(tester, 'logout_button');
    expect(find.text(AppStrings.logoutConfirm), findsOneWidget);
    await _tapKey(tester, 'logout_cancel');
    expect(auth.logoutCalls, 0);

    await _tapKey(tester, 'logout_button');
    await _tapKey(tester, 'logout_agree');
    expect(auth.logoutCalls, 1);
    expect(find.widgetWithText(FilledButton, AppStrings.login), findsOneWidget);

    // Đăng nhập nhân viên -> vào khu vực Staff.
    await tester.enterText(fieldByLabel(AppStrings.phone), '0901234567');
    await tester.enterText(fieldByLabel(AppStrings.password), 'Staff@123');
    await tapButton(tester, AppStrings.login);
    expect(find.text(AppStrings.tabOverview), findsOneWidget);
    expect(find.text(AppStrings.tabSchedule), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('greeting_name'))).data,
      'Trần Thu Trang',
    );
  });

  testWidgets('nhân viên đăng xuất rồi đăng nhập bằng tài khoản khách hàng', (tester) async {
    final auth = _repo();
    await pumpApp(tester, auth, appointmentRepo: FakeAppointmentRepository());
    await loginFromWelcome(tester, '0901234567', 'Staff@123');
    expect(find.text(AppStrings.tabOverview), findsOneWidget);

    await _openTab(tester, AppStrings.tabAccount);
    await _tapKey(tester, 'logout_button');
    await _tapKey(tester, 'logout_agree');

    await tester.enterText(fieldByLabel(AppStrings.phone), '0912345678');
    await tester.enterText(fieldByLabel(AppStrings.password), 'Khach@123');
    await tapButton(tester, AppStrings.login);
    // Khu vực khách hàng: không có các tab của nhân viên.
    expect(find.text(AppStrings.tabProfile), findsOneWidget);
    expect(find.text(AppStrings.tabOverview), findsNothing);
    expect(find.text(AppStrings.tabSchedule), findsNothing);
  });
}
