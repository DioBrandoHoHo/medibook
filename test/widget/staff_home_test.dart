import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/constants/app_strings.dart';
import 'package:medibook/core/errors/app_failure.dart';
import 'package:medibook/features/appointments/domain/entities/appointment.dart';
import 'package:medibook/features/appointments/domain/entities/appointment_status.dart';
import 'package:medibook/features/auth/domain/entities/user_role.dart';
import 'package:medibook/features/notifications/domain/entities/app_notification.dart';

import '../mocks/fake_clinic_repositories.dart';
import '../mocks/fake_repositories.dart';
import 'test_helpers.dart';

/// "Bây giờ" trong test = 14/11/2026 10:00.
final _now = DateTime(2026, 11, 14, 10);
DateTime _today(int h, [int m = 0]) => DateTime(2026, 11, 14, h, m);
DateTime _tomorrow(int h) => DateTime(2026, 11, 15, h);

List<Appointment> _sample() => [
  appt('t1', _today(8), status: AppointmentStatus.confirmed, name: 'Lê Văn Hùng'),
  appt('t2', _today(9), status: AppointmentStatus.cancelled, name: 'Đỗ Thị Lan'),
  appt('t3', _today(11), name: 'Trần Văn Minh', service: 'Khám da liễu'),
  appt('t4', _today(12), status: AppointmentStatus.confirmed, name: 'Nguyễn Thị Mai'),
  appt('m1', _tomorrow(8), name: 'Phạm Thị Bích'),
  appt('m2', _tomorrow(9), status: AppointmentStatus.confirmed, name: 'Bùi Thu Hà'),
];

AppNotification _note(String id, {String? appointmentId, bool isRead = false}) => AppNotification(
  id: id,
  title: 'Lịch đặt mới',
  body: 'Nội dung $id',
  createdAt: _now.subtract(const Duration(minutes: 5)),
  appointmentId: appointmentId,
  isRead: isRead,
);

/// Mở app với một Staff đã đăng nhập sẵn -> vào thẳng Trang chủ Staff.
Future<void> _pumpStaffHome(
  WidgetTester tester, {
  required FakeAppointmentRepository appointments,
  FakeNotificationRepository? notifications,
}) async {
  final auth = FakeAuthRepository()
    ..seed(
      phone: '0900000001',
      password: 'Staff@123',
      fullName: 'Trần Thu Trang',
      role: UserRole.staff,
      signedIn: true,
    );
  await pumpApp(
    tester,
    auth,
    appointmentRepo: appointments,
    notificationRepo: notifications,
    clock: () => _now,
  );
}

String _textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

