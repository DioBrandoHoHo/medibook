import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/constants/app_strings.dart';
import 'package:medibook/features/appointments/domain/entities/appointment.dart';
import 'package:medibook/features/appointments/domain/entities/appointment_status.dart';
import 'package:medibook/features/auth/domain/entities/user_role.dart';
import 'package:medibook/features/notifications/domain/appointment_alerts.dart';
import 'package:medibook/features/profile/presentation/screens/staff_account_screen.dart';

import '../mocks/fake_alerts.dart';
import '../mocks/fake_clinic_repositories.dart';
import '../mocks/fake_repositories.dart';
import 'test_helpers.dart';

/// "Bây giờ" = 18/11/2026 10:00.
final _now = DateTime(2026, 11, 18, 10);

/// Khách hàng đã đăng nhập (uid 'u0' – id đầu tiên của FakeAuthRepository).
FakeAuthRepository _customer() => FakeAuthRepository()
  ..seed(
    phone: '0912345678',
    password: 'Khach@123',
    fullName: 'Nguyễn Văn Bình',
    signedIn: true,
    profilePromptDismissed: true,
  );

Appointment _mine(String id, DateTime start, {AppointmentStatus status = AppointmentStatus.pending}) =>
    appt(id, start, status: status, customerId: 'u0', doctorId: 'd1', name: 'Nguyễn Văn Bình');

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester, {
  required FakeAuthRepository auth,
  required FakeAppointmentRepository appointments,
  required FakeLocalNotifications notifications,
  MemoryAlertStore? store,
}) async {
  await pumpApp(
    tester,
    auth,
    appointmentRepo: appointments,
    clock: () => _now,
    localNotifications: notifications,
    alertStore: store ?? MemoryAlertStore(),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('nhân viên xác nhận -> điện thoại khách hiện thông báo; bấm -> mở Chi tiết lịch đó',
      (tester) async {
    final repo = FakeAppointmentRepository(initial: [_mine('p1', DateTime(2026, 11, 20, 9))]);
    final notifications = FakeLocalNotifications();
    await _pump(tester, auth: _customer(), appointments: repo, notifications: notifications);
    expect(notifications.permissionRequests, 1); // hỏi quyền khi vào khu vực Khách hàng
    expect(notifications.shown, isEmpty);

    await repo.updateStatus('p1', AppointmentStatus.confirmed); // nhân viên xác nhận
    await tester.pumpAndSettle();
    expect(notifications.shown.single.title, AppStrings.alertConfirmedTitle);
    expect(notifications.scheduled, hasLength(2)); // nhắc 1 ngày + 1 giờ trước

    notifications.tap(notifications.shown.single.payload);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.appointmentDetail), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    // Đang ở tab Lịch hẹn.
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 2);
  });

  testWidgets('mở app từ một thông báo (app đang tắt) -> vào thẳng Chi tiết lịch', (tester) async {
    final repo = FakeAppointmentRepository(initial: [
      _mine('c1', DateTime(2026, 11, 20, 9), status: AppointmentStatus.confirmed),
    ]);
    final notifications = FakeLocalNotifications(launchPayload: payloadFor('c1'));
    await _pump(tester, auth: _customer(), appointments: repo, notifications: notifications);
    expect(find.text(AppStrings.appointmentDetail), findsOneWidget);
  });

  testWidgets('tab Cá nhân: công tắc thông báo, số lời nhắc; tắt -> huỷ nhắc; bật lại -> hẹn lại',
      (tester) async {
    final repo = FakeAppointmentRepository(initial: [
      _mine('c1', DateTime(2026, 11, 20, 9), status: AppointmentStatus.confirmed),
    ]);
    final notifications = FakeLocalNotifications();
    final store = MemoryAlertStore();
    await _pump(tester,
        auth: _customer(), appointments: repo, notifications: notifications, store: store);
    await _openTab(tester, AppStrings.tabProfile);

    final card = find.byKey(const ValueKey('alerts_card'));
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(find.byKey(const ValueKey('alerts_switch'))).value, isTrue);
    expect(tester.widget<Text>(find.byKey(const ValueKey('alerts_subtitle'))).data,
        contains(AppStrings.alertsUpcoming(2)));

    await tester.tap(find.byKey(const ValueKey('alerts_switch')));
    await tester.pumpAndSettle();
    expect(notifications.scheduled, isEmpty);
    expect(store.enabled['u0'], isFalse);

    await tester.tap(find.byKey(const ValueKey('alerts_switch')));
    await tester.pumpAndSettle();
    expect(notifications.scheduled, hasLength(2));
  });

  testWidgets('không cho phép thông báo trong Cài đặt -> hiện hướng dẫn bật lại', (tester) async {
    final notifications = FakeLocalNotifications(granted: false);
    await _pump(tester,
        auth: _customer(), appointments: FakeAppointmentRepository(), notifications: notifications);
    await _openTab(tester, AppStrings.tabProfile);
    await tester.ensureVisible(find.byKey(const ValueKey('alerts_card')));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.alertsBlocked), findsOneWidget);
  });

  testWidgets('đăng xuất -> huỷ lời nhắc của khách đó', (tester) async {
    final repo = FakeAppointmentRepository(initial: [
      _mine('c1', DateTime(2026, 11, 20, 9), status: AppointmentStatus.confirmed),
    ]);
    final notifications = FakeLocalNotifications();
    await _pump(tester, auth: _customer(), appointments: repo, notifications: notifications);
    expect(notifications.scheduled, hasLength(2));

    await _openTab(tester, AppStrings.tabProfile);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('logout_button')),
      300,
      scrollable: find.descendant(of: find.byType(AccountView), matching: find.byType(Scrollable)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('logout_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('logout_agree')));
    await tester.pumpAndSettle();
    expect(notifications.scheduled, isEmpty);
  });

  testWidgets('nhân viên đăng nhập -> không hỏi quyền, không hẹn nhắc (chức năng chỉ cho khách)',
      (tester) async {
    final staff = FakeAuthRepository()
      ..seed(
        phone: '0901234567',
        password: 'Staff@123',
        fullName: 'Trần Thu Trang',
        role: UserRole.staff,
        signedIn: true,
        profilePromptDismissed: true,
      );
    final notifications = FakeLocalNotifications();
    await _pump(tester,
        auth: staff,
        appointments: FakeAppointmentRepository(initial: [
          appt('x', DateTime(2026, 11, 20, 9), status: AppointmentStatus.confirmed),
        ]),
        notifications: notifications);
    expect(notifications.permissionRequests, 0);
    expect(notifications.scheduled, isEmpty);
  });
}
