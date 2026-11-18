import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../features/appointments/domain/repositories/appointment_repository.dart';
import '../features/appointments/presentation/controllers/appointments_controller.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/booking/domain/repositories/doctor_repository.dart';
import '../features/booking/presentation/controllers/busy_slots_controller.dart';
import '../features/booking/presentation/controllers/doctors_controller.dart';
import '../features/notifications/domain/repositories/notification_repository.dart';
import '../features/notifications/presentation/controllers/notifications_controller.dart';
import '../features/profile/data/avatar_picker.dart';
import '../features/profile/domain/repositories/profile_repository.dart';
import 'router/app_router.dart';

/// Widget gốc. Repository được truyền vào (Firebase khi chạy thật, Fake khi test).
class MediBookApp extends StatefulWidget {
  const MediBookApp({
    super.key,
    required this.authRepository,
    required this.profileRepository,
    required this.appointmentRepository,
    required this.notificationRepository,
    required this.doctorRepository,
    this.clock,
    this.avatarPicker,
  });

  final AuthRepository authRepository;
  final ProfileRepository profileRepository;
  final AppointmentRepository appointmentRepository;
  final NotificationRepository notificationRepository;
  final DoctorRepository doctorRepository;

  /// Nguồn thời gian (mặc định giờ thiết bị; test truyền giờ cố định).
  final DateTime Function()? clock;

  /// Chọn + xử lý ảnh đại diện (mặc định thư viện ảnh của điện thoại; test truyền bản giả).
  final AvatarPicker? avatarPicker;

  @override
  State<MediBookApp> createState() => _MediBookAppState();
}

class _MediBookAppState extends State<MediBookApp> {
  late final AuthController _auth = AuthController(widget.authRepository);
  late final GoRouter _router = createAppRouter(_auth);

  // Controller dữ liệu dùng chung. Chúng chỉ bắt đầu lắng nghe khi StaffShell / CustomerShell
  // gọi start(): Staff nghe toàn bộ lịch hẹn, Customer chỉ nghe lịch của mình + khung giờ bận.
  late final AppointmentsController _appointments = AppointmentsController(
    widget.appointmentRepository,
    clock: widget.clock,
  );
  late final NotificationsController _notifications = NotificationsController(
    widget.notificationRepository,
  );
  late final DoctorsController _doctors = DoctorsController(widget.doctorRepository);
  late final BusySlotsController _busySlots = BusySlotsController(widget.appointmentRepository);
  late final AvatarPicker _avatarPicker = widget.avatarPicker ?? ImagePickerAvatarPicker();

  @override
  void dispose() {
    _router.dispose();
    _auth.dispose();
    _appointments.dispose();
    _notifications.dispose();
    _doctors.dispose();
    _busySlots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthRepository>.value(value: widget.authRepository),
        Provider<ProfileRepository>.value(value: widget.profileRepository),
        Provider<AppointmentRepository>.value(value: widget.appointmentRepository),
        Provider<NotificationRepository>.value(value: widget.notificationRepository),
        Provider<DoctorRepository>.value(value: widget.doctorRepository),
        Provider<AvatarPicker>.value(value: _avatarPicker),
        ChangeNotifierProvider<AuthController>.value(value: _auth),
        ChangeNotifierProvider<AppointmentsController>.value(value: _appointments),
        ChangeNotifierProvider<NotificationsController>.value(value: _notifications),
        ChangeNotifierProvider<DoctorsController>.value(value: _doctors),
        ChangeNotifierProvider<BusySlotsController>.value(value: _busySlots),
      ],
      child: MaterialApp.router(
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: _router,
      ),
    );
  }
}
