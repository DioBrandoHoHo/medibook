import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/constants/app_strings.dart';
import 'package:medibook/core/errors/app_failure.dart';
import 'package:medibook/features/appointments/domain/entities/appointment.dart';
import 'package:medibook/features/appointments/domain/entities/appointment_status.dart';
import 'package:medibook/features/appointments/presentation/widgets/status_chip.dart';
import 'package:medibook/features/auth/domain/entities/user_role.dart';

import '../mocks/fake_clinic_repositories.dart';
import '../mocks/fake_repositories.dart';
import 'test_helpers.dart';

/// "Bây giờ" trong test = Thứ Bảy 14/11/2026 10:00.
final _now = DateTime(2026, 11, 14, 10);
DateTime _today(int h, [int m = 0]) => DateTime(2026, 11, 14, h, m);
DateTime _tomorrow(int h) => DateTime(2026, 11, 15, h);

/// 4 lịch hôm nay (đủ trạng thái) + 2 lịch ngày mai.
List<Appointment> _sample() => [
      appt('t1', _today(8), status: AppointmentStatus.confirmed, name: 'Lê Văn Hùng'),
      appt('t2', _today(9), status: AppointmentStatus.cancelled, name: 'Đỗ Thị Lan'),
      appt('t3', _today(11), name: 'Trần Văn Minh', service: 'Khám da liễu'),
      appt('t4', _today(12), status: AppointmentStatus.rejected, name: 'Nguyễn Thị Mai'),
      appt('m1', _tomorrow(8), name: 'Phạm Thị Bích'),
      appt('m2', _tomorrow(9), status: AppointmentStatus.confirmed, name: 'Bùi Thu Hà'),
    ];

Future<FakeAuthRepository> _pumpStaff(
  WidgetTester tester,
  FakeAppointmentRepository appointments, {
  FakeAuthRepository? auth,
}) async {
  final repo = auth ??
      (FakeAuthRepository()
        ..seed(
          phone: '0900000001',
          password: 'Staff@123',
          fullName: 'Trần Thu Trang',
          role: UserRole.staff,
          signedIn: true,
        ));
  await pumpApp(tester, repo, appointmentRepo: appointments, clock: () => _now);
  return repo;
}

