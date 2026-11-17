import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/constants/app_strings.dart';
import 'package:medibook/core/errors/app_failure.dart';
import 'package:medibook/features/appointments/domain/entities/appointment.dart';
import 'package:medibook/features/appointments/domain/entities/appointment_status.dart';
import 'package:medibook/features/auth/domain/entities/user_role.dart';
import 'package:medibook/features/booking/domain/entities/doctor.dart';

import '../mocks/fake_clinic_repositories.dart';
import '../mocks/fake_repositories.dart';
import 'test_helpers.dart';

// Kiểm thử tab Lịch hẹn của Khách hàng + hủy lịch (lich_hen.txt).

/// "Bây giờ" = Thứ Bảy 14/11/2026 10:00.
final _now = DateTime(2026, 11, 14, 10);
DateTime _today(int h, [int m = 0]) => DateTime(2026, 11, 14, h, m);
DateTime _tomorrow(int h, [int m = 0]) => DateTime(2026, 11, 15, h, m);

const _phone = '0912345678';
const _me = 'u0'; // tài khoản đầu tiên trong FakeAuthRepository

const _doctors = [
  Doctor(id: 'd1', name: 'BS. Nguyễn Văn An', specialty: 'Nội tổng quát', room: 'Phòng 101', fee: 150000),
  Doctor(id: 'd2', name: 'BS. Trần Thị Bình', specialty: 'Da liễu', room: 'Phòng 102'),
];

/// Khách hàng (u0) đã đăng nhập sẵn + một tài khoản nhân viên để kiểm tra phía Staff.
FakeAuthRepository _auth() => FakeAuthRepository()
  ..seed(
    phone: _phone,
    password: 'Khach@123',
    fullName: 'Nguyễn Văn Bình',
    signedIn: true,
    profilePromptDismissed: true,
  )
  ..seed(
    phone: '0900000001',
    password: 'Staff@123',
    fullName: 'Trần Thu Trang',
    role: UserRole.staff,
    profilePromptDismissed: true,
  );

Appointment _mine(String id, DateTime start,
        {AppointmentStatus status = AppointmentStatus.pending, String doctorId = 'd1'}) =>
    appt(id, start,
        status: status,
        doctorId: doctorId,
        customerId: _me,
        name: 'Nguyễn Văn Bình',
        service: 'Khám nội tổng quát');

List<Appointment> _sample() => [
      _mine('pend', _today(14)), // chờ xác nhận, hôm nay
      _mine('conf', _tomorrow(9), status: AppointmentStatus.confirmed, doctorId: 'd2'),
      _mine('soon', _today(11), status: AppointmentStatus.confirmed, doctorId: 'd2'), // còn 1 giờ
      _mine('old', _today(8), status: AppointmentStatus.confirmed),
      _mine('rej', _today(16), status: AppointmentStatus.rejected),
      appt('other', _today(15), doctorId: 'd1', customerId: 'someone', name: 'Người Khác'),
    ];

Future<(FakeAppointmentRepository, FakeNotificationRepository, FakeAuthRepository)> _pump(
  WidgetTester tester, {
  List<Appointment>? initial,
  FakeAppointmentRepository? repo,
}) async {
  final notifications = FakeNotificationRepository();
  final appointments =
      repo ?? FakeAppointmentRepository(initial: initial ?? _sample(), notifications: notifications);
  final auth = _auth();
  await pumpApp(
    tester,
    auth,
    appointmentRepo: appointments,
    notificationRepo: notifications,
    doctorRepo: FakeDoctorRepository(initial: _doctors),
    clock: () => _now,
  );
  await _openTab(tester, AppStrings.tabAppointments);
  return (appointments, notifications, auth);
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
  await tester.pumpAndSettle();
}

String _textOf(WidgetTester tester, String key) {
  final onstage = find.byKey(ValueKey(key));
  final finder =
      onstage.evaluate().isNotEmpty ? onstage : find.byKey(ValueKey(key), skipOffstage: false);
  return tester.widget<Text>(finder.first).data!;
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key), skipOffstage: false).first);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey(key)).first);
  await tester.pumpAndSettle();
}

Finder _card(String id) => find.byKey(ValueKey('cappt_$id'));

