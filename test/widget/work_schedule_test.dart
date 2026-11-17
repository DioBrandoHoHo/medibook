import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/constants/app_strings.dart';
import 'package:medibook/core/errors/app_failure.dart';
import 'package:medibook/features/appointments/domain/entities/appointment.dart';
import 'package:medibook/features/appointments/domain/entities/appointment_status.dart';
import 'package:medibook/features/auth/domain/entities/user_role.dart';
import 'package:medibook/features/booking/domain/entities/doctor.dart';
import 'package:medibook/features/home/domain/demo_data.dart';

import '../../tool/seed_data.dart' show seedDoctors;
import '../mocks/fake_clinic_repositories.dart';
import '../mocks/fake_repositories.dart';
import 'test_helpers.dart';

/// "Bây giờ" mặc định = Thứ Bảy 14/11/2026 10:00.
final _now = DateTime(2026, 11, 14, 10);
DateTime _today(int h, [int m = 0]) => DateTime(2026, 11, 14, h, m);
DateTime _tomorrow(int h, [int m = 0]) => DateTime(2026, 11, 15, h, m);

const _doctors = [
  Doctor(id: 'd1', name: 'BS. Nguyễn Văn An', specialty: 'Nội tổng quát', room: 'Phòng 101'),
  Doctor(id: 'd2', name: 'BS. Trần Thị Bình', specialty: 'Da liễu', room: 'Phòng 102'),
];

List<Appointment> _sample() => [
      appt('conf', _today(8), status: AppointmentStatus.confirmed, name: 'Lê Văn Hùng', doctorId: 'd1'),
      appt('pend', _today(10, 30), name: 'Trần Văn Minh', doctorId: 'd1'),
      appt('canc', _today(11), status: AppointmentStatus.cancelled, name: 'Đỗ Thị Lan', doctorId: 'd1'),
      appt('aft', _today(14), status: AppointmentStatus.confirmed, name: 'Bùi Thu Hà', doctorId: 'd1'),
      appt('tom', _tomorrow(8), name: 'Phạm Thị Bích', doctorId: 'd2'),
      // Lịch không gắn bác sĩ: không được xuất hiện ở tab này.
      appt('nodoc', _today(10), status: AppointmentStatus.confirmed, name: 'Khách Lẻ'),
    ];

Future<void> _pumpSchedule(
  WidgetTester tester, {
  required FakeAppointmentRepository appointments,
  FakeDoctorRepository? doctors,
  DateTime? now,
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
    doctorRepo: doctors ?? FakeDoctorRepository(initial: _doctors),
    clock: () => now ?? _now,
  );
  await _openTab(tester, AppStrings.tabSchedule);
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
  await tester.pumpAndSettle();
}

/// Đọc chữ theo key, kể cả phần tử đã dựng nhưng nằm ngoài màn hình.
String _textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key), skipOffstage: false)).data!;

String _slot(WidgetTester tester, String doctorId, String hhmm) =>
    _textOf(tester, 'slot_label_${doctorId}_$hhmm');

Future<void> _tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key), skipOffstage: false));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