Future<void> _openTab(WidgetTester tester, String label) async {
  // Nhãn tab nằm trong thanh điều hướng dưới cùng.
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

Future<void> _selectFilter(WidgetTester tester, String name) async {
  final chip = find.byKey(ValueKey('filter_$name'));
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

String _textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

bool _isSelected(WidgetTester tester, String name) =>
    tester.widget<ChoiceChip>(find.byKey(ValueKey('filter_$name'))).selected;

Finder _card(String id) => find.byKey(ValueKey('card_$id'));

/// Cuộn danh sách Lịch đặt tới khi thấy [finder].
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    150,
    scrollable: find.descendant(
      of: find.byKey(const ValueKey('bookings_list')),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.pumpAndSettle();
}

/// Thứ tự các thẻ đang hiển thị, từ trên xuống.
List<String> _visibleCardIds(WidgetTester tester) {
  final cards = find.byWidgetPredicate(
    (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('card_'),
  );
  final entries = [
    for (final e in cards.evaluate())
      (
        (e.widget.key! as ValueKey<String>).value.substring(5),
        tester.getTopLeft(find.byWidget(e.widget)).dy,
      ),
  ]..sort((a, b) => a.$2.compareTo(b.$2));
  return entries.map((e) => e.$1).toList();
}

void main() {
  testWidgets('Tất cả: hiện đủ mọi trạng thái, sắp theo thời gian, gom theo ngày', (tester) async {
    await _pumpStaff(tester, FakeAppointmentRepository(initial: _sample()));
    await _openTab(tester, AppStrings.tabStaffBookings);

    expect(_isSelected(tester, 'all'), isTrue);
    expect(_textOf(tester, 'booking_count'), AppStrings.bookingCount(6));
    // Số trên từng bộ lọc đếm từ cùng danh sách.
    expect(_textOf(tester, 'filter_count_all'), '6');
    expect(_textOf(tester, 'filter_count_today'), '4');
    expect(_textOf(tester, 'filter_count_pending'), '2');

    expect(find.text('Hôm nay, 14/11/2026'), findsOneWidget);
    expect(_visibleCardIds(tester).take(3), ['t1', 't2', 't3']);
    // Thẻ hiện đủ thông tin: tên, dịch vụ, giờ + ngày, mã lịch, trạng thái tiếng Việt.
    final t3 = _card('t3');
    expect(find.descendant(of: t3, matching: find.text('Trần Văn Minh')), findsOneWidget);
    expect(find.descendant(of: t3, matching: find.text('Khám da liễu')), findsOneWidget);
    expect(find.descendant(of: t3, matching: find.text('11:00 – 11:30  •  14/11/2026')),
        findsOneWidget);
    expect(find.descendant(of: t3, matching: find.text('#T3')), findsOneWidget);
    expect(find.descendant(of: t3, matching: find.text('M')), findsOneWidget); // chữ cái đại diện
    expect(tester.widget<StatusChip>(find.descendant(of: t3, matching: find.byType(StatusChip))).status,
        AppointmentStatus.pending);
    expect(find.descendant(of: _card('t2'), matching: find.text(AppStrings.statusCancelled)),
        findsOneWidget);

    // Cuộn xuống: đủ cả 4 trạng thái và lịch ngày mai nằm sau lịch hôm nay.
    await _scrollTo(tester, _card('t4'));
    expect(find.descendant(of: _card('t4'), matching: find.text(AppStrings.statusRejected)),
        findsOneWidget);
    await _scrollTo(tester, _card('m2'));
    expect(find.text('Ngày mai, 15/11/2026'), findsOneWidget);
    expect(_visibleCardIds(tester).last, 'm2');
    expect(find.descendant(of: _card('m2'), matching: find.text(AppStrings.statusConfirmed)),
        findsOneWidget);
  });

  testWidgets('Hôm nay: chỉ lịch trong ngày, vẫn đủ trạng thái; Chờ xác nhận: Pending mọi ngày',
      (tester) async {
    await _pumpStaff(tester, FakeAppointmentRepository(initial: _sample()));
    await _openTab(tester, AppStrings.tabStaffBookings);

    await _selectFilter(tester, 'today');
    expect(_isSelected(tester, 'today'), isTrue);
    expect(_isSelected(tester, 'all'), isFalse);
    expect(_textOf(tester, 'booking_count'), AppStrings.bookingCount(4));
    expect(find.text('Ngày mai, 15/11/2026'), findsNothing);
    expect(_card('m1'), findsNothing);
    expect(_visibleCardIds(tester).take(3), ['t1', 't2', 't3']);

    await _selectFilter(tester, 'pending');
    expect(_textOf(tester, 'booking_count'), AppStrings.bookingCount(2));
    expect(_visibleCardIds(tester), ['t3', 'm1']); // gồm cả lịch ngày mai
    expect(find.text('Lê Văn Hùng'), findsNothing);
  });

  testWidgets('bấm thẻ -> mở đúng Chi tiết của lịch đó', (tester) async {
    await _pumpStaff(tester, FakeAppointmentRepository(initial: _sample()));
    await _openTab(tester, AppStrings.tabStaffBookings);
    await _selectFilter(tester, 'pending');

    await tester.tap(find.byKey(const ValueKey('appointment_m1')));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.appointmentDetail), findsOneWidget);
    expect(find.text('Phạm Thị Bích'), findsOneWidget);
    expect(find.text('m1'), findsOneWidget); // mã lịch đầy đủ = id
    expect(find.text('Chủ nhật, 15/11/2026'), findsOneWidget);
    expect(find.text('08:00 – 08:30'), findsOneWidget);
    expect(find.text(AppStrings.notePending), findsOneWidget);
  });

  testWidgets('Xác nhận ở Chi tiết -> danh sách đổi trạng thái; đang lọc Chờ xác nhận thì thẻ biến mất',
      (tester) async {
    final repo = FakeAppointmentRepository(initial: _sample());
    await _pumpStaff(tester, repo);
    await _openTab(tester, AppStrings.tabStaffBookings);
    await _selectFilter(tester, 'pending');

    await tester.tap(find.byKey(const ValueKey('appointment_t3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dialog_agree')));
    await tester.pumpAndSettle();
    expect(repo.items.firstWhere((a) => a.id == 't3').status, AppointmentStatus.confirmed);

    await tester.pageBack();
    await tester.pumpAndSettle();
    // Không còn phù hợp bộ lọc -> tự biến mất, số đếm giảm.
    expect(_card('t3'), findsNothing);
    expect(_visibleCardIds(tester), ['m1']);
    expect(_textOf(tester, 'filter_count_pending'), '1');

    // Sang "Hôm nay": vẫn là lịch đó nhưng nhãn đã đổi và hết nút xử lý.
    await _selectFilter(tester, 'today');
    expect(find.descendant(of: _card('t3'), matching: find.text(AppStrings.statusConfirmed)),
        findsOneWidget);
    expect(find.byKey(const ValueKey('quick_confirm_t3')), findsNothing);
  });

  testWidgets('Từ chối nhanh ngay trên thẻ: hỏi lại, Hủy thì không đổi, Đồng ý thì cập nhật',
      (tester) async {
    final repo = FakeAppointmentRepository(initial: _sample());
    await _pumpStaff(tester, repo);
    await _openTab(tester, AppStrings.tabStaffBookings);
    await _selectFilter(tester, 'today');

    // Chỉ lịch đang chờ mới có nút xử lý nhanh.
    expect(find.byKey(const ValueKey('quick_reject_t3')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick_reject_t1')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('quick_reject_t3')));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.rejectDialogTitle), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('dialog_cancel')));
    await tester.pumpAndSettle();
    expect(repo.items.firstWhere((a) => a.id == 't3').status, AppointmentStatus.pending);

    await tester.tap(find.byKey(const ValueKey('quick_reject_t3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dialog_agree')));
    await tester.pumpAndSettle();
    expect(repo.items.firstWhere((a) => a.id == 't3').status, AppointmentStatus.rejected);
    expect(find.text(AppStrings.rejectedDone), findsOneWidget);
    // Vẫn thuộc "Hôm nay" nên thẻ còn đó, nhưng đã đổi nhãn và hết nút.
    expect(find.descendant(of: _card('t3'), matching: find.text(AppStrings.statusRejected)),
        findsOneWidget);
    expect(find.byKey(const ValueKey('quick_reject_t3')), findsNothing);
  });

  testWidgets('thao tác ở Lịch đặt -> Tổng quan cập nhật số liệu, thẻ chờ xử lý, sắp diễn ra',
      (tester) async {
    await _pumpStaff(tester, FakeAppointmentRepository(initial: _sample()));
    // Trước khi thao tác.
    expect(_textOf(tester, 'stat_today_total'), '4');
    expect(_textOf(tester, 'stat_pending'), '1');
    expect(_textOf(tester, 'stat_confirmed'), '1');
    expect(_textOf(tester, 'stat_cancelled'), '2');
    expect(find.text(AppStrings.pendingNotice(2)), findsOneWidget);
    expect(_textOf(tester, 'tab_pending_badge'), '2');

    await _openTab(tester, AppStrings.tabStaffBookings);
    await tester.tap(find.byKey(const ValueKey('quick_confirm_t3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dialog_agree')));
    await tester.pumpAndSettle();

    await _openTab(tester, AppStrings.tabOverview);
    expect(_textOf(tester, 'stat_today_total'), '4'); // tổng không đổi
    expect(_textOf(tester, 'stat_pending'), '0');
    expect(_textOf(tester, 'stat_confirmed'), '2');
    // Thẻ thông báo vẫn đếm Pending mọi ngày (còn lịch ngày mai) -> khác chỉ số hôm nay.
    expect(find.text(AppStrings.pendingNotice(1)), findsOneWidget);
    expect(_textOf(tester, 'tab_pending_badge'), '1');

    // Từ chối lịch chờ còn lại -> rời khỏi "sắp diễn ra", lịch kế tiếp lên thay.
    expect(find.text('Phạm Thị Bích'), findsOneWidget);
    await _openTab(tester, AppStrings.tabStaffBookings);
    await _selectFilter(tester, 'pending');
    await tester.tap(find.byKey(const ValueKey('quick_reject_m1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dialog_agree')));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.bookingsEmptyPending), findsOneWidget);

    await _openTab(tester, AppStrings.tabOverview);
    expect(find.text(AppStrings.noPendingNotice), findsOneWidget);
    expect(find.text('Phạm Thị Bích'), findsNothing);
    expect(find.text('Bùi Thu Hà'), findsOneWidget);
    expect(find.byKey(const ValueKey('tab_pending_badge')), findsNothing);
  });

  testWidgets('dữ liệu đổi từ nơi khác khi đang mở Lịch đặt -> danh sách tự cập nhật', (tester) async {
    final repo = FakeAppointmentRepository(initial: _sample());
    await _pumpStaff(tester, repo);
    await _openTab(tester, AppStrings.tabStaffBookings);
    await _selectFilter(tester, 'pending');

    await repo.create(
      customerId: 'c9',
      customerName: 'Lê An',
      serviceName: 'Khám mắt',
      startAt: _today(10, 30),
      endAt: _today(11),
    );
    await tester.pumpAndSettle();
    expect(_textOf(tester, 'booking_count'), AppStrings.bookingCount(3));
    expect(find.text('Lê An'), findsOneWidget);

    await repo.updateStatus('t3', AppointmentStatus.cancelled); // khách tự hủy
    await tester.pumpAndSettle();
    expect(_card('t3'), findsNothing);
    expect(_textOf(tester, 'booking_count'), AppStrings.bookingCount(2));
  });

  testWidgets('bấm thẻ chỉ số ở Tổng quan -> Lịch đặt lọc Hôm nay + đúng trạng thái, số lịch khớp',
      (tester) async {
    await _pumpStaff(tester, FakeAppointmentRepository(initial: _sample()));
    final cancelledStat = _textOf(tester, 'stat_cancelled');

    await tester.tap(find.byKey(const ValueKey('stat_card_cancelled')));
    await tester.pumpAndSettle();
    expect(_isSelected(tester, 'today'), isTrue);
    expect(find.byKey(const ValueKey('status_filter_dot')), findsOneWidget);
    expect(_textOf(tester, 'booking_count'), AppStrings.bookingCount(int.parse(cancelledStat)));
    expect(_visibleCardIds(tester), ['t2', 't4']);

    // Bỏ một trạng thái bằng nhãn đang lọc.
    await tester.tap(find.descendant(
      of: find.byKey(const ValueKey('active_status_rejected')),
      matching: find.byIcon(Icons.close_rounded),
    ));
    await tester.pumpAndSettle();
    expect(_visibleCardIds(tester), ['t2']);

    // Chọn "Chờ xác nhận" thì lọc trạng thái nâng cao tự bỏ.
    await _selectFilter(tester, 'pending');
    expect(find.byKey(const ValueKey('status_filter_dot')), findsNothing);
    expect(_visibleCardIds(tester), ['t3', 'm1']);
  });

  testWidgets('lọc theo trạng thái bằng bảng chọn', (tester) async {
    await _pumpStaff(tester, FakeAppointmentRepository(initial: _sample()));
    await _openTab(tester, AppStrings.tabStaffBookings);

    await tester.tap(find.byKey(const ValueKey('status_filter_button')));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.statusFilter), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('status_option_confirmed')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('status_apply')));
    await tester.pumpAndSettle();
    expect(_visibleCardIds(tester), ['t1', 'm2']);

    await tester.tap(find.byKey(const ValueKey('status_filter_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('status_reset')));
    await tester.pumpAndSettle();
    expect(_textOf(tester, 'booking_count'), AppStrings.bookingCount(6));
  });

  testWidgets('tìm kiếm theo tên không dấu; không có kết quả -> thông báo + nút xoá lọc', (tester) async {
    await _pumpStaff(tester, FakeAppointmentRepository(initial: _sample()));
    await _openTab(tester, AppStrings.tabStaffBookings);

    await tester.tap(find.byKey(const ValueKey('search_button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('search_field')), 'thi');
    await tester.pumpAndSettle();
    expect(_visibleCardIds(tester), ['t2', 't4', 'm1']); // Đỗ Thị Lan, Nguyễn Thị Mai, Phạm Thị Bích

    await tester.enterText(find.byKey(const ValueKey('search_field')), 'khong co ai');
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.bookingsEmptyFiltered), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('clear_filters')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('search_field')), findsNothing);
    expect(_textOf(tester, 'booking_count'), AppStrings.bookingCount(6));
  });

  testWidgets('không có dữ liệu -> thông báo theo từng bộ lọc', (tester) async {
    await _pumpStaff(tester, FakeAppointmentRepository());
    await _openTab(tester, AppStrings.tabStaffBookings);

    expect(find.text(AppStrings.bookingsEmptyAll), findsOneWidget);
    await _selectFilter(tester, 'today');
    expect(find.text(AppStrings.bookingsEmptyToday), findsOneWidget);
    await _selectFilter(tester, 'pending');
    expect(find.text(AppStrings.bookingsEmptyPending), findsOneWidget);
  });

  testWidgets('lỗi tải dữ liệu -> thông báo + Thử lại; thử lại thành công', (tester) async {
    final repo = FakeAppointmentRepository(initial: _sample())
      ..watchError = const NetworkFailure();
    await _pumpStaff(tester, repo);
    await _openTab(tester, AppStrings.tabStaffBookings);

    expect(find.text(AppStrings.loadFailed), findsOneWidget);
    expect(find.text(AppStrings.errNetwork), findsOneWidget);

    repo.watchError = null;
    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.loadFailed), findsNothing);
    expect(_textOf(tester, 'booking_count'), AppStrings.bookingCount(6));
  });

  testWidgets('đổi trạng thái thất bại -> báo lỗi, danh sách giữ nguyên', (tester) async {
    final repo = FakeAppointmentRepository(initial: _sample());
    await _pumpStaff(tester, repo);
    await _openTab(tester, AppStrings.tabStaffBookings);
    await _selectFilter(tester, 'pending');

    repo.nextUpdateError = const NetworkFailure();
    await tester.tap(find.byKey(const ValueKey('quick_confirm_t3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dialog_agree')));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.errNetwork), findsOneWidget);
    expect(repo.items.firstWhere((a) => a.id == 't3').status, AppointmentStatus.pending);
    expect(_visibleCardIds(tester), ['t3', 'm1']);
  });

  testWidgets('thoát app rồi mở lại -> dữ liệu đã đổi vẫn còn, các màn vẫn khớp nhau', (tester) async {
    final repo = FakeAppointmentRepository(initial: _sample());
    final auth = await _pumpStaff(tester, repo);
    await _openTab(tester, AppStrings.tabStaffBookings);
    await tester.tap(find.byKey(const ValueKey('quick_confirm_t3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dialog_agree')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5)); // chờ thanh thông báo tự ẩn
    await tester.pumpAndSettle();

    // Mở lại app với cùng nguồn dữ liệu (như Firestore sau khi khởi động lại).
    await _pumpStaff(tester, repo, auth: auth);
    expect(_textOf(tester, 'stat_pending'), '0');
    expect(_textOf(tester, 'stat_confirmed'), '2');
    await _openTab(tester, AppStrings.tabStaffBookings);
    await _selectFilter(tester, 'pending');
    expect(_visibleCardIds(tester), ['m1']);
  });
}
