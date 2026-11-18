import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../app/shells/staff_nav_controller.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../appointments/domain/booking_filter.dart';
import '../../../appointments/presentation/controllers/appointments_controller.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../notifications/presentation/controllers/notifications_controller.dart';
import '../../../notifications/presentation/widgets/notifications_popup.dart';
import '../../domain/staff_home_summary.dart';
import '../widgets/pending_notice_card.dart';
import '../widgets/staff_home_header.dart';
import '../widgets/today_overview_card.dart';
import '../widgets/upcoming_list.dart';

/// Trang chủ Staff (tab "Tổng quan") – đặc tả trang_chu.txt.
///
/// Màn hình KHÔNG giữ số liệu nào: mỗi lần dựng lại, nó lấy danh sách lịch hẹn
/// từ [AppointmentsController] rồi tính [StaffHomeSummary] từ danh sách đó.
class StaffHomeScreen extends StatelessWidget {
  const StaffHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appointments = context.watch<AppointmentsController>();
    final unreadCount = context.watch<NotificationsController>().unreadCount;
    final staff = context.watch<AuthController>().currentUser;
    final nav = context.read<StaffNavController>();

    return Scaffold(
      backgroundColor: AppColors.surface,
      // Phần đầu nền xanh tràn lên thanh trạng thái -> dùng icon trạng thái màu sáng.
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        // Kéo xuống để làm mới: dữ liệu vốn tự cập nhật theo thời gian thực, nên thao tác này
        // tính lại theo giờ hiện tại; nếu đang lỗi thì kết nối lại.
        child: RefreshIndicator(
          key: const ValueKey('home_refresh'),
          color: AppColors.primary,
          onRefresh: () => _refresh(appointments),
          child: ListView(
            padding: EdgeInsets.zero,
            // Luôn kéo được kể cả khi nội dung ngắn hơn màn hình.
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              StaffHomeHeader(
                staffName: staff?.fullName ?? '',
                unreadCount: unreadCount,
                onBellTap: () => NotificationsPopup.show(context),
                onAvatarTap: () => nav.selectTab(StaffNavController.accountTab),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _buildBody(appointments, nav),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refresh(AppointmentsController appointments) async {
    if (appointments.status == LoadStatus.error) {
      appointments.retry();
    } else {
      appointments.refreshClock();
    }
    // Giữ vòng xoay một nhịp ngắn để người dùng thấy thao tác đã được nhận.
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  /// Phần thân theo 3 trạng thái: đang tải / lỗi (có Thử lại) / có dữ liệu.
  List<Widget> _buildBody(AppointmentsController appointments, StaffNavController nav) {
    switch (appointments.status) {
      case LoadStatus.loading:
        return const [LoadingView()];
      case LoadStatus.error:
        return [
          ErrorRetryView(
            message: appointments.errorMessage ?? AppStrings.errUnknown,
            onRetry: appointments.retry,
          ),
        ];
      case LoadStatus.ready:
        // Toàn bộ số liệu được tính tại đây từ MỘT danh sách lịch hẹn.
        final summary = StaffHomeSummary.from(appointments.items, appointments.now);
        // Thứ bậc: việc CẦN LÀM (lịch chờ xử lý) lên đầu để luôn thấy ngay khi mở app,
        // tiếp theo là số liệu hôm nay, cuối cùng là các lịch sắp diễn ra.
        return [
          PendingNoticeCard(
            summary: summary,
            now: appointments.now,
            onTap: () => nav.openBookings(BookingFilter.pending),
          ),
          const SizedBox(height: 18),
          TodayOverviewCard(
            summary: summary,
            today: appointments.now,
            // Bấm "Xem chi tiết" hoặc một thẻ chỉ số -> Lịch đặt lọc Hôm nay (+ trạng thái).
            onOpenToday: (statuses) => nav.openBookings(BookingFilter.today, statuses: statuses),
          ),
          const SizedBox(height: 16),
          UpcomingList(
            upcoming: summary.upcoming,
            now: appointments.now,
            // "Tất cả" mở sẵn ở vị trí hôm nay (lịch cũ hơn nằm phía trên) – xem StaffBookingsScreen.
            onSeeAll: () => nav.openBookings(BookingFilter.all),
          ),
        ];
    }
  }
}
