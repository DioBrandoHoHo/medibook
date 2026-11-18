// Công cụ chụp ảnh giao diện Trang chủ Staff + Lịch đặt + Chi tiết bằng dữ liệu giả (phục vụ kiểm tra bố cục / báo cáo).
// Chạy:  flutter test test/snapshot --dart-define=SNAPSHOT_DIR=<thư mục lưu ảnh>
// Không truyền SNAPSHOT_DIR thì test tự bỏ qua.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/app/app.dart';
import 'package:medibook/features/auth/domain/entities/user_role.dart';
import 'package:medibook/features/home/domain/demo_data.dart';

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
  testWidgets('chụp ảnh khu vực Staff', skip: _outDir.isEmpty, (tester) async {
    await _loadFont('Roboto', ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf', 'roboto-black.ttf']);
    await _loadFont('MaterialIcons', ['materialicons-regular.otf']);

    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final now = DateTime(2026, 11, 14, 10, 10);
    final data = DemoData.build(now);
    final auth = FakeAuthRepository()
      ..seed(phone: '0900000001', password: 'x', fullName: 'Trần Thu Trang', role: UserRole.staff, signedIn: true);
    final key = GlobalKey();

    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MediBookApp(
          authRepository: auth,
          profileRepository: FakeProfileRepository(auth),
          appointmentRepository: FakeAppointmentRepository(initial: data.appointments),
          notificationRepository: FakeNotificationRepository(initial: data.notifications),
          doctorRepository: FakeDoctorRepository(initial: data.doctors),
          clock: () => now,
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

    await shoot('1_home');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -420));
    await tester.pumpAndSettle();
    await shoot('1b_home_scrolled');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 600));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bell_button')));
    await tester.pumpAndSettle();
    await shoot('2_popup');
    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('see_all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('see_all')));
    await tester.pumpAndSettle();
    await shoot('3_bookings_all');
    await tester.tap(find.byKey(const ValueKey('filter_today')));
    await tester.pumpAndSettle();
    await shoot('3b_bookings_today');
    await tester.tap(find.byKey(const ValueKey('filter_pending')));
    await tester.pumpAndSettle();
    await shoot('4_bookings_pending');
    await tester.tap(find.byKey(const ValueKey('quick_confirm_demo_05')));
    await tester.pumpAndSettle();
    await shoot('4b_confirm_dialog');
    await tester.tap(find.byKey(const ValueKey('dialog_cancel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('status_filter_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('status_option_confirmed')));
    await tester.pumpAndSettle();
    await shoot('5_status_sheet');
    await tester.tap(find.byKey(const ValueKey('status_apply')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('search_button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('search_field')), 'thi');
    await tester.pumpAndSettle();
    await shoot('6_search_and_status');
    await tester.tap(find.byKey(const ValueKey('filter_pending')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('search_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('appointment_demo_05')));
    await tester.pumpAndSettle();
    await shoot('7_detail_pending');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filter_all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('appointment_demo_02')));
    await tester.pumpAndSettle();
    await shoot('8_detail_cancelled');
  });
}
