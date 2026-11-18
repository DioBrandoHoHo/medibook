import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../app/shells/customer_nav_controller.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../../appointments/domain/entities/appointment_status.dart';
import '../../../appointments/presentation/controllers/appointments_controller.dart';
import '../../../appointments/presentation/screens/customer_appointment_detail_screen.dart';
import '../../../appointments/presentation/widgets/status_chip.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../booking/domain/availability.dart';
import '../../../booking/presentation/controllers/busy_slots_controller.dart';
import '../../../booking/presentation/controllers/doctors_controller.dart';
import '../../../booking/presentation/screens/doctor_detail_screen.dart';
import '../../../booking/presentation/widgets/doctor_card.dart';
import '../../domain/customer_home_summary.dart';
import '../widgets/staff_home_header.dart';

/// Trang chủ của Customer (trang_chu.txt phần 2).
///
/// Màn này KHÔNG giữ số liệu riêng:
/// - lịch hẹn của khách đọc từ `AppointmentsController.items` rồi tính bằng [CustomerHomeSummary];
/// - bác sĩ đọc từ `DoctorsController`, số ca trống tính bằng [applyDoctorFilter] từ
///   `BusySlotsController` – cùng hàm và cùng nguồn với tab Đặt lịch.
/// Vì vậy Staff xác nhận / từ chối, hay có người đặt mất một khung, thì trang tự đổi theo.
class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({super.key});

  /// Số bác sĩ còn trống hôm nay hiện ở Trang chủ.
  static const freeDoctorLimit = 3;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().currentUser;
    final appointments = context.watch<AppointmentsController>();
    final doctors = context.watch<DoctorsController>();
    final busy = context.watch<BusySlotsController>();
    final nav = context.read<CustomerNavController>();
    final now = appointments.now;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: ListView(
          key: const ValueKey('customer_home_list'),
          padding: EdgeInsets.zero,
          children: [
            StaffHomeHeader(
              staffName: user?.fullName ?? '',
              avatar: user?.avatar ?? '',
              wish: AppStrings.customerWish,
              onAvatarTap: () =>
                  nav.selectTab(CustomerNavController.profileTab),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ..._appointmentSection(appointments, doctors, nav, now),
                  const SizedBox(height: 22),
                  ..._doctorSection(
                    context,
                    appointments,
                    doctors,
                    busy,
                    nav,
                    now,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----- Lịch hẹn của tôi -----
  List<Widget> _appointmentSection(
    AppointmentsController appointments,
    DoctorsController doctors,
    CustomerNavController nav,
    DateTime now,
  ) {
    if (appointments.status == LoadStatus.error) {
      return [
        SectionCard(
          child: ErrorRetryView(
            message: appointments.errorMessage ?? AppStrings.errUnknown,
            onRetry: appointments.retry,
          ),
        ),
      ];
    }
    if (appointments.status == LoadStatus.loading) {
      return const [SectionCard(child: LoadingView())];
    }
    final summary = CustomerHomeSummary.from(appointments.items, now);
    final next = summary.next;
    return [
      _SectionTitle(
        title: AppStrings.nextAppointment,
        action: AppStrings.seeAll,
        actionKey: 'see_all_appointments',
        onAction: nav.openAppointments,
      ),
      const SizedBox(height: 10),
      if (next == null)
        _NoUpcomingCard(onBook: nav.openBooking)
      else
        _NextAppointmentCard(
          appointment: next,
          // Phòng khám lấy từ danh sách bác sĩ hiện tại (đổi phòng thì thẻ đổi theo).
          room: doctors.byId(next.doctorId ?? '')?.room ?? '',
          now: now,
        ),
      const SizedBox(height: 12),
      Row(
        children: [
          _StatTile(
            name: 'upcoming',
            value: summary.upcomingTotal,
            label: AppStrings.cStatUpcoming,
            color: AppColors.primary,
            background: AppColors.primaryLight,
          ),
          const SizedBox(width: 10),
          _StatTile(
            name: 'pending',
            value: summary.upcomingPending,
            label: AppStrings.cStatPending,
            color: AppColors.warningDark,
            background: AppColors.warningLight,
          ),
          const SizedBox(width: 10),
          _StatTile(
            name: 'confirmed',
            value: summary.upcomingConfirmed,
            label: AppStrings.cStatConfirmed,
            color: AppColors.success,
            background: AppColors.successLight,
          ),
        ],
      ),
      if (summary.others.isNotEmpty) ...[
        const SizedBox(height: 18),
        const _SectionTitle(title: AppStrings.otherUpcoming),
        const SizedBox(height: 10),
        SectionCard(
          child: Column(
            children: [
              for (final (i, a) in summary.others.indexed) ...[
                if (i > 0)
                  const Divider(
                    height: 1,
                    indent: 14,
                    endIndent: 14,
                    color: AppColors.border,
                  ),
                _UpcomingRow(appointment: a, now: now),
              ],
            ],
          ),
        ),
      ],
    ];
  }

  // ----- Chuyên khoa + bác sĩ còn trống hôm nay -----
  List<Widget> _doctorSection(
    BuildContext context,
    AppointmentsController appointments,
    DoctorsController doctors,
    BusySlotsController busy,
    CustomerNavController nav,
    DateTime now,
  ) {
    if (doctors.status == LoadStatus.error || busy.status == LoadStatus.error) {
      return [
        SectionCard(
          child: ErrorRetryView(
            message:
                doctors.errorMessage ??
                busy.errorMessage ??
                AppStrings.errUnknown,
            onRetry: () {
              if (doctors.status == LoadStatus.error) doctors.retry();
              if (busy.status == LoadStatus.error) busy.retry();
            },
          ),
        ),
      ];
    }
    if (doctors.status == LoadStatus.loading ||
        busy.status == LoadStatus.loading) {
      return const [SectionCard(child: LoadingView())];
    }
    if (doctors.items.isEmpty) {
      return const [
        SectionCard(
          child: EmptyView(
            message: AppStrings.doctorsEmptyCustomer,
            icon: Icons.person_off_outlined,
          ),
        ),
      ];
    }

    final today = AppDateUtils.dayOnly(now);
    final free = applyDoctorFilter(
      doctors: doctors.items,
      filter: DoctorFilter(day: today, onlyFree: true),
      busyIds: busy.ids,
      mine: appointments.items,
      now: now,
    );
    return [
      const _SectionTitle(title: AppStrings.specialties),
      const SizedBox(height: 10),
      SizedBox(
        height: 40,
        child: ListView.separated(
          key: const ValueKey('home_specialties'),
          scrollDirection: Axis.horizontal,
          itemCount: specialtiesOf(doctors.items).length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final name = specialtiesOf(doctors.items)[i];
            return ActionChip(
              key: ValueKey('home_spec_$name'),
              avatar: const Icon(
                Icons.medical_services_outlined,
                size: 16,
                color: AppColors.primary,
              ),
              label: Text(name),
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              backgroundColor: Colors.white,
              side: const BorderSide(color: AppColors.border),
              shape: const StadiumBorder(),
              onPressed: () => nav.openBooking(specialty: name),
            );
          },
        ),
      ),
      const SizedBox(height: 22),
      _SectionTitle(
        title: AppStrings.freeToday,
        action: AppStrings.seeAll,
        actionKey: 'see_all_doctors',
        onAction: nav.openBooking,
      ),
      const SizedBox(height: 10),
      if (free.isEmpty)
        SectionCard(
          child: Column(
            children: [
              const EmptyView(message: AppStrings.noFreeToday),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: OutlinedButton(
                  key: const ValueKey('pick_another_day'),
                  onPressed: nav.openBooking,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                  ),
                  child: const Text(AppStrings.pickAnotherDay),
                ),
              ),
            ],
          ),
        ),
      for (final item in free.take(freeDoctorLimit))
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: DoctorCard(
            item: item,
            onTap: () => DoctorDetailScreen.open(
              context,
              doctorId: item.doctor.id,
              day: today,
            ),
          ),
        ),
    ];
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    this.action,
    this.actionKey,
    this.onAction,
  });

  final String title;
  final String? action;
  final String? actionKey;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (action != null)
          InkWell(
            key: actionKey == null ? null : ValueKey<String>(actionKey!),
            borderRadius: BorderRadius.circular(8),
            onTap: onAction,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                action!,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Thẻ nổi bật: lịch hẹn gần nhất của khách.
class _NextAppointmentCard extends StatelessWidget {
  const _NextAppointmentCard({
    required this.appointment,
    required this.room,
    required this.now,
  });

  final Appointment appointment;
  final String room;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final note = a.status == AppointmentStatus.confirmed
        ? AppStrings.noteConfirmedCustomer
        : AppStrings.notePendingCustomer;
    return SectionCard(
      key: const ValueKey('next_appointment'),
      onTap: () => CustomerAppointmentDetailScreen.open(context, a.id),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.medical_information_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.doctorName ?? a.serviceName,
                        key: const ValueKey('next_doctor'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: StatusChip(
                          key: const ValueKey('next_status'),
                          status: a.status,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              [a.serviceName, if (room.isNotEmpty) room].join('  •  '),
              key: const ValueKey('next_service'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppDateUtils.dayLabel(a.startAt, now),
                      key: const ValueKey('next_day'),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.access_time_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    AppDateUtils.timeRange(a.startAt, a.endAt),
                    key: const ValueKey('next_time'),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              note,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thẻ khi khách chưa có lịch hẹn sắp tới: mời đặt lịch.
class _NoUpcomingCard extends StatelessWidget {
  const _NoUpcomingCard({required this.onBook});

  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      key: const ValueKey('no_upcoming'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_available_rounded,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              AppStrings.noUpcoming,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              AppStrings.noUpcomingHint,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              key: const ValueKey('book_now'),
              onPressed: onBook,
              icon: const Icon(Icons.add_rounded),
              label: const Text(AppStrings.bookNow),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.name,
    required this.value,
    required this.label,
    required this.color,
    required this.background,
  });

  final String name;
  final int value;
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              key: ValueKey('cstat_$name'),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Một dòng lịch hẹn sắp tới (dạng gọn).
class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.appointment, required this.now});

  final Appointment appointment;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    return InkWell(
      key: ValueKey('upcoming_${a.id}'),
      onTap: () => CustomerAppointmentDetailScreen.open(context, a.id),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            // Ô ngày: thứ + ngày/tháng.
            Container(
              width: 50,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    AppDateUtils.isSameDay(a.startAt, now)
                        ? AppStrings.today
                        : AppDateUtils.weekdayShort(a.startAt),
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  Text(
                    '${a.startAt.day}/${a.startAt.month}',
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.doctorName ?? a.serviceName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    AppDateUtils.timeRange(a.startAt, a.endAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusChip(status: a.status),
          ],
        ),
      ),
    );
  }
}
