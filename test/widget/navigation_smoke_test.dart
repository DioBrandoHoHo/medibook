import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/constants/app_strings.dart';
import 'package:medibook/features/auth/domain/entities/user_role.dart';

import '../mocks/fake_repositories.dart';
import 'test_helpers.dart';

void main() {
  testWidgets('Welcome hiển thị đúng tagline và chuyển sang màn xác thực', (tester) async {
    await pumpApp(tester, FakeAuthRepository());
    expect(find.text(AppStrings.welcomeTagline, findRichText: true), findsOneWidget);

    await openAuth(tester);
    expect(find.text(AppStrings.authWelcomeBack), findsOneWidget);
    expect(fieldByLabel(AppStrings.phone), findsOneWidget);
  });

  testWidgets('Customer shell có 4 tab và chuyển tab được', (tester) async {
    // Shell của Customer giờ đọc lịch hẹn / bác sĩ nên phải mở qua app đầy đủ.
    final repo = FakeAuthRepository()
      ..seed(phone: '0912345678', password: 'Khach@123', signedIn: true);
    await pumpApp(tester, repo);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(find.text(AppStrings.tabHome), findsOneWidget);

    await tester.tap(find.text(AppStrings.tabAppointments));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.myAppointments), findsWidgets);
  });

  testWidgets('Staff shell có 4 tab và chuyển tab được', (tester) async {
    final repo = FakeAuthRepository()
      ..seed(phone: '0900000001', password: 'Staff@123', role: UserRole.staff, signedIn: true);
    await pumpApp(tester, repo);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(find.text(AppStrings.tabOverview), findsOneWidget);
    expect(find.text(AppStrings.tabAccount), findsOneWidget);

    await tester.tap(find.text(AppStrings.tabSchedule));
    await tester.pumpAndSettle();
    expect(find.text('Lịch làm việc'), findsWidgets);
  });
}
