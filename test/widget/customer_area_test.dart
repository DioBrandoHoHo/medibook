import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/constants/app_strings.dart';
import 'package:medibook/core/errors/app_failure.dart';
import 'package:medibook/features/appointments/domain/entities/appointment_status.dart';
import 'package:medibook/features/booking/domain/entities/doctor.dart';

import '../mocks/fake_clinic_repositories.dart';
import '../mocks/fake_repositories.dart';
import 'test_helpers.dart';

// Kiểm thử khu vực Khách hàng: Trang chủ (trang_chu.txt phần 2), Đặt lịch (dat_lich.txt),
// Cá nhân (thong_tin.txt phần 2).

/// "Bây giờ" = Thứ Bảy 14/11/2026 10:00.
final _now = DateTime(2026, 11, 14, 10);
DateTime _today(int h, [int m = 0]) => DateTime(2026, 11, 14, h, m);
DateTime _tomorrow(int h, [int m = 0]) => DateTime(2026, 11, 15, h, m);

const _phone = '0912345678';
const _name = 'Nguyễn Văn Bình';

/// Tài khoản đầu tiên được tạo trong FakeAuthRepository có id 'u0'.
const _me = 'u0';

const _doctors = [
  Doctor(
    id: 'd1',
    name: 'BS. Nguyễn Văn An',
    specialty: 'Nội tổng quát',
    room: 'Phòng 101',
    experienceYears: 12,
    fee: 150000,
    bio: 'Khám và điều trị các bệnh nội khoa.',
  ),
  Doctor(id: 'd2', name: 'BS. Trần Thị Bình', specialty: 'Da liễu', room: 'Phòng 102'),
];

FakeAuthRepository _auth() => FakeAuthRepository()
  ..seed(
    phone: _phone,
    password: 'Khach@123',
    fullName: _name,
    signedIn: true,
    profilePromptDismissed: true,
  );

Future<FakeAppointmentRepository> _pump(
  WidgetTester tester, {
  FakeAppointmentRepository? appointments,
  FakeNotificationRepository? notifications,
  FakeDoctorRepository? doctors,
  FakeAuthRepository? auth,
  DateTime? now,
}) async {
  final repo = appointments ?? FakeAppointmentRepository(notifications: notifications);
  await pumpApp(
    tester,
    auth ?? _auth(),
    appointmentRepo: repo,
    notificationRepo: notifications,
    doctorRepo: doctors ?? FakeDoctorRepository(initial: _doctors),
    clock: () => now ?? _now,
  );
  return repo;
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
  await tester.pumpAndSettle();
}

/// Đọc chữ theo key: ưu tiên phần tử đang hiện trên màn hình; nếu không có thì lấy phần tử
/// đã dựng nhưng nằm ngoài vùng nhìn (cuộn khỏi màn hình / ở tab khác).
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

bool _slotEnabled(WidgetTester tester, int minutes) =>
    tester.widget<InkWell>(find.byKey(ValueKey('slot_$minutes'))).onTap != null;

/// Từ tab Đặt lịch mở trang bác sĩ rồi chuyển sang buổi Chiều.
Future<void> _openDoctorAfternoon(WidgetTester tester, String doctorId) async {
  await _openTab(tester, AppStrings.tabBooking);
  await _tapKey(tester, 'doctor_card_$doctorId');
  await _tapKey(tester, 'detail_shift_afternoon');
}