void main() {
  testWidgets('chỉ hiện lịch của chính khách, chia 3 nhóm kèm số lượng; đổi nhóm', (tester) async {
    await _pump(tester);

    expect(_textOf(tester, 'cfilter_count_upcoming'), '3');
    expect(_textOf(tester, 'cfilter_count_past'), '1');
    expect(_textOf(tester, 'cfilter_count_cancelled'), '1');
    // Sắp tới (mặc định): gần nhất trên cùng; không có lịch của người khác.
    expect(_card('soon'), findsOneWidget);
    expect(_card('pend'), findsOneWidget);
    expect(_card('conf'), findsOneWidget);
    expect(_card('other'), findsNothing);
    expect(tester.getTopLeft(_card('soon')).dy, lessThan(tester.getTopLeft(_card('pend')).dy));
    expect(tester.getTopLeft(_card('pend')).dy, lessThan(tester.getTopLeft(_card('conf')).dy));

    await _tapKey(tester, 'cfilter_past');
    expect(_card('old'), findsOneWidget);
    expect(_card('pend'), findsNothing);

    await _tapKey(tester, 'cfilter_cancelled');
    expect(_card('rej'), findsOneWidget);
    expect(find.descendant(of: _card('rej'), matching: find.text(AppStrings.statusRejected)),
        findsOneWidget);
  });

  testWidgets('nút Hủy chỉ có ở lịch còn hủy được; lịch đã xác nhận còn dưới 2 giờ hiện lý do',
      (tester) async {
    await _pump(tester);

    expect(find.byKey(const ValueKey('cancel_pend')), findsOneWidget); // chờ xác nhận
    expect(find.byKey(const ValueKey('cancel_conf')), findsOneWidget); // xác nhận, còn 23 giờ
    expect(find.byKey(const ValueKey('cancel_soon')), findsNothing); // xác nhận, còn 1 giờ
    expect(_textOf(tester, 'cancel_blocked_soon'), AppStrings.errCancelTooLate);

    await _tapKey(tester, 'cfilter_past');
    expect(find.byKey(const ValueKey('cancel_old')), findsNothing);
  });

  testWidgets('hủy lịch: có hỏi lại; "Không" thì giữ nguyên; đồng ý thì sang nhóm Đã hủy '
      'và Trang chủ, tab Cá nhân, chấm số, số ca trống cùng đổi', (tester) async {
    final (repo, _, _) = await _pump(tester);
    expect(_textOf(tester, 'tab_upcoming_badge'), '3');

    await _tapKey(tester, 'cancel_pend');
    expect(find.text(AppStrings.cancelDialogTitle), findsOneWidget);
    await _tapKey(tester, 'cancel_keep');
    expect(repo.items.firstWhere((a) => a.id == 'pend').status, AppointmentStatus.pending);

    await _tapKey(tester, 'cancel_pend');
    await _tapKey(tester, 'cancel_agree');
    expect(find.text(AppStrings.cancelledDone), findsOneWidget);
    expect(repo.items.firstWhere((a) => a.id == 'pend').status, AppointmentStatus.cancelled);

    // Tab Lịch hẹn.
    expect(_card('pend'), findsNothing);
    expect(_textOf(tester, 'cfilter_count_upcoming'), '2');
    expect(_textOf(tester, 'cfilter_count_cancelled'), '2');
    expect(_textOf(tester, 'tab_upcoming_badge'), '2');
    await _tapKey(tester, 'cfilter_cancelled');
    expect(_card('pend'), findsOneWidget);

    // Trang chủ + Cá nhân.
    await _openTab(tester, AppStrings.tabHome);
    expect(_textOf(tester, 'cstat_upcoming'), '2');
    expect(_textOf(tester, 'cstat_pending'), '0');
    await _openTab(tester, AppStrings.tabProfile);
    expect(_textOf(tester, 'pstat_upcoming'), '2');

    // Khung 14:00 của d1 trống trở lại: d1 còn 10:30, 11:00 + 8 khung chiều − 15:00 (người khác) = 9.
    await _openTab(tester, AppStrings.tabBooking);
    expect(_textOf(tester, 'doctor_free_d1'), AppStrings.freeSlots(9));
  });

  testWidgets('khách hủy -> nhân viên nhận thông báo, Lịch đặt thấy Đã hủy, số cần xử lý giảm',
      (tester) async {
    final (repo, notifications, _) = await _pump(tester);
    await _tapKey(tester, 'cancel_pend');
    await _tapKey(tester, 'cancel_agree');

    final n = notifications.items.single;
    expect(n.title, AppStrings.notifCancelledTitle);
    expect(n.body, 'Nguyễn Văn Bình đã hủy lịch Khám nội tổng quát lúc 14:00 ngày 14/11/2026.');
    expect(n.appointmentId, 'pend');
    // Chờ thông báo "Đã hủy lịch hẹn" tự ẩn (nó đang che nút Đăng xuất phía dưới).
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // Đăng xuất, đăng nhập nhân viên.
    await _openTab(tester, AppStrings.tabProfile);
    await _tapKey(tester, 'logout_button');
    await _tapKey(tester, 'logout_agree');
    await tester.enterText(fieldByLabel(AppStrings.phone), '0900000001');
    await tester.enterText(fieldByLabel(AppStrings.password), 'Staff@123');
    await tapButton(tester, AppStrings.login);

    // Chuông có 1 thông báo chưa đọc; popup hiện đúng nội dung.
    expect(_textOf(tester, 'unread_badge'), '1');
    await _tapKey(tester, 'bell_button');
    expect(find.text(AppStrings.notifCancelledTitle), findsOneWidget);
    expect(find.textContaining('đã hủy lịch Khám nội tổng quát'), findsOneWidget);
    await tester.tap(find.byTooltip(AppStrings.close));
    await tester.pumpAndSettle();

    // Chỉ còn lịch của người khác đang chờ.
    expect(repo.items.where((a) => a.isPending).length, 1);
    expect(find.text(AppStrings.pendingNotice(1), skipOffstage: false), findsOneWidget);
  });

  testWidgets('Chi tiết: thông tin đầy đủ, hủy tại đây; nhân viên xác nhận khi đang xem -> đổi ngay',
      (tester) async {
    final (repo, _, _) = await _pump(tester);
    await tester.tap(_card('pend'));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.appointmentDetail), findsOneWidget);
    expect(_textOf(tester, 'cdetail_status'), AppStrings.statusPending);
    expect(_textOf(tester, 'cdetail_note'), AppStrings.notePendingCustomer);
    expect(_textOf(tester, 'cdetail_doctor'), 'BS. d1');
    expect(_textOf(tester, 'cdetail_specialty'), 'Nội tổng quát');
    expect(_textOf(tester, 'cdetail_time'), '14:00 – 14:30');
    expect(_textOf(tester, 'cdetail_room'), 'Phòng 101');
    expect(_textOf(tester, 'cdetail_fee'), '150.000 đ');
    expect(_textOf(tester, 'cdetail_patient'), 'Nguyễn Văn Bình\n$_phone');
    expect(_textOf(tester, 'cdetail_cancel_hint'), AppStrings.cancelRuleHint);

    await repo.updateStatus('pend', AppointmentStatus.confirmed);
    await tester.pumpAndSettle();
    expect(_textOf(tester, 'cdetail_status'), AppStrings.statusConfirmed);

    await _tapKey(tester, 'cdetail_cancel');
    await _tapKey(tester, 'cancel_agree');
    expect(_textOf(tester, 'cdetail_status'), AppStrings.statusCancelled);
    expect(_textOf(tester, 'cdetail_note'), AppStrings.noteCancelledCustomer);
    expect(find.byKey(const ValueKey('cdetail_cancel')), findsNothing);
    // Lịch đã hủy -> gợi ý đặt lại với bác sĩ đó.
    await _tapKey(tester, 'cdetail_rebook');
    expect(find.text(AppStrings.doctorInfo), findsOneWidget);
  });

  testWidgets('Chi tiết lịch đã xác nhận còn dưới 2 giờ: không có nút Hủy, có lý do', (tester) async {
    await _pump(tester);
    await tester.tap(_card('soon'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('cdetail_cancel')), findsNothing);
    expect(_textOf(tester, 'cdetail_cancel_hint'), AppStrings.errCancelTooLate);
  });

  testWidgets('hủy thất bại (mất mạng) -> báo lỗi, lịch giữ nguyên; '
      'nhân viên đã từ chối trước -> lịch rời nhóm Sắp tới', (tester) async {
    final (repo, notifications, _) = await _pump(tester);
    repo.nextUpdateError = const NetworkFailure();
    await _tapKey(tester, 'cancel_pend');
    await _tapKey(tester, 'cancel_agree');
    expect(find.text(AppStrings.errNetwork), findsOneWidget);
    expect(_card('pend'), findsOneWidget);
    expect(notifications.items, isEmpty);

    await repo.updateStatus('pend', AppointmentStatus.rejected);
    await tester.pumpAndSettle();
    expect(_card('pend'), findsNothing);
    expect(_textOf(tester, 'cfilter_count_cancelled'), '2');
  });

  testWidgets('trạng thái trống từng nhóm; "Đặt lịch ngay" -> tab Đặt lịch', (tester) async {
    await _pump(tester, initial: const []);
    expect(find.text(AppStrings.cEmptyUpcoming), findsOneWidget);
    await _tapKey(tester, 'cfilter_past');
    expect(find.text(AppStrings.cEmptyPast), findsOneWidget);
    await _tapKey(tester, 'cfilter_cancelled');
    expect(find.text(AppStrings.cEmptyCancelled), findsOneWidget);

    await _tapKey(tester, 'cfilter_upcoming');
    await _tapKey(tester, 'appointments_book_now');
    expect(find.text(AppStrings.bookingTitle), findsOneWidget);
  });

  testWidgets('lỗi tải -> thông báo + Thử lại; thử lại thành công', (tester) async {
    final repo = FakeAppointmentRepository(initial: _sample())..watchError = const NetworkFailure();
    await _pump(tester, repo: repo);
    expect(find.text(AppStrings.loadFailed), findsOneWidget);

    repo.watchError = null;
    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();
    expect(_card('pend'), findsOneWidget);
  });

  testWidgets('Trang chủ: bấm thẻ "Lịch hẹn sắp tới" mở Chi tiết; "Xem tất cả" mở tab Lịch hẹn',
      (tester) async {
    await _pump(tester);
    await _openTab(tester, AppStrings.tabHome);
    await _tapKey(tester, 'next_appointment');
    expect(find.text(AppStrings.appointmentDetail), findsOneWidget);
    expect(_textOf(tester, 'cdetail_time'), '11:00 – 11:30');
    await tester.pageBack();
    await tester.pumpAndSettle();

    await _tapKey(tester, 'see_all_appointments');
    expect(find.byKey(const ValueKey('cfilter_upcoming')), findsOneWidget);
  });
}
