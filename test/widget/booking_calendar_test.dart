import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/constants/app_strings.dart';
import 'package:medibook/features/appointments/domain/entities/appointment_status.dart';
import 'package:medibook/features/booking/domain/entities/doctor.dart';

import '../mocks/fake_clinic_repositories.dart';
import '../mocks/fake_repositories.dart';
import 'test_helpers.dart';

// Tab Đặt lịch: chuyển tháng / năm, chọn ngày ở tháng sau, đồng bộ giờ mong muốn,
// đặt lịch sang năm sau và thấy đúng ở tab Lịch hẹn (bổ sung 17/11/2026).

/// "Bây giờ" = Thứ Ba 17/11/2026 10:00.
final _now = DateTime(2026, 11, 17, 10);

const _doctors = [
  Doctor(id: 'd1', name: 'BS. Nguyễn Văn An', specialty: 'Nội tổng quát', room: 'Phòng 101'),
  Doctor(id: 'd2', name: 'BS. Trần Thị Bình', specialty: 'Da liễu', room: 'Phòng 102'),
];

FakeAuthRepository _auth() => FakeAuthRepository()
  ..seed(
    phone: '0912345678',
    password: 'Khach@123',
    fullName: 'Nguyễn Văn Bình',
    signedIn: true,
    profilePromptDismissed: true,
  );

