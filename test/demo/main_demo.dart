// BẢN XEM THỬ GIAO DIỆN – KHÔNG dùng Firebase.
// Chạy:  flutter run -t test/demo/main_demo.dart
//
// App mở thẳng khu vực Nhân viên (đã đăng nhập sẵn), dữ liệu mẫu lưu TRONG BỘ NHỚ (repository giả của bộ test).
// Có sẵn 2 tài khoản giả (chỉ có trong bộ nhớ của bản xem thử, mật khẩu đều là Demo@123):
//   Nhân viên: 0901234567
//   Khách hàng: 0912345678
// Đăng ký tài khoản mới cũng được. Tắt app là mất dữ liệu.
// Thử khu vực Khách hàng (Trang chủ, Đặt lịch, Cá nhân): tab Tài khoản -> Đăng xuất -> đăng nhập 0912345678.
// Bản chính thức vẫn là lib/main.dart (dùng Firebase).
import 'package:flutter/material.dart';
import 'package:medibook/app/app.dart';
import 'package:medibook/features/auth/domain/entities/user_role.dart';
import 'package:medibook/features/home/domain/demo_data.dart';

import '../mocks/fake_clinic_repositories.dart';
import '../mocks/fake_repositories.dart';

const _asCustomer = bool.fromEnvironment('CUSTOMER');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final data = DemoData.build(DateTime.now());
  final auth = FakeAuthRepository()
    ..seed(
      phone: '0901234567',
      password: 'Demo@123',
      fullName: 'Trần Thu Trang',
      role: UserRole.staff,
      // Mặc định mở app là vào thẳng khu vực nhân viên.
      signedIn: !_asCustomer,
    )
    ..seed(
      phone: '0912345678',
      password: 'Demo@123',
      fullName: 'Nguyễn Văn Bình',
      profilePromptDismissed: true,
      // Chạy kèm --dart-define=CUSTOMER=true để mở thẳng khu vực khách hàng.
      signedIn: _asCustomer,
    );
  final notifications = FakeNotificationRepository(initial: data.notifications);
  runApp(
    MediBookApp(
      authRepository: auth,
      profileRepository: FakeProfileRepository(auth),
      appointmentRepository: FakeAppointmentRepository(
        initial: data.appointments,
        notifications: notifications,
      ),
      notificationRepository: notifications,
      doctorRepository: FakeDoctorRepository(initial: data.doctors),
    ),
  );
}
