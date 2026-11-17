import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../features/appointments/presentation/controllers/appointments_controller.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/booking/presentation/controllers/doctors_controller.dart';
import '../../features/home/presentation/screens/staff_home_screen.dart';
import '../../features/notifications/presentation/controllers/notifications_controller.dart';
import '../../features/profile/presentation/screens/staff_account_screen.dart';
import '../../features/schedule/presentation/screens/work_schedule_screen.dart';
import '../../features/staff_bookings/presentation/screens/staff_bookings_screen.dart';
import 'staff_nav_controller.dart';

/// Khung điều hướng 4 tab của Staff: Tổng quan / Lịch đặt / Lịch làm việc / Tài khoản.
///
/// Khi Staff vào khu vực này, shell bắt đầu lắng nghe lịch hẹn + thông báo;
/// khi rời đi (đăng xuất) thì ngừng lắng nghe.
class StaffShell extends StatefulWidget {
  const StaffShell({super.key});

  @override
  State<StaffShell> createState() => _StaffShellState();
}

class _StaffShellState extends State<StaffShell> with WidgetsBindingObserver {
  final _nav = StaffNavController();
  late final AppointmentsController _appointments;
  late final NotificationsController _notifications;
  late final DoctorsController _doctors;
  Timer? _clockTimer;

  static const _pages = <Widget>[
    StaffHomeScreen(),
    StaffBookingsScreen(),
    WorkScheduleScreen(),
    StaffAccountScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _appointments = context.read<AppointmentsController>()..start();
    _notifications = context.read<NotificationsController>()..start();
    _doctors = context.read<DoctorsController>()..start();
    WidgetsBinding.instance.addObserver(this);
    // Mỗi phút tính lại theo giờ hiện tại: lịch vừa tới giờ rời khỏi "sắp diễn ra",
    // và sang ngày mới thì "Hôm nay" đổi theo dù app đang mở sẵn.
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) => _appointments.refreshClock());
  }

  /// Mở lại app từ nền -> tính lại theo giờ hiện tại (VD đã sang ngày mới).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _appointments.refreshClock();
    // Vừa bấm liên kết xác minh email khôi phục trong ứng dụng email -> tiếp tục phiên ngầm.
    context.read<AuthController>().checkPendingRecovery();
  }

  void _onTabSelected(int index) {
    _nav.selectTab(index);
    // Đổi tab -> tính lại số liệu / bộ lọc "Hôm nay" theo thời điểm hiện tại.
    _appointments.refreshClock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    _appointments.stop();
    _notifications.stop();
    _doctors.stop();
    _nav.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<StaffNavController>.value(
      value: _nav,
      child: ListenableBuilder(
        // Nghe cả danh sách lịch hẹn để số lịch chờ trên tab Lịch đặt luôn khớp dữ liệu.
        listenable: Listenable.merge([_nav, _appointments]),
        builder: (context, _) => Scaffold(
          body: IndexedStack(index: _nav.index, children: _pages),
          // Mục đang chọn có màu xanh dương (đặc tả 2.5).
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
                  fontWeight: states.contains(WidgetState.selected)
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ),
            child: DecoratedBox(
              // Đường kẻ mảnh tách thanh điều hướng với nội dung (dùng chung mọi tab Staff).
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
                    label: AppStrings.tabOverview,
                  ),
                  NavigationDestination(
                    icon: _PendingBadge(
                      count: _pendingCount,
                      child: const Icon(Icons.event_note_outlined),
                    ),
                    selectedIcon: _PendingBadge(
                      count: _pendingCount,
                      child: const Icon(Icons.event_note),
                    ),
                    label: AppStrings.tabStaffBookings,
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.calendar_month_outlined),
                    selectedIcon: Icon(Icons.calendar_month),
                    label: AppStrings.tabSchedule,
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: AppStrings.tabAccount,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Số lịch đang chờ xác nhận ở mọi ngày – đếm từ danh sách lịch hẹn chung,
  /// nên luôn bằng số trên thẻ "Có X lịch đặt mới cần xử lý" và bộ lọc Chờ xác nhận.
  int get _pendingCount => _appointments.items.where((a) => a.isPending).length;

  static Color _tabColor(Set<WidgetState> states) =>
      states.contains(WidgetState.selected) ? AppColors.primary : AppColors.textSecondary;
}

/// Chấm số trên icon tab Lịch đặt; ẩn khi không còn lịch chờ.
class _PendingBadge extends StatelessWidget {
  const _PendingBadge({required this.count, required this.child});

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: count > 0,
      backgroundColor: AppColors.warning,
      label: Text('$count', key: const ValueKey('tab_pending_badge')),
      child: child,
    );
  }
}
