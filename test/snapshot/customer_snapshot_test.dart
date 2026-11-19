// Công cụ chụp ảnh giao diện khu vực Khách hàng (Trang chủ, Đặt lịch, Thông tin bác sĩ, Cá nhân)
// bằng dữ liệu giả – phục vụ kiểm tra bố cục / báo cáo.
// Chạy:  flutter test test/snapshot --dart-define=SNAPSHOT_DIR=<thư mục lưu ảnh> --dart-define=FONT_DIR=<thư mục phông>
// Không truyền SNAPSHOT_DIR thì test tự bỏ qua.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/app/app.dart';
import 'package:medibook/core/constants/app_strings.dart';
import 'package:medibook/features/appointments/domain/entities/appointment_status.dart';
import 'package:medibook/features/booking/presentation/widgets/doctor_card.dart';
import 'package:medibook/features/home/domain/demo_data.dart';

import '../mocks/fake_alerts.dart';
import '../mocks/fake_clinic_repositories.dart';
import '../mocks/fake_repositories.dart';

const _outDir = String.fromEnvironment('SNAPSHOT_DIR');
const _fontDir = String.fromEnvironment('FONT_DIR');

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    final bytes = File('$_fontDir/$f').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

void main() {
  testWidgets('chụp ảnh khu vực Khách hàng', skip: _outDir.isEmpty, (tester) async {
    await _loadFont('Roboto', ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf', 'roboto-black.ttf']);
    await _loadFont('MaterialIcons', ['materialicons-regular.otf']);

    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final now = DateTime(2026, 11, 14, 10, 10);
    final data = DemoData.build(now);
    final auth = FakeAuthRepository()
      ..seed(phone: '0912345678', password: 'x', fullName: 'Nguyễn Văn Bình', signedIn: true);
    final key = GlobalKey();
    final doctors = data.doctors;

    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MediBookApp(
          authRepository: auth,
          profileRepository: FakeProfileRepository(auth),
          appointmentRepository: FakeAppointmentRepository(
            initial: [
              ...data.appointments,
              appt('mine1', DateTime(2026, 11, 14, 15, 30), doctorId: doctors[1].id, customerId: 'u0')
                  .copyWith(status: AppointmentStatus.confirmed),
              appt('mine2', DateTime(2026, 11, 16, 9), doctorId: doctors[2].id, customerId: 'u0'),
              appt('mine3', DateTime(2026, 11, 18, 14), doctorId: doctors[0].id, customerId: 'u0'),
            ],
          ),
          notificationRepository: FakeNotificationRepository(),
          doctorRepository: FakeDoctorRepository(initial: doctors),
          clock: () => now,
          localNotifications: FakeLocalNotifications(),
          alertStore: MemoryAlertStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> shoot(String name) async {
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$_outDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    Future<void> tapKey(String name) async {
      await tester.ensureVisible(find.byKey(ValueKey(name), skipOffstage: false).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey(name)).first);
      await tester.pumpAndSettle();
    }

    Future<void> openTab(String label) async {
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
      await tester.pumpAndSettle();
    }

    await shoot('c1_home');
    await tester.drag(find.byKey(const ValueKey('customer_home_list')), const Offset(0, -520));
    await tester.pumpAndSettle();
    await shoot('c1b_home_scrolled');

    await openTab(AppStrings.tabBooking);
    await shoot('c2_booking');
    await tapKey('time_filter');
    await shoot('c3_time_sheet');
    await tapKey('time_opt_${14 * 60}');
    await shoot('c4_booking_time_chosen');

    await tester.tap(find.byType(DoctorCard).first);
    await tester.pumpAndSettle();
    await shoot('c5_doctor_detail');
    await tester.drag(find.byKey(const ValueKey('doctor_detail_list')), const Offset(0, -400));
    await tester.pumpAndSettle();
    await shoot('c5b_doctor_detail_slots');
    await tapKey('book_button');
    await shoot('c6_confirm_sheet');
    await tapKey('book_cancel');
    await tester.pageBack();
    await tester.pumpAndSettle();

    await openTab(AppStrings.tabProfile);
    await shoot('c7_profile');
  });
}