Future<FakeAppointmentRepository> _pump(
  WidgetTester tester, {
  FakeAppointmentRepository? appointments,
  DateTime? now,
}) async {
  final repo = appointments ?? FakeAppointmentRepository();
  await pumpApp(
    tester,
    _auth(),
    appointmentRepo: repo,
    doctorRepo: FakeDoctorRepository(initial: _doctors),
    clock: () => now ?? _now,
  );
  return repo;
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

bool _enabled(WidgetTester tester, String key) =>
    tester.widget<InkWell>(find.byKey(ValueKey(key))).onTap != null;

void main() {
  testWidgets('‹ › chuyển tháng: sang tháng 12/2026 rồi 01/2027, ngày + thứ + số ca trống đúng',
      (tester) async {
    await _pump(
      tester,
      appointments: FakeAppointmentRepository(
        initial: [appt('o1', DateTime(2027, 1, 1, 8), doctorId: 'd1', customerId: 'someone')],
      ),
    );
    await _openTab(tester, AppStrings.tabBooking);

    expect(_textOf(tester, 'month_label_text'), 'Tháng 11, 2026');
    expect(_textOf(tester, 'booking_day_label'), 'Hôm nay, 17/11/2026');
    // Tháng đầu tiên -> không lùi được nữa.
    expect(tester.widget<IconButton>(find.byKey(const ValueKey('month_prev'))).onPressed, isNull);

    await _tapKey(tester, 'month_next');
    expect(_textOf(tester, 'month_label_text'), 'Tháng 12, 2026');
    expect(_textOf(tester, 'booking_day_label'), 'Thứ Ba, 01/12/2026');
    expect(_textOf(tester, 'doctor_free_d1'), AppStrings.freeSlots(16));

    await _tapKey(tester, 'month_next');
    expect(_textOf(tester, 'month_label_text'), 'Tháng 1, 2027');
    expect(_textOf(tester, 'booking_day_label'), 'Thứ Sáu, 01/01/2027');
    // Khung 08:00 ngày 01/01/2027 của d1 đã có người đặt.
    expect(_textOf(tester, 'doctor_free_d1'), AppStrings.freeSlots(15));
    expect(_textOf(tester, 'doctor_free_d2'), AppStrings.freeSlots(16));

    // Lùi về tháng 11 -> về hôm nay (không chọn được ngày đã qua).
    await _tapKey(tester, 'month_prev');
    await _tapKey(tester, 'month_prev');
    expect(_textOf(tester, 'booking_day_label'), 'Hôm nay, 17/11/2026');
  });

  testWidgets('bảng lịch tháng: ngày đã qua bị khoá, đổi tháng + năm, chọn 08/03/2027',
      (tester) async {
    await _pump(tester);
    await _openTab(tester, AppStrings.tabBooking);

    await _tapKey(tester, 'month_label');
    expect(_textOf(tester, 'cal_title_text'), 'Tháng 11, 2026');
    expect(_enabled(tester, 'cal_day_2026-11-16'), isFalse); // hôm qua
    expect(_enabled(tester, 'cal_day_2026-11-17'), isTrue);
    expect(_textOf(tester, 'cal_note'), AppStrings.bookingRange('17/11/2026', '15/05/2027'));
    expect(tester.widget<IconButton>(find.byKey(const ValueKey('cal_prev'))).onPressed, isNull);

    await _tapKey(tester, 'cal_next');
    expect(_textOf(tester, 'cal_title_text'), 'Tháng 12, 2026');

    // Chọn nhanh tháng / năm.
    await _tapKey(tester, 'cal_title');
    expect(_textOf(tester, 'cal_year'), '2026');
    expect(_enabled(tester, 'cal_month_10'), isFalse); // tháng đã qua
    await _tapKey(tester, 'cal_year_next');
    expect(_textOf(tester, 'cal_year'), '2027');
    expect(_enabled(tester, 'cal_month_6'), isFalse); // ngoài 180 ngày
    expect(tester.widget<IconButton>(find.byKey(const ValueKey('cal_year_next'))).onPressed, isNull);
    await _tapKey(tester, 'cal_month_3');
    expect(_textOf(tester, 'cal_title_text'), 'Tháng 3, 2027');

    await _tapKey(tester, 'cal_day_2027-03-08');
    expect(find.byKey(const ValueKey('cal_title')), findsNothing); // bảng đã đóng
    expect(_textOf(tester, 'booking_day_label'), 'Thứ Hai, 08/03/2027');
    expect(_textOf(tester, 'month_label_text'), 'Tháng 3, 2027');
    expect(_textOf(tester, 'doctor_free_d1'), AppStrings.freeSlots(16));

    // Ngày cuối được đặt mở được, ngày sau đó thì không.
    await _tapKey(tester, 'month_label');
    await _tapKey(tester, 'cal_next');
    await _tapKey(tester, 'cal_next');
    expect(_textOf(tester, 'cal_title_text'), 'Tháng 5, 2027');
    expect(_enabled(tester, 'cal_day_2027-05-15'), isTrue);
    expect(_enabled(tester, 'cal_day_2027-05-16'), isFalse);
    expect(tester.widget<IconButton>(find.byKey(const ValueKey('cal_next'))).onPressed, isNull);
  });

  testWidgets('giờ mong muốn: chọn 08:00 ở tháng sau rồi quay về hôm nay -> tự bỏ chọn giờ',
      (tester) async {
    await _pump(tester);
    await _openTab(tester, AppStrings.tabBooking);

    await _tapKey(tester, 'month_next'); // 01/12/2026
    await _tapKey(tester, 'time_filter');
    expect(_textOf(tester, 'time_sheet_day'), 'Thứ Ba, 01/12/2026');
    // Ngày tương lai: mọi khung đều chọn được, kể cả 08:00.
    expect(_enabled(tester, 'time_opt_${8 * 60}'), isTrue);
    await _tapKey(tester, 'time_opt_${8 * 60}');
    expect(_textOf(tester, 'time_filter_label'), '08:00 – 08:30');
    expect(_textOf(tester, 'doctor_match_count'), AppStrings.doctorMatch(2));

    // Sang ngày khác của tháng sau: vẫn giữ giờ.
    await _tapKey(tester, 'month_next'); // 01/01/2027
    expect(_textOf(tester, 'time_filter_label'), '08:00 – 08:30');

    // Về hôm nay lúc 10:00: 08:00 đã qua -> bỏ chọn + báo.
    await _tapKey(tester, 'month_prev');
    await _tapKey(tester, 'month_prev');
    expect(_textOf(tester, 'booking_day_label'), 'Hôm nay, 17/11/2026');
    expect(_textOf(tester, 'time_filter_label'), AppStrings.anyTime);
    expect(find.text(AppStrings.timeCleared('08:00 – 08:30')), findsOneWidget);
    // Khung đã qua của hôm nay vẫn bị khoá trong bảng chọn giờ.
    await _tapKey(tester, 'time_filter');
    expect(_enabled(tester, 'time_opt_${8 * 60}'), isFalse);
  });

  testWidgets('đặt lịch ngày 01/01/2027 -> tab Lịch hẹn có tiêu đề ngày + năm; khung không còn trống',
      (tester) async {
    final repo = await _pump(tester);
    await _openTab(tester, AppStrings.tabBooking);
    await _tapKey(tester, 'month_next');
    await _tapKey(tester, 'month_next'); // 01/01/2027
    await _tapKey(tester, 'time_filter');
    await _tapKey(tester, 'time_opt_${8 * 60}');

    await _tapKey(tester, 'doctor_card_d1');
    // Màn bác sĩ mở đúng ngày + giờ đã chọn.
    expect(_textOf(tester, 'month_label_text'), 'Tháng 1, 2027');
    expect(_textOf(tester, 'book_summary'), '08:00 – 08:30');
    await _tapKey(tester, 'book_button');
    expect(_textOf(tester, 'confirm_date'), 'Thứ Sáu, 01/01/2027');
    await _tapKey(tester, 'book_confirm');

    final created = repo.items.single;
    expect(created.startAt, DateTime(2027, 1, 1, 8));
    expect(created.status, AppointmentStatus.pending);

    // Trở về tab Đặt lịch: d1 không còn trống 08:00 nên bị lọc khỏi danh sách.
    expect(find.byKey(const ValueKey('doctor_card_d1')), findsNothing);
    expect(_textOf(tester, 'doctor_match_count'), AppStrings.doctorMatch(1));

    // Nút "Xem lịch hẹn" trên thông báo -> tab Lịch hẹn, nhóm Sắp tới.
    await tester.tap(find.text(AppStrings.viewAppointments));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.myAppointments), findsOneWidget);
    expect(_textOf(tester, 'cday_2027-01-01'), 'Thứ Sáu, 01/01/2027');
    expect(
      find.descendant(of: find.byKey(ValueKey('cappt_${created.id}')), matching: find.text('2027')),
      findsOneWidget,
    );
    expect(_textOf(tester, 'cfilter_count_upcoming'), '1');
  });

  testWidgets('tab Lịch hẹn: tiêu đề ngày nhóm theo ngày; lịch chờ quá giờ có ghi chú', (tester) async {
    await _pump(
      tester,
      appointments: FakeAppointmentRepository(
        initial: [
          appt('a', DateTime(2026, 11, 17, 14), doctorId: 'd1', customerId: 'u0'),
          appt('b', DateTime(2026, 11, 17, 15), doctorId: 'd2', customerId: 'u0'),
          appt('c', DateTime(2026, 11, 18, 9), doctorId: 'd1', customerId: 'u0'),
          appt('p', DateTime(2026, 11, 16, 9), doctorId: 'd1', customerId: 'u0'),
          appt('q', DateTime(2026, 11, 15, 9),
              status: AppointmentStatus.confirmed, doctorId: 'd1', customerId: 'u0'),
        ],
      ),
    );
    await _openTab(tester, AppStrings.tabAppointments);

    expect(_textOf(tester, 'cday_2026-11-17'), 'Hôm nay, 17/11/2026');
    expect(_textOf(tester, 'cday_2026-11-18'), 'Ngày mai, 18/11/2026');
    expect(find.byKey(const ValueKey('cday_2026-11-17')), findsOneWidget); // 2 lịch, 1 tiêu đề

    await _tapKey(tester, 'cfilter_past');
    expect(_textOf(tester, 'cday_2026-11-16'), 'Hôm qua, 16/11/2026');
    expect(find.byKey(const ValueKey('never_confirmed_p')), findsOneWidget);
    expect(find.byKey(const ValueKey('never_confirmed_q')), findsNothing);
  });
}