void main() {
  group('Trang chủ Khách hàng', () {
    testWidgets('chưa có lịch: lời chào đúng tên, thẻ mời đặt lịch, số liệu 0, bác sĩ còn trống hôm nay',
        (tester) async {
      await _pump(tester);

      expect(_textOf(tester, 'greeting_name'), _name);
      expect(find.byKey(const ValueKey('no_upcoming')), findsOneWidget);
      expect(_textOf(tester, 'cstat_upcoming'), '0');
      expect(_textOf(tester, 'cstat_pending'), '0');
      expect(_textOf(tester, 'cstat_confirmed'), '0');
      // Khách hàng không có chuông thông báo của nhân viên.
      expect(find.byKey(const ValueKey('bell_button')), findsNothing);
      // 10:00 -> còn 10:30, 11:00 và 8 khung chiều = 10 ca.
      expect(_textOf(tester, 'doctor_free_d1'), AppStrings.freeSlots(10));
      expect(_textOf(tester, 'doctor_next_d1'), AppStrings.nearest('10:30'));
      expect(find.byKey(const ValueKey('tab_upcoming_badge')), findsNothing);

      await _tapKey(tester, 'book_now');
      expect(find.text(AppStrings.bookingTitle), findsOneWidget);
    });

    testWidgets('chỉ hiện lịch của CHÍNH khách; lịch gần nhất, số liệu, danh sách tiếp theo',
        (tester) async {
      await _pump(
        tester,
        appointments: FakeAppointmentRepository(
          initial: [
            appt('mine1', _today(14), doctorId: 'd1', customerId: _me),
            appt('mine2', _tomorrow(9), status: AppointmentStatus.confirmed, doctorId: 'd2', customerId: _me),
            appt('minex', _today(15), status: AppointmentStatus.cancelled, doctorId: 'd1', customerId: _me),
            appt('other', _today(11), doctorId: 'd2', customerId: 'someone'),
          ],
        ),
      );

      expect(_textOf(tester, 'next_doctor'), 'BS. d1');
      expect(_textOf(tester, 'next_time'), '14:00 – 14:30');
      expect(_textOf(tester, 'next_day'), startsWith('Hôm nay'));
      expect(_textOf(tester, 'cstat_upcoming'), '2');
      expect(_textOf(tester, 'cstat_pending'), '1');
      expect(_textOf(tester, 'cstat_confirmed'), '1');
      expect(find.byKey(const ValueKey('upcoming_mine2'), skipOffstage: false), findsOneWidget);
      expect(find.byKey(const ValueKey('upcoming_other'), skipOffstage: false), findsNothing);
      expect(_textOf(tester, 'tab_upcoming_badge'), '2');
      // Khung 11:00 của d2 do người khác giữ -> d2 còn 9 ca; d1 mất 14:00 (lịch của mình) -> 9 ca.
      expect(_textOf(tester, 'doctor_free_d2'), AppStrings.freeSlots(9));
      expect(_textOf(tester, 'doctor_free_d1'), AppStrings.freeSlots(9));
    });

    testWidgets('nhân viên xác nhận / từ chối -> Trang chủ khách tự đổi theo', (tester) async {
      final repo = await _pump(
        tester,
        appointments: FakeAppointmentRepository(
          initial: [appt('mine1', _today(14), doctorId: 'd1', customerId: _me)],
        ),
      );
      expect(find.descendant(
        of: find.byKey(const ValueKey('next_appointment')),
        matching: find.text(AppStrings.statusPending),
      ), findsOneWidget);

      await repo.updateStatus('mine1', AppointmentStatus.confirmed);
      await tester.pumpAndSettle();
      expect(find.descendant(
        of: find.byKey(const ValueKey('next_appointment')),
        matching: find.text(AppStrings.statusConfirmed),
      ), findsOneWidget);
      expect(_textOf(tester, 'cstat_pending'), '0');
      expect(_textOf(tester, 'cstat_confirmed'), '1');

      // Bị hủy / từ chối -> rời khỏi "sắp tới", khung của bác sĩ trống lại.
      await repo.updateStatus('mine1', AppointmentStatus.cancelled);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('no_upcoming')), findsOneWidget);
      expect(_textOf(tester, 'cstat_upcoming'), '0');
      expect(_textOf(tester, 'doctor_free_d1'), AppStrings.freeSlots(10));
    });

    testWidgets('bấm chuyên khoa -> tab Đặt lịch lọc sẵn chuyên khoa đó', (tester) async {
      await _pump(tester);
      await _tapKey(tester, 'home_spec_Da liễu');

      expect(find.text(AppStrings.bookingTitle), findsOneWidget);
      expect(_textOf(tester, 'doctor_match_count'), AppStrings.doctorMatch(1));
      expect(find.byKey(const ValueKey('doctor_card_d2')), findsOneWidget);
      expect(find.byKey(const ValueKey('doctor_card_d1')), findsNothing);
    });

    testWidgets('hết giờ làm -> báo hôm nay không còn ca trống; chưa có bác sĩ -> thông báo',
        (tester) async {
      await _pump(tester, now: _today(18));
      expect(find.text(AppStrings.noFreeToday, skipOffstage: false), findsOneWidget);

      await _pump(tester, doctors: FakeDoctorRepository());
      expect(find.text(AppStrings.doctorsEmptyCustomer), findsOneWidget);
    });

    testWidgets('lỗi tải dữ liệu -> thông báo + Thử lại; thử lại thành công', (tester) async {
      final repo = FakeAppointmentRepository()..watchError = const NetworkFailure();
      await _pump(tester, appointments: repo);
      expect(find.text(AppStrings.loadFailed, skipOffstage: false), findsWidgets);

      repo.watchError = null;
      while (find.text(AppStrings.retry, skipOffstage: false).evaluate().isNotEmpty) {
        final button = find.text(AppStrings.retry, skipOffstage: false).first;
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
      }
      expect(find.text(AppStrings.loadFailed, skipOffstage: false), findsNothing);
      expect(find.byKey(const ValueKey('no_upcoming')), findsOneWidget);
    });
  });

  group('Đặt lịch', () {
    testWidgets('danh sách bác sĩ kèm số ca trống; chọn giờ mong muốn -> chỉ còn bác sĩ trống giờ đó',
        (tester) async {
      await _pump(
        tester,
        appointments: FakeAppointmentRepository(
          initial: [appt('o1', _today(14), doctorId: 'd1', customerId: 'someone')],
        ),
      );
      await _openTab(tester, AppStrings.tabBooking);

      expect(_textOf(tester, 'doctor_match_count'), AppStrings.doctorMatch(2));
      expect(_textOf(tester, 'doctor_free_d1'), AppStrings.freeSlots(9));
      expect(_textOf(tester, 'doctor_free_d2'), AppStrings.freeSlots(10));
      expect(_textOf(tester, 'time_filter_label'), AppStrings.anyTime);

      // Chọn 14:00 – d1 đã có người đặt nên chỉ còn d2.
      await _tapKey(tester, 'time_filter');
      // Khung đã qua trong hôm nay bị khoá.
      expect(
        tester.widget<InkWell>(find.byKey(const ValueKey('time_opt_${8 * 60}'))).onTap,
        isNull,
      );
      await _tapKey(tester, 'time_opt_${14 * 60}');
      expect(_textOf(tester, 'time_filter_label'), '14:00 – 14:30');
      expect(_textOf(tester, 'doctor_match_count'), AppStrings.doctorMatch(1));
      expect(find.byKey(const ValueKey('doctor_card_d1')), findsNothing);
      expect(_textOf(tester, 'doctor_free_d2'), AppStrings.freeAt('14:00'));

      // Sang ngày mai: d1 lại trống lúc 14:00.
      await _tapKey(tester, 'day_1');
      expect(_textOf(tester, 'doctor_match_count'), AppStrings.doctorMatch(2));

      // Bỏ chọn giờ.
      await _tapKey(tester, 'time_filter_clear');
      expect(_textOf(tester, 'time_filter_label'), AppStrings.anyTime);
    });

    testWidgets('lọc chuyên khoa, tìm không dấu, không có kết quả -> xoá bộ lọc', (tester) async {
      await _pump(tester);
      await _openTab(tester, AppStrings.tabBooking);

      await _tapKey(tester, 'spec_Nội tổng quát');
      expect(find.byKey(const ValueKey('doctor_card_d1')), findsOneWidget);
      expect(find.byKey(const ValueKey('doctor_card_d2')), findsNothing);
      await _tapKey(tester, 'spec_all');
      expect(_textOf(tester, 'doctor_match_count'), AppStrings.doctorMatch(2));

      await tester.enterText(find.byKey(const ValueKey('doctor_search')), 'binh');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('doctor_card_d2')), findsOneWidget);
      expect(find.byKey(const ValueKey('doctor_card_d1')), findsNothing);

      await tester.enterText(find.byKey(const ValueKey('doctor_search')), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.noDoctorMatch), findsOneWidget);
      await _tapKey(tester, 'clear_doctor_filters');
      expect(_textOf(tester, 'doctor_match_count'), AppStrings.doctorMatch(2));
      expect(
        tester.widget<TextField>(find.byKey(const ValueKey('doctor_search'))).controller!.text,
        isEmpty,
      );
    });

    testWidgets('"Còn trống" ẩn bác sĩ đã kín lịch trong ngày', (tester) async {
      await _pump(
        tester,
        // 17:00: d1 chỉ còn khung 17:00... đã tới giờ -> hết ca; ngày mai thì còn.
        now: _today(17),
      );
      await _openTab(tester, AppStrings.tabBooking);
      expect(_textOf(tester, 'doctor_free_d1'), AppStrings.fullDay);

      await _tapKey(tester, 'only_free_doctors');
      expect(_textOf(tester, 'doctor_match_count'), AppStrings.doctorMatch(0));
      await _tapKey(tester, 'day_1');
      expect(_textOf(tester, 'doctor_match_count'), AppStrings.doctorMatch(2));
    });

    testWidgets('xem thông tin bác sĩ, chọn khung, xác nhận -> tạo lịch Chờ xác nhận + thông báo cho nhân viên',
        (tester) async {
      final notifications = FakeNotificationRepository();
      final repo = await _pump(tester, notifications: notifications);
      await _openTab(tester, AppStrings.tabBooking);
      await _tapKey(tester, 'doctor_card_d1');

      // Thông tin bác sĩ.
      expect(_textOf(tester, 'detail_doctor_name'), 'BS. Nguyễn Văn An');
      expect(_textOf(tester, 'doctor_bio'), 'Khám và điều trị các bệnh nội khoa.');
      expect(find.text(AppStrings.experience(12)), findsOneWidget);
      expect(find.textContaining('150.000 đ'), findsOneWidget);
      expect(_textOf(tester, 'detail_free_count'), AppStrings.freeSlots(10));
      // Chưa chọn giờ -> nút Đặt lịch bị khoá.
      expect(_textOf(tester, 'book_summary'), AppStrings.noSlotChosen);
      expect(
        tester.widget<FilledButton>(find.byKey(const ValueKey('book_button'))).onPressed,
        isNull,
      );
      // Buổi sáng lúc 10:00: khung 09:30 đã qua, 10:30 còn trống.
      expect(_slotEnabled(tester, 9 * 60 + 30), isFalse);
      expect(_slotEnabled(tester, 10 * 60 + 30), isTrue);

      await _tapKey(tester, 'detail_shift_afternoon');
      await _tapKey(tester, 'slot_${14 * 60}');
      expect(_textOf(tester, 'book_summary'), '14:00 – 14:30');

      await _tapKey(tester, 'book_button');
      // Bảng xác nhận lấy người khám từ hồ sơ đang đăng nhập.
      expect(_textOf(tester, 'confirm_doctor'), 'BS. Nguyễn Văn An');
      expect(_textOf(tester, 'confirm_service'), 'Khám nội tổng quát');
      expect(_textOf(tester, 'confirm_time'), '14:00 – 14:30');
      expect(_textOf(tester, 'confirm_patient'), '$_name\n$_phone');

      // Hủy ở bảng xác nhận -> chưa ghi gì.
      await _tapKey(tester, 'book_cancel');
      expect(repo.items, isEmpty);

      await _tapKey(tester, 'book_button');
      await _tapKey(tester, 'book_confirm');

      // Dữ liệu ghi vào nguồn chung đúng như Staff sẽ thấy.
      final created = repo.items.single;
      expect(created.status, AppointmentStatus.pending);
      expect(created.customerId, _me);
      expect(created.customerName, _name);
      expect(created.doctorId, 'd1');
      expect(created.doctorName, 'BS. Nguyễn Văn An');
      expect(created.serviceName, 'Khám nội tổng quát');
      expect(created.startAt, _today(14));
      expect(created.endAt, _today(14, 30));
      expect(notifications.items.single.appointmentId, created.id);

      // Quay lại danh sách, có thông báo thành công; số ca trống giảm 1.
      expect(find.text(AppStrings.bookedDone), findsOneWidget);
      expect(find.text(AppStrings.bookingTitle), findsOneWidget);
      expect(_textOf(tester, 'doctor_free_d1'), AppStrings.freeSlots(9));
      expect(_textOf(tester, 'tab_upcoming_badge'), '1');

      // Trang chủ hiện đúng lịch vừa đặt.
      await _openTab(tester, AppStrings.tabHome);
      expect(_textOf(tester, 'next_doctor'), 'BS. Nguyễn Văn An');
      expect(_textOf(tester, 'next_time'), '14:00 – 14:30');
      expect(_textOf(tester, 'cstat_pending'), '1');
    });

    testWidgets('khung của mình hiện "Của bạn"; người khác đặt mất khung đang chọn -> bỏ chọn; '
        'nhân viên từ chối -> khung trống lại', (tester) async {
      final repo = await _pump(
        tester,
        appointments: FakeAppointmentRepository(
          initial: [appt('mine1', _today(15), doctorId: 'd1', customerId: _me)],
        ),
      );
      await _openDoctorAfternoon(tester, 'd1');

      expect(_textOf(tester, 'slot_state_${15 * 60}'), AppStrings.slotMine);
      expect(_slotEnabled(tester, 15 * 60), isFalse);

      await _tapKey(tester, 'slot_${16 * 60}');
      expect(_textOf(tester, 'book_summary'), '16:00 – 16:30');

      // Một khách khác vừa đặt đúng khung 16:00.
      repo.addExternal(appt('other', _today(16), doctorId: 'd1', customerId: 'someone'));
      await tester.pumpAndSettle();
      expect(_textOf(tester, 'slot_state_${16 * 60}'), AppStrings.slotTaken);
      expect(_slotEnabled(tester, 16 * 60), isFalse);
      expect(_textOf(tester, 'book_summary'), AppStrings.noSlotChosen);

      // Nhân viên từ chối lịch đó -> khung trống lại, đặt được.
      await repo.updateStatus('other', AppointmentStatus.rejected);
      await tester.pumpAndSettle();
      expect(_slotEnabled(tester, 16 * 60), isTrue);
    });

    testWidgets('khung vừa bị đặt lúc ghi dữ liệu -> báo lỗi, không tạo lịch', (tester) async {
      final repo = await _pump(tester);
      await _openDoctorAfternoon(tester, 'd1');
      await _tapKey(tester, 'slot_${14 * 60}');
      repo.nextCreateError = const SlotTakenFailure();
      await _tapKey(tester, 'book_button');
      await _tapKey(tester, 'book_confirm');

      expect(find.text(AppStrings.errSlotTaken), findsOneWidget);
      expect(repo.items, isEmpty);
      // Vẫn ở trang bác sĩ để chọn giờ khác.
      expect(find.text(AppStrings.doctorInfo), findsOneWidget);
      expect(_textOf(tester, 'book_summary'), AppStrings.noSlotChosen);
    });

    testWidgets('mất mạng khi đặt -> báo lỗi dễ hiểu, không tạo lịch', (tester) async {
      final repo = await _pump(tester);
      await _openDoctorAfternoon(tester, 'd1');
      await _tapKey(tester, 'slot_${14 * 60}');
      repo.nextCreateError = const NetworkFailure();
      await _tapKey(tester, 'book_button');
      await _tapKey(tester, 'book_confirm');

      expect(find.text(AppStrings.errNetwork), findsOneWidget);
      expect(repo.items, isEmpty);
    });

    testWidgets('đã có lịch cùng giờ với bác sĩ khác -> không cho đặt trùng', (tester) async {
      final repo = await _pump(
        tester,
        appointments: FakeAppointmentRepository(
          initial: [appt('mine1', _today(14), doctorId: 'd2', customerId: _me)],
        ),
      );
      await _openDoctorAfternoon(tester, 'd1');
      await _tapKey(tester, 'slot_${14 * 60}');
      await _tapKey(tester, 'book_button');
      await _tapKey(tester, 'book_confirm');

      expect(find.text(AppStrings.errOwnOverlap), findsOneWidget);
      expect(repo.items.length, 1);
    });

    testWidgets('giờ mong muốn đã chọn ở danh sách được chọn sẵn khi mở trang bác sĩ', (tester) async {
      await _pump(tester);
      await _openTab(tester, AppStrings.tabBooking);
      await _tapKey(tester, 'day_1');
      await _tapKey(tester, 'time_filter');
      await _tapKey(tester, 'time_opt_${8 * 60 + 30}');
      await _tapKey(tester, 'doctor_card_d2');

      expect(_textOf(tester, 'book_summary'), '08:30 – 09:00');
      expect(
        tester.widget<FilledButton>(find.byKey(const ValueKey('book_button'))).onPressed,
        isNotNull,
      );
    });
  });

  group('Cá nhân (Khách hàng)', () {
    testWidgets('thông tin lúc tạo tài khoản hiện đúng, nhãn Khách hàng, trường trống ghi "Chưa cập nhật"',
        (tester) async {
      await _pump(tester);
      await _openTab(tester, AppStrings.tabProfile);

      expect(find.text(AppStrings.personalTitle), findsWidgets);
      expect(_textOf(tester, 'account_name'), _name);
      expect(_textOf(tester, 'account_phone'), _phone);
      expect(_textOf(tester, 'account_role'), AppStrings.roleCustomer);
      expect(_textOf(tester, 'info_full_name'), _name);
      expect(_textOf(tester, 'info_email'), AppStrings.notUpdated);
      expect(find.byKey(const ValueKey('incomplete_notice'), skipOffstage: false), findsOneWidget);
      expect(find.textContaining('medibook.local'), findsNothing);
    });

    testWidgets('thẻ Lịch hẹn của tôi cùng số liệu với Trang chủ; bấm -> tab Lịch hẹn', (tester) async {
      await _pump(
        tester,
        appointments: FakeAppointmentRepository(
          initial: [
            appt('mine1', _today(14), doctorId: 'd1', customerId: _me),
            appt('mine2', _tomorrow(9), status: AppointmentStatus.confirmed, doctorId: 'd2', customerId: _me),
            appt('other', _today(11), doctorId: 'd2', customerId: 'someone'),
          ],
        ),
      );
      final home = [
        _textOf(tester, 'cstat_upcoming'),
        _textOf(tester, 'cstat_pending'),
        _textOf(tester, 'cstat_confirmed'),
      ];
      await _openTab(tester, AppStrings.tabProfile);
      expect(
        [
          _textOf(tester, 'pstat_upcoming'),
          _textOf(tester, 'pstat_pending'),
          _textOf(tester, 'pstat_confirmed'),
        ],
        home,
      );
      expect(home, ['2', '1', '1']);

      await _tapKey(tester, 'my_appointments_card');
      expect(find.byKey(const ValueKey('cfilter_upcoming')), findsOneWidget);
      expect(_textOf(tester, 'cfilter_count_upcoming'), '2');
    });

    testWidgets('sửa họ tên -> tab Cá nhân, lời chào Trang chủ và bảng xác nhận đặt lịch cùng đổi',
        (tester) async {
      final auth = _auth();
      await _pump(tester, auth: auth);
      await _openTab(tester, AppStrings.tabProfile);

      await _tapKey(tester, 'edit_profile');
      await tester.enterText(fieldByLabel(AppStrings.fullName), 'Nguyễn Bình An');
      await tapButton(tester, AppStrings.save);

      expect(_textOf(tester, 'info_full_name'), 'Nguyễn Bình An');
      expect(auth.storedUser(_phone)!.fullName, 'Nguyễn Bình An');
      await _openTab(tester, AppStrings.tabHome);
      expect(_textOf(tester, 'greeting_name'), 'Nguyễn Bình An');

      // Đợi thông báo "đã lưu" tự tắt để nó không che thẻ bác sĩ khi bấm.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await _openDoctorAfternoon(tester, 'd1');
      await _tapKey(tester, 'slot_${14 * 60}');
      await _tapKey(tester, 'book_button');
      expect(_textOf(tester, 'confirm_patient'), 'Nguyễn Bình An\n$_phone');
    });

    testWidgets('đăng xuất rồi đăng nhập lại: dữ liệu khách hàng được nạp lại đúng', (tester) async {
      final repo = await _pump(
        tester,
        appointments: FakeAppointmentRepository(
          initial: [appt('mine1', _today(14), doctorId: 'd1', customerId: _me)],
        ),
      );
      await _openTab(tester, AppStrings.tabProfile);
      await _tapKey(tester, 'logout_button');
      await _tapKey(tester, 'logout_agree');
      expect(find.widgetWithText(FilledButton, AppStrings.login), findsOneWidget);

      await tester.enterText(fieldByLabel(AppStrings.phone), _phone);
      await tester.enterText(fieldByLabel(AppStrings.password), 'Khach@123');
      await tapButton(tester, AppStrings.login);
      expect(_textOf(tester, 'next_time'), '14:00 – 14:30');
      expect(repo.items.length, 1);
    });
  });
}