void main() {
  testWidgets('hiển thị số liệu TÍNH từ danh sách lịch hẹn, không phải số cố định', (tester) async {
    await _pumpStaffHome(tester, appointments: FakeAppointmentRepository(initial: _sample()));

    expect(find.text(AppStrings.appName), findsOneWidget);
    expect(find.text(AppStrings.slogan), findsOneWidget);
    expect(_textOf(tester, 'stat_today_total'), '4');
    expect(_textOf(tester, 'stat_pending'), '1');
    expect(_textOf(tester, 'stat_confirmed'), '2');
    expect(_textOf(tester, 'stat_cancelled'), '1');
    // Lời chào kèm tên nhân viên + ngày đang thống kê.
    expect(find.text(AppStrings.greeting), findsOneWidget);
    expect(_textOf(tester, 'greeting_name'), 'Trần Thu Trang');
    expect(_textOf(tester, 'overview_date'), 'Thứ Bảy, 14/11/2026');
    // Số trên tab Lịch đặt = Pending mọi ngày, cùng nguồn với thẻ bên dưới.
    expect(_textOf(tester, 'tab_pending_badge'), '2');
    // Thẻ đếm Pending ở mọi ngày (t3 + m1) nên khác chỉ số hôm nay.
    expect(find.text(AppStrings.pendingNotice(2)), findsOneWidget);
    // 3 lịch gần nhất chưa diễn ra, đúng thứ tự.
    expect(find.text('Trần Văn Minh'), findsOneWidget);
    expect(find.text('Nguyễn Thị Mai'), findsOneWidget);
    expect(find.text('Phạm Thị Bích'), findsOneWidget);
    expect(find.text('Bùi Thu Hà'), findsNothing); // lịch thứ 4 không hiện
    expect(find.text('Lê Văn Hùng'), findsNothing); // đã diễn ra
    // Ngày dạng gọn + thời gian còn lại cho lịch hôm nay (Lượt 18).
    expect(find.text('11:00 – 11:30  •  '), findsOneWidget);
    expect(_textOf(tester, 'starts_in_t3'), 'còn 1 giờ');
    expect(find.text('08:00 – 08:30  •  Ngày mai'), findsOneWidget);
    expect(find.byKey(const ValueKey('starts_in_m1')), findsNothing);
  });

  testWidgets('mở chi tiết -> Xác nhận -> quay lại Trang chủ thấy số liệu đổi', (tester) async {
    final repo = FakeAppointmentRepository(initial: _sample());
    await _pumpStaffHome(tester, appointments: repo);

    // Danh sách sắp diễn ra nằm dưới 4 thẻ chỉ số -> cuộn tới rồi mới bấm.
    await tester.ensureVisible(find.byKey(const ValueKey('appointment_t3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('appointment_t3')));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.appointmentDetail), findsOneWidget);
    expect(find.text('Khám da liễu'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('confirm_button')));
    await tester.pumpAndSettle();
    // Có hộp thoại hỏi lại; chưa đồng ý thì dữ liệu chưa đổi.
    expect(find.text(AppStrings.confirmDialogTitle), findsOneWidget);
    expect(repo.items.firstWhere((a) => a.id == 't3').status, AppointmentStatus.pending);
    await tester.tap(find.byKey(const ValueKey('dialog_agree')));
    await tester.pumpAndSettle();
    expect(repo.items.firstWhere((a) => a.id == 't3').status, AppointmentStatus.confirmed);
    expect(find.text(AppStrings.noteConfirmed), findsOneWidget);
    expect(find.byKey(const ValueKey('confirm_button')), findsNothing); // hết nút sau khi xử lý

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(_textOf(tester, 'stat_pending'), '0');
    expect(_textOf(tester, 'stat_confirmed'), '3');
    expect(_textOf(tester, 'stat_today_total'), '4'); // tổng không đổi
    expect(find.text(AppStrings.pendingNotice(1)), findsOneWidget);
    expect(find.text('Trần Văn Minh'), findsOneWidget); // vẫn sắp diễn ra
  });

  testWidgets('Từ chối -> lịch biến mất khỏi danh sách, lịch kế tiếp lên thay', (tester) async {
    await _pumpStaffHome(tester, appointments: FakeAppointmentRepository(initial: _sample()));

    // Danh sách sắp diễn ra nằm dưới 4 thẻ chỉ số -> cuộn tới rồi mới bấm.
    await tester.ensureVisible(find.byKey(const ValueKey('appointment_t3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('appointment_t3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reject_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dialog_agree')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(_textOf(tester, 'stat_pending'), '0');
    expect(_textOf(tester, 'stat_cancelled'), '2');
    expect(find.text('Trần Văn Minh'), findsNothing);
    expect(find.text('Bùi Thu Hà'), findsOneWidget);
  });

  testWidgets('dữ liệu đổi từ bên ngoài (Customer đặt / hủy) -> Trang chủ tự cập nhật', (
    tester,
  ) async {
    final repo = FakeAppointmentRepository(initial: _sample());
    await _pumpStaffHome(tester, appointments: repo);

    await repo.create(
      customerId: 'c9',
      customerName: 'Lê An',
      serviceName: 'Khám mắt',
      startAt: _today(10, 30),
      endAt: _today(11),
    );
    await tester.pumpAndSettle();
    expect(_textOf(tester, 'stat_today_total'), '5');
    expect(_textOf(tester, 'stat_pending'), '2');
    expect(find.text(AppStrings.pendingNotice(3)), findsOneWidget);
    expect(find.text('Lê An'), findsOneWidget);

    await repo.updateStatus('t4', AppointmentStatus.cancelled); // Customer hủy lịch đã xác nhận
    await tester.pumpAndSettle();
    expect(_textOf(tester, 'stat_confirmed'), '1');
    expect(find.text('Nguyễn Thị Mai'), findsNothing);
  });

  testWidgets('không có dữ liệu -> số 0, thẻ và danh sách hiện trạng thái trống', (tester) async {
    await _pumpStaffHome(tester, appointments: FakeAppointmentRepository());

    expect(_textOf(tester, 'stat_today_total'), '0');
    expect(find.text(AppStrings.noPendingNotice), findsOneWidget);
    expect(find.text(AppStrings.upcomingEmpty), findsOneWidget);
  });

  testWidgets('lỗi tải dữ liệu -> hiện thông báo và nút Thử lại; thử lại thành công', (
    tester,
  ) async {
    final repo = FakeAppointmentRepository(initial: _sample())..watchError = const NetworkFailure();
    await _pumpStaffHome(tester, appointments: repo);

    expect(find.text(AppStrings.loadFailed), findsOneWidget);
    expect(find.text(AppStrings.errNetwork), findsOneWidget);

    repo.watchError = null;
    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.loadFailed), findsNothing);
    expect(_textOf(tester, 'stat_today_total'), '4');
  });

  testWidgets('"Xem chi tiết" -> Lịch đặt lọc Hôm nay; thẻ chờ xử lý -> lọc Pending', (
    tester,
  ) async {
    await _pumpStaffHome(tester, appointments: FakeAppointmentRepository(initial: _sample()));

    await tester.tap(find.byKey(const ValueKey('see_detail')));
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(find.byKey(const ValueKey('filter_today'))).selected, isTrue);
    expect(find.text('Lê Văn Hùng'), findsOneWidget); // lịch hôm nay đã diễn ra vẫn có ở đây
    expect(find.text('Phạm Thị Bích'), findsNothing); // lịch ngày mai bị lọc

    await tester.tap(find.text(AppStrings.tabOverview));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pending_notice')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ChoiceChip>(find.byKey(const ValueKey('filter_pending'))).selected,
      isTrue,
    );
    expect(find.text('Trần Văn Minh'), findsOneWidget);
    expect(find.text('Phạm Thị Bích'), findsOneWidget);
    expect(find.text('Nguyễn Thị Mai'), findsNothing);
  });

  testWidgets('"Xem tất cả" -> Lịch đặt hiện đầy đủ; ảnh đại diện -> tab Tài khoản', (
    tester,
  ) async {
    await _pumpStaffHome(tester, appointments: FakeAppointmentRepository(initial: _sample()));

    // Danh sách sắp diễn ra nằm cuối trang -> cuộn tới rồi mới bấm.
    await tester.ensureVisible(find.byKey(const ValueKey('see_all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('see_all')));
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(find.byKey(const ValueKey('filter_all'))).selected, isTrue);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('booking_count'))).data,
      AppStrings.bookingCount(6),
    );
    // Lịch cuối danh sách nằm dưới màn hình -> cuộn tới.
    await tester.scrollUntilVisible(
      find.text('Bùi Thu Hà'),
      200,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('bookings_list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Bùi Thu Hà'), findsOneWidget);

    await tester.tap(find.text(AppStrings.tabOverview));
    await tester.pumpAndSettle();
    // Tab giữ nguyên vị trí cuộn lúc rời đi -> cuộn lên lại phần đầu.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('staff_avatar')),
      -300,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('home_refresh')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('staff_avatar')));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.profileTitle), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('account_name'))).data, 'Trần Thu Trang');
  });

  testWidgets('chuông: số chưa đọc, popup, đọc thông báo thì số giảm và ẩn khi hết', (
    tester,
  ) async {
    final notifications = FakeNotificationRepository(
      initial: [_note('n1'), _note('n2'), _note('n3', isRead: true)],
    );
    await _pumpStaffHome(
      tester,
      appointments: FakeAppointmentRepository(initial: _sample()),
      notifications: notifications,
    );
    // Số trên chuông (2) khác số lịch chờ xử lý trên thẻ (2 lịch nhưng nguồn khác nhau).
    expect(_textOf(tester, 'unread_badge'), '2');

    await tester.tap(find.byKey(const ValueKey('bell_button')));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.notifications), findsOneWidget);
    expect(find.text('Nội dung n1'), findsOneWidget);
    expect(find.text('5 phút trước'), findsNWidgets(3));

    await tester.tap(find.byKey(const ValueKey('notification_n1')));
    await tester.pumpAndSettle();
    expect(notifications.items.firstWhere((n) => n.id == 'n1').isRead, isTrue);
    expect(_textOf(tester, 'unread_badge'), '1');

    await tester.tap(find.byKey(const ValueKey('mark_all_read')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(AppStrings.close));
    await tester.pumpAndSettle();
    // Hết thông báo chưa đọc -> ẩn số đỏ.
    final bellBadge = find.descendant(
      of: find.byKey(const ValueKey('bell_button')),
      matching: find.byType(Badge),
    );
    expect(tester.widget<Badge>(bellBadge).isLabelVisible, isFalse);
  });

  testWidgets('bấm thông báo có lịch liên quan -> mở Chi tiết lịch hẹn', (tester) async {
    await _pumpStaffHome(
      tester,
      appointments: FakeAppointmentRepository(initial: _sample()),
      notifications: FakeNotificationRepository(initial: [_note('n1', appointmentId: 't3')]),
    );

    await tester.tap(find.byKey(const ValueKey('bell_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('notification_n1')));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.appointmentDetail), findsOneWidget);
    expect(find.text('Trần Văn Minh'), findsOneWidget);
  });

  testWidgets('popup không có thông báo -> hiện trạng thái trống', (tester) async {
    await _pumpStaffHome(tester, appointments: FakeAppointmentRepository());
    await tester.tap(find.byKey(const ValueKey('bell_button')));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.notificationsEmpty), findsOneWidget);
  });

  testWidgets('Tổng quan không còn nút "Tạo lại dữ liệu mẫu"', (tester) async {
    await _pumpStaffHome(tester, appointments: FakeAppointmentRepository());
    expect(find.byKey(const ValueKey('seed_demo'), skipOffstage: false), findsNothing);
    expect(find.text('Tạo lại dữ liệu mẫu', skipOffstage: false), findsNothing);
  });

  group('Nâng cấp Lượt 18', () {
    testWidgets('thẻ cần xử lý nằm ngay dưới phần đầu, chia hôm nay / ngày khác + lịch gần nhất', (
      tester,
    ) async {
      await _pumpStaffHome(tester, appointments: FakeAppointmentRepository(initial: _sample()));

      // Thẻ việc cần làm nằm TRÊN khu vực Tổng quan hôm nay và thấy được ngay, không cần cuộn.
      final card = find.byKey(const ValueKey('pending_notice'));
      expect(
        tester.getTopLeft(card).dy,
        lessThan(tester.getTopLeft(find.byKey(const ValueKey('see_detail'))).dy),
      );
      expect(tester.getBottomLeft(card).dy, lessThan(600));
      expect(_textOf(tester, 'pending_breakdown'), 'Hôm nay 1  •  Ngày khác 1');
      expect(_textOf(tester, 'pending_next'), 'Gần nhất: 11:00, Hôm nay');
      expect(find.byKey(const ValueKey('pending_overdue')), findsNothing);
    });

    testWidgets('lịch chờ đã quá giờ -> cảnh báo đỏ; xử lý xong thì cảnh báo biến mất', (
      tester,
    ) async {
      final repo = FakeAppointmentRepository(
        initial: [
          ..._sample(),
          appt('y1', DateTime(2026, 11, 13, 15), name: 'Khách hôm qua'),
        ],
      );
      await _pumpStaffHome(tester, appointments: repo);

      expect(find.text(AppStrings.pendingNotice(3)), findsOneWidget);
      expect(_textOf(tester, 'pending_breakdown'), 'Hôm nay 1  •  Ngày khác 2');
      expect(_textOf(tester, 'pending_overdue'), AppStrings.pendingOverdue(1));

      await repo.updateStatus('y1', AppointmentStatus.rejected);
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.pendingNotice(2)), findsOneWidget);
      expect(find.byKey(const ValueKey('pending_overdue')), findsNothing);
      expect(find.byKey(const ValueKey('pending_next')), findsOneWidget);
    });

    testWidgets('còn lại hôm nay + thanh tỉ lệ trạng thái', (tester) async {
      await _pumpStaffHome(tester, appointments: FakeAppointmentRepository(initial: _sample()));
      // t3 (11:00, chờ) + t4 (12:00, đã xác nhận) chưa diễn ra.
      expect(_textOf(tester, 'today_remaining'), AppStrings.todayRemaining(2));
      expect(find.byKey(const ValueKey('today_status_bar')), findsOneWidget);
    });

    testWidgets('không có lịch hôm nay -> ẩn thanh tỉ lệ', (tester) async {
      await _pumpStaffHome(tester, appointments: FakeAppointmentRepository());
      expect(_textOf(tester, 'today_remaining'), AppStrings.todayRemaining(0));
      expect(find.byKey(const ValueKey('today_status_bar')), findsNothing);
    });

    testWidgets('lịch sắp diễn ra hiện tên bác sĩ (nếu có)', (tester) async {
      await _pumpStaffHome(
        tester,
        appointments: FakeAppointmentRepository(
          initial: [
            appt('a1', _today(11), name: 'Có bác sĩ', doctorId: 'd1'),
            appt('a2', _today(12), name: 'Chưa gắn bác sĩ'),
          ],
        ),
      );
      expect(_textOf(tester, 'tile_doctor_a1'), 'BS. d1');
      expect(find.byKey(const ValueKey('tile_doctor_a2')), findsNothing);
    });

    testWidgets('kéo xuống để làm mới: khi lỗi thì kết nối lại', (tester) async {
      final repo = FakeAppointmentRepository(initial: _sample())
        ..watchError = const NetworkFailure();
      await _pumpStaffHome(tester, appointments: repo);
      expect(find.text(AppStrings.loadFailed), findsOneWidget);

      repo.watchError = null;
      await tester.fling(find.byKey(const ValueKey('greeting_name')), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.loadFailed), findsNothing);
      expect(_textOf(tester, 'stat_today_total'), '4');
    });

    testWidgets('chuông: hơn 99 thông báo chưa đọc -> hiện "99+"', (tester) async {
      await _pumpStaffHome(
        tester,
        appointments: FakeAppointmentRepository(initial: _sample()),
        notifications: FakeNotificationRepository(
          initial: [for (var i = 0; i < 120; i++) _note('n$i')],
        ),
      );
      expect(_textOf(tester, 'unread_badge'), '99+');
    });

    testWidgets('"Xem tất cả" khi có lịch cũ -> Lịch đặt mở sẵn ở hôm nay, kéo lên thấy lịch cũ', (
      tester,
    ) async {
      await _pumpStaffHome(
        tester,
        appointments: FakeAppointmentRepository(
          initial: [
            for (var d = 1; d <= 6; d++)
              appt(
                'old$d',
                DateTime(2026, 11, 14 - d, 9),
                name: 'Khách cũ $d',
                status: AppointmentStatus.confirmed,
              ),
            ..._sample(),
          ],
        ),
      );
      await tester.ensureVisible(find.byKey(const ValueKey('see_all')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('see_all')));
      await tester.pumpAndSettle();

      expect(_textOf(tester, 'booking_count'), AppStrings.bookingCount(12));
      // Mở ngay ở hôm nay: dòng nhắc nằm sát mép trên danh sách, ngay sau là Hôm nay + lịch đầu ngày.
      expect(find.text(AppStrings.earlierBookings(6)), findsOneWidget);
      expect(find.text('Hôm nay, 14/11/2026'), findsOneWidget);
      expect(find.byKey(const ValueKey('card_t1')), findsOneWidget);
      final listTop = tester.getTopLeft(find.byKey(const ValueKey('bookings_list'))).dy;
      expect(tester.getTopLeft(find.byKey(const ValueKey('earlier_hint'))).dy, closeTo(listTop, 1));

      // Kéo xuống (cuộn lên) để xem lịch cũ; lịch cũ hơn nằm phía trên.
      final scrollable = find.descendant(
        of: find.byKey(const ValueKey('bookings_list')),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('card_old1')),
        -150,
        scrollable: scrollable,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('card_old2')),
        -150,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('card_old2'))).dy,
        lessThan(tester.getTopLeft(find.byKey(const ValueKey('card_old1'))).dy),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('card_old6')),
        -150,
        scrollable: scrollable,
      );
      expect(find.byKey(const ValueKey('card_old6')), findsOneWidget);
    });

    testWidgets('Lịch đặt: bộ lọc khác "Tất cả" hoặc đang tìm kiếm -> danh sách thường', (
      tester,
    ) async {
      await _pumpStaffHome(
        tester,
        appointments: FakeAppointmentRepository(
          initial: [
            appt(
              'old1',
              DateTime(2026, 11, 10, 9),
              name: 'Khách cũ',
              status: AppointmentStatus.confirmed,
            ),
            ..._sample(),
          ],
        ),
      );
      await tester.tap(find.byKey(const ValueKey('pending_notice')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('earlier_hint')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('filter_all')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('earlier_hint')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('search_button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('search_field')), 'khach cu');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('earlier_hint')), findsNothing);
      expect(find.byKey(const ValueKey('card_old1')), findsOneWidget);
    });
  });
}