/// Gõ vào ô tìm bác sĩ (cuộn lên cho thấy ô trước).
Future<void> _search(WidgetTester tester, String text) async {
  final field = find.byKey(const ValueKey('schedule_search'), skipOffstage: false);
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('hiện bác sĩ kèm thông tin, lưới 8 khung buổi Sáng và số tổng hợp của hôm nay',
      (tester) async {
    await _pumpSchedule(tester, appointments: FakeAppointmentRepository(initial: _sample()));

    expect(_textOf(tester, 'schedule_day_label'), 'Hôm nay, 14/11/2026');
    expect(_textOf(tester, 'doctor_count'), AppStrings.doctorCount(2));
    expect(find.text('BS. Nguyễn Văn An'), findsOneWidget);
    expect(find.text('Nội tổng quát  •  Phòng 101'), findsOneWidget);

    // Lưới buổi Sáng của BS. An lúc 10:00.
    expect(_slot(tester, 'd1', '0730'), AppStrings.slotPast);
    expect(_slot(tester, 'd1', '0800'), AppStrings.slotBooked); // đã qua nhưng có lịch
    expect(_slot(tester, 'd1', '0930'), AppStrings.slotPast);
    expect(_slot(tester, 'd1', '1000'), AppStrings.slotFree); // lịch không gắn bác sĩ không chiếm
    expect(_slot(tester, 'd1', '1030'), AppStrings.slotPending);
    expect(_slot(tester, 'd1', '1100'), AppStrings.slotFree); // lịch đã hủy không chiếm khung
    expect(find.byKey(const ValueKey('slot_d1_1330'), skipOffstage: false), findsNothing);
    expect(_textOf(tester, 'free_d1'), AppStrings.freeOf(2, 8));
    expect(_textOf(tester, 'free_d2'), AppStrings.freeOf(3, 8));

    // Tổng hợp cả hai buổi của cả hai bác sĩ: 32 khung − 9 đã qua − 2 đã đặt − 1 chờ.
    // (BS. An có 4 khung sáng đã qua vì khung 08:00 có lịch; BS. Bình có 5.)
    expect(_textOf(tester, 'sum_free'), '20');
    expect(_textOf(tester, 'sum_pending'), '1');
    expect(_textOf(tester, 'sum_booked'), '2');
  });

  testWidgets('đổi Sáng / Chiều riêng cho từng bác sĩ', (tester) async {
    await _pumpSchedule(tester, appointments: FakeAppointmentRepository(initial: _sample()));

    await _tapKey(tester, 'shift_d1_afternoon');
    expect(_slot(tester, 'd1', '1330'), AppStrings.slotFree);
    expect(_slot(tester, 'd1', '1400'), AppStrings.slotBooked);
    expect(_slot(tester, 'd1', '1700'), AppStrings.slotFree);
    expect(find.byKey(const ValueKey('slot_d1_0730'), skipOffstage: false), findsNothing);
    expect(_textOf(tester, 'free_d1'), AppStrings.freeOf(7, 8));
    // Bác sĩ còn lại vẫn đang xem buổi Sáng.
    expect(_slot(tester, 'd2', '0730'), AppStrings.slotPast);

    await _tapKey(tester, 'shift_d1_morning');
    expect(_slot(tester, 'd1', '0800'), AppStrings.slotBooked);
  });

  testWidgets('đổi ngày: lưới và số tổng hợp theo ngày được chọn', (tester) async {
    await _pumpSchedule(tester, appointments: FakeAppointmentRepository(initial: _sample()));

    await _tapKey(tester, 'day_1');
    expect(_textOf(tester, 'schedule_day_label'), 'Ngày mai, 15/11/2026');
    expect(_slot(tester, 'd2', '0800'), AppStrings.slotPending);
    expect(_slot(tester, 'd1', '0800'), AppStrings.slotFree); // lịch hôm nay không dính sang
    expect(_slot(tester, 'd1', '0730'), AppStrings.slotFree); // ngày mai không có khung "Đã qua"
    expect(_textOf(tester, 'free_d1'), AppStrings.freeOf(8, 8));
    expect(_textOf(tester, 'sum_free'), '31');
    expect(_textOf(tester, 'sum_pending'), '1');
    expect(_textOf(tester, 'sum_booked'), '0');

    await _tapKey(tester, 'day_0');
    expect(_textOf(tester, 'schedule_day_label'), 'Hôm nay, 14/11/2026');
    expect(_slot(tester, 'd1', '0800'), AppStrings.slotBooked);
  });

  testWidgets('sau giờ sáng thì mở sẵn buổi Chiều; hết giờ làm -> lọc "còn trống" báo không còn ai',
      (tester) async {
    await _pumpSchedule(
      tester,
      appointments: FakeAppointmentRepository(initial: _sample()),
      now: _today(17, 40),
    );

    // Mặc định là buổi Chiều.
    expect(_slot(tester, 'd1', '1400'), AppStrings.slotBooked);
    expect(_slot(tester, 'd1', '1700'), AppStrings.slotPast);
    expect(_textOf(tester, 'sum_free'), '0');

    await _tapKey(tester, 'only_free');
    expect(find.text(AppStrings.noFreeDoctors), findsOneWidget);
    expect(_textOf(tester, 'doctor_count'), AppStrings.doctorCount(0));
    expect(find.text('BS. Nguyễn Văn An'), findsNothing);

    // Ngày mai thì ai cũng còn trống.
    await _tapKey(tester, 'day_1');
    expect(_textOf(tester, 'doctor_count'), AppStrings.doctorCount(2));
  });

  testWidgets('bấm khung có lịch -> mở đúng Chi tiết lịch hẹn; khung trống không bấm được',
      (tester) async {
    await _pumpSchedule(tester, appointments: FakeAppointmentRepository(initial: _sample()));

    await _tapKey(tester, 'slot_d1_1100'); // khung Trống
    expect(find.text(AppStrings.appointmentDetail), findsNothing);

    await _tapKey(tester, 'slot_d1_1030');
    expect(find.text(AppStrings.appointmentDetail), findsOneWidget);
    expect(find.text('Trần Văn Minh'), findsOneWidget);
    expect(find.text('BS. d1'), findsOneWidget); // dòng "Bác sĩ" ở Chi tiết
    expect(find.text(AppStrings.notePending), findsOneWidget);
  });

  testWidgets('xác nhận ở Chi tiết / từ chối ở Lịch đặt / có lịch mới -> khung đổi theo',
      (tester) async {
    final repo = FakeAppointmentRepository(initial: _sample());
    await _pumpSchedule(tester, appointments: repo);
    expect(_slot(tester, 'd1', '1030'), AppStrings.slotPending);

    // Xác nhận từ màn Chi tiết mở ra từ khung giờ.
    await _tapKey(tester, 'slot_d1_1030');
    await _tapKey(tester, 'confirm_button');
    await _tapKey(tester, 'dialog_agree');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(_slot(tester, 'd1', '1030'), AppStrings.slotBooked);
    expect(_textOf(tester, 'sum_pending'), '0');
    expect(_textOf(tester, 'sum_booked'), '3');

    // Từ chối lịch ngày mai ở tab Lịch đặt -> khung ngày mai trở lại Trống.
    await _openTab(tester, AppStrings.tabStaffBookings);
    await _tapKey(tester, 'filter_pending');
    await _tapKey(tester, 'quick_reject_tom');
    await _tapKey(tester, 'dialog_agree');
    await _openTab(tester, AppStrings.tabSchedule);
    await _tapKey(tester, 'day_1');
    expect(_slot(tester, 'd2', '0800'), AppStrings.slotFree);

    // Khách đặt lịch mới với BS. Bình sáng mai -> khung thành Chờ, không cần tải lại.
    await repo.create(
      customerId: 'c9',
      customerName: 'Lê An',
      serviceName: 'Khám da liễu',
      startAt: _tomorrow(9),
      endAt: _tomorrow(9, 30),
      doctorId: 'd2',
      doctorName: 'BS. Trần Thị Bình',
    );
    await tester.pumpAndSettle();
    expect(_slot(tester, 'd2', '0900'), AppStrings.slotPending);

    // Khách tự hủy lịch đã xác nhận -> khung trống lại.
    await _tapKey(tester, 'day_0');
    await repo.updateStatus('conf', AppointmentStatus.cancelled);
    await tester.pumpAndSettle();
    expect(_slot(tester, 'd1', '0800'), AppStrings.slotPast);
  });

  testWidgets('hai lịch còn hiệu lực trùng khung -> hiện Đã đặt kèm dấu cảnh báo', (tester) async {
    await _pumpSchedule(
      tester,
      appointments: FakeAppointmentRepository(initial: [
        appt('p', _today(10, 30), doctorId: 'd1'),
        appt('c', _today(10, 30), status: AppointmentStatus.confirmed, doctorId: 'd1'),
      ]),
    );
    expect(_slot(tester, 'd1', '1030'), AppStrings.slotBooked);
    expect(find.byKey(const ValueKey('slot_conflict_d1_1030'), skipOffstage: false), findsOneWidget);
    expect(find.byKey(const ValueKey('slot_conflict_d1_1100'), skipOffstage: false), findsNothing);
  });

  testWidgets('chưa có bác sĩ -> thông báo + gợi ý; app không còn nút tạo dữ liệu mẫu', (tester) async {
    await _pumpSchedule(
      tester,
      appointments: FakeAppointmentRepository(),
      doctors: FakeDoctorRepository(),
    );
    expect(find.text(AppStrings.doctorsEmpty), findsOneWidget);
    expect(find.text(AppStrings.doctorsEmptyHint), findsOneWidget);
    await _openTab(tester, AppStrings.tabOverview);
    expect(find.byKey(const ValueKey('seed_demo'), skipOffstage: false), findsNothing);
  });

  testWidgets('đủ 5 bác sĩ (dữ liệu có sẵn) -> hiện đủ thẻ, đếm khung đã đặt hôm nay', (tester) async {
    final data = DemoData.build(_now);
    await _pumpSchedule(
      tester,
      appointments: FakeAppointmentRepository(initial: data.appointments),
      doctors: FakeDoctorRepository(initial: data.doctors),
    );
    expect(find.text(AppStrings.doctorsEmpty), findsNothing);
    expect(_textOf(tester, 'doctor_count'), AppStrings.doctorCount(5));
    // Đã có khung được đặt trong hôm nay.
    expect(int.parse(_textOf(tester, 'sum_booked')), greaterThan(0));
    // Danh sách dài hơn màn hình -> cuộn tới thẻ của bác sĩ.
    await tester.scrollUntilVisible(find.text('BS. Trần Thị Bình'), 200,
        scrollable: find
            .descendant(of: find.byKey(const ValueKey('schedule_list')), matching: find.byType(Scrollable))
            .first);
    expect(find.text('BS. Trần Thị Bình'), findsOneWidget);
  });

  testWidgets('20 bác sĩ: lọc theo khoa, tìm không dấu, tổng hợp theo danh sách đang lọc, xoá bộ lọc',
      (tester) async {
    await _pumpSchedule(
      tester,
      appointments: FakeAppointmentRepository(),
      doctors: FakeDoctorRepository(initial: seedDoctors),
    );
    expect(_textOf(tester, 'doctor_count'), AppStrings.doctorCount(20));
    final freeAll = int.parse(_textOf(tester, 'sum_free'));

    // Chọn khoa Da liễu (4 bác sĩ): danh sách + thẻ tổng hợp chỉ tính 4 người.
    await _tapKey(tester, 'sched_spec_Da liễu');
    expect(_textOf(tester, 'doctor_count'), AppStrings.doctorCount(4));
    expect(int.parse(_textOf(tester, 'sum_free')), freeAll * 4 ~/ 20);
    expect(find.byKey(const ValueKey('doctor_seed_d10'), skipOffstage: false), findsOneWidget);
    expect(find.byKey(const ValueKey('doctor_demo_d01'), skipOffstage: false), findsNothing);

    // Bấm lại -> bỏ chọn khoa. Tìm "tuan" (không dấu) -> BS. Đặng Minh Tuấn.
    await _tapKey(tester, 'sched_spec_Da liễu');
    expect(_textOf(tester, 'doctor_count'), AppStrings.doctorCount(20));
    await _search(tester, 'tuan');
    expect(_textOf(tester, 'doctor_count'), AppStrings.doctorCount(1));
    expect(find.text('BS. Đặng Minh Tuấn', skipOffstage: false), findsOneWidget);

    // Tìm theo phòng.
    await _search(tester, 'phòng 20');
    expect(_textOf(tester, 'doctor_count'), AppStrings.doctorCount(7)); // 201–207

    // Không ai khớp -> thông báo + Xoá bộ lọc.
    await _search(tester, 'zzz');
    expect(find.text(AppStrings.noDoctorMatch), findsOneWidget);
    await _tapKey(tester, 'schedule_clear_filters');
    expect(_textOf(tester, 'doctor_count'), AppStrings.doctorCount(20));
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('schedule_search'), skipOffstage: false))
          .controller!
          .text,
      isEmpty,
    );
  });

  testWidgets('lỗi tải danh sách bác sĩ -> thông báo + Thử lại; thử lại thành công', (tester) async {
    final doctors = FakeDoctorRepository(initial: _doctors)..watchError = const NetworkFailure();
    await _pumpSchedule(
      tester,
      appointments: FakeAppointmentRepository(initial: _sample()),
      doctors: doctors,
    );
    expect(find.text(AppStrings.loadFailed), findsOneWidget);
    expect(find.text(AppStrings.errNetwork), findsOneWidget);

    doctors.watchError = null;
    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.loadFailed), findsNothing);
    expect(_textOf(tester, 'doctor_count'), AppStrings.doctorCount(2));
  });
}
