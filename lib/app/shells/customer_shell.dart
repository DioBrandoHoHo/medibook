import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_date_utils.dart';
import '../../features/appointments/presentation/controllers/appointments_controller.dart';
import '../../features/appointments/presentation/screens/customer_appointment_detail_screen.dart';
import '../../features/appointments/presentation/screens/customer_appointments_screen.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/booking/presentation/controllers/busy_slots_controller.dart';
import '../../features/booking/presentation/controllers/doctors_controller.dart';
import '../../features/booking/presentation/screens/booking_screen.dart';
import '../../features/home/domain/customer_home_summary.dart';
import '../../features/home/presentation/screens/customer_home_screen.dart';
import '../../features/notifications/presentation/controllers/customer_alerts_controller.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import 'customer_nav_controller.dart';

/// Khung điều hướng 4 tab của Customer.
class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key});

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> with WidgetsBindingObserver {
  final _nav = CustomerNavController();
  late final AppointmentsController _appointments;
  late final DoctorsController _doctors;
  late final BusySlotsController _busySlots;
  late final CustomerAlertsController _alerts;
  StreamSubscription<String>? _openSub;
  Timer? _clockTimer;

  static const _pages = <Widget>[
    CustomerHomeScreen(),
    BookingScreen(),
    CustomerAppointmentsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    final userId = context.read<AuthController>().currentUser?.id ?? '';
    _appointments = context.read<AppointmentsController>()..start(customerId: userId);
    _doctors = context.read<DoctorsController>()..start();
    _busySlots = context.read<BusySlotsController>()
      ..start(AppDateUtils.dayOnly(_appointments.now));
    _alerts = context.read<CustomerAlertsController>();
    _openSub = _alerts.openRequests.listen(_openAppointment);
    unawaited(_alerts.start(userId, _appointments));
    WidgetsBinding.instance.addObserver(this);
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) => _appointments.refreshClock());
  }

  /// Mở lại app từ nền.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _appointments.refreshClock();
    unawaited(_alerts.refreshSystemStatus());
    context.read<AuthController>().checkPendingRecovery();
  }

  /// Bấm vào thông báo lịch hẹn.
  void _openAppointment(String appointmentId) {
    if (!mounted) return;
    _nav.selectTab(CustomerNavController.appointmentsTab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) CustomerAppointmentDetailScreen.open(context, appointmentId);
    });
  }

  void _onTabSelected(int index) {
    _nav.selectTab(index);
    _appointments.refreshClock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    _openSub?.cancel();
    _alerts.stop();
    _appointments.stop();
    _doctors.stop();
    _busySlots.stop();
    _nav.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CustomerNavController>.value(
      value: _nav,
      child: ListenableBuilder(
        listenable: Listenable.merge([_nav, _appointments]),
        builder: (context, _) => Scaffold(
          body: IndexedStack(index: _nav.index, children: _pages),
          bottomNavigationBar: NavigationBarTheme(
            data: NavigationBarThemeData(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              height: 68,
              indicatorColor: AppColors.primaryLight,
              iconTheme: WidgetStateProperty.resolveWith(
                (states) => IconThemeData(color: _tabColor(states)),
              ),
              labelTextStyle: WidgetStateProperty.resolveWith(
                (states) => TextStyle(
                  fontSize: 12,
                  color: _tabColor(states),
                  fontWeight:
                      states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: NavigationBar(
                selectedIndex: _nav.index,
                onDestinationSelected: _onTabSelected,
                destinations: [
                  const NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: AppStrings.tabHome,
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.add_circle_outline),
                    selectedIcon: Icon(Icons.add_circle),
                    label: AppStrings.tabBooking,
                  ),
                  NavigationDestination(
                    icon: _UpcomingBadge(
                      count: _upcomingCount,
                      child: const Icon(Icons.event_note_outlined),
                    ),
                    selectedIcon: _UpcomingBadge(
                      count: _upcomingCount,
                      child: const Icon(Icons.event_note),
                    ),
                    label: AppStrings.tabAppointments,
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: AppStrings.tabProfile,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Số lịch sắp tới.
  int get _upcomingCount =>
      CustomerHomeSummary.from(_appointments.items, _appointments.now).upcomingTotal;

  static Color _tabColor(Set<WidgetState> states) =>
      states.contains(WidgetState.selected) ? AppColors.primary : AppColors.textSecondary;
}

/// Chấm số lịch sắp tới trên icon tab Lịch hẹn.
class _UpcomingBadge extends StatelessWidget {
  const _UpcomingBadge({required this.count, required this.child});

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: count > 0,
      backgroundColor: AppColors.primary,
      label: Text('$count', key: const ValueKey('tab_upcoming_badge')),
      child: child,
    );
  }
}
