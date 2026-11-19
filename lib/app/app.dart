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
import '../features/notifications/data/alert_store.dart';
import '../features/notifications/data/local_notifications.dart';
import '../features/notifications/domain/repositories/notification_repository.dart';
import '../features/notifications/presentation/controllers/customer_alerts_controller.dart';
import '../features/notifications/presentation/controllers/notifications_controller.dart';
import '../features/profile/data/avatar_picker.dart';
import '../features/profile/domain/repositories/profile_repository.dart';
import 'router/app_router.dart';

/// Widget gốc.
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
    this.localNotifications,
    this.alertStore,
  });

  final AuthRepository authRepository;
  final ProfileRepository profileRepository;
  final AppointmentRepository appointmentRepository;
  final NotificationRepository notificationRepository;
  final DoctorRepository doctorRepository;

  /// Nguồn thời gian.
  final DateTime Function()? clock;

  /// Chọn + xử lý ảnh đại diện.
  final AvatarPicker? avatarPicker;

  /// Thông báo / nhắc lịch của khách hàng.
  final LocalNotifications? localNotifications;
  final AlertStore? alertStore;

  @override
  State<MediBookApp> createState() => _MediBookAppState();
}

class _MediBookAppState extends State<MediBookApp> {
  late final AuthController _auth = AuthController(widget.authRepository);
  late final GoRouter _router = createAppRouter(_auth);

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
  late final CustomerAlertsController _customerAlerts = CustomerAlertsController(
    widget.localNotifications ?? PluginLocalNotifications(),
    widget.alertStore ?? PrefsAlertStore(),
  );

  @override
  void dispose() {
    _router.dispose();
    _auth.dispose();
    _appointments.dispose();
    _notifications.dispose();
    _doctors.dispose();
    _busySlots.dispose();
    _customerAlerts.dispose();
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
        ChangeNotifierProvider<CustomerAlertsController>.value(value: _customerAlerts),
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
