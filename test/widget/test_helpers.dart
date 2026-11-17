import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/app/app.dart';
import 'package:medibook/core/constants/app_strings.dart';

import '../mocks/fake_clinic_repositories.dart';
import '../mocks/fake_repositories.dart';

/// Giả lập màn hình điện thoại dọc 360x780.
void usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Mở app (qua màn khởi động) với repository giả lập.
Future<void> pumpApp(
  WidgetTester tester,
  FakeAuthRepository repo, {
  FakeProfileRepository? profileRepo,
  FakeAppointmentRepository? appointmentRepo,
  FakeNotificationRepository? notificationRepo,
  FakeDoctorRepository? doctorRepo,
  DateTime Function()? clock,
}) async {
  usePhoneScreen(tester);
  await tester.pumpWidget(
    MediBookApp(
      key: UniqueKey(), // mỗi lần gọi = một lần mở app mới
      authRepository: repo,
      profileRepository: profileRepo ?? FakeProfileRepository(repo),
      appointmentRepository: appointmentRepo ?? FakeAppointmentRepository(),
      notificationRepository: notificationRepo ?? FakeNotificationRepository(),
      doctorRepository: doctorRepo ?? FakeDoctorRepository(),
      clock: clock,
    ),
  );
  await tester.pumpAndSettle();
}

/// Từ Welcome bấm "Bắt đầu" để tới màn xác thực.
Future<void> openAuth(WidgetTester tester) async {
  await tester.tap(find.text(AppStrings.startBooking));
  await tester.pumpAndSettle();
}

Future<void> switchToRegister(WidgetTester tester) async {
  await tester.tap(find.text(AppStrings.register).first);
  await tester.pumpAndSettle();
}

Finder fieldByLabel(String label) => find.widgetWithText(TextFormField, label);

Finder passwordInput(String key) =>
    find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(TextField));

Future<void> tapButton(WidgetTester tester, String label) async {
  final btn = find.widgetWithText(FilledButton, label);
  await tester.ensureVisible(btn);
  await tester.tap(btn);
  await tester.pumpAndSettle();
}

/// Đăng nhập từ màn Welcome.
Future<void> loginFromWelcome(WidgetTester tester, String phone, String password) async {
  await openAuth(tester);
  await tester.enterText(fieldByLabel(AppStrings.phone), phone);
  await tester.enterText(fieldByLabel(AppStrings.password), password);
  await tapButton(tester, AppStrings.login);
}
