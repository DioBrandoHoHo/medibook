import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../app/shells/customer_nav_controller.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../booking/presentation/controllers/doctors_controller.dart';
import '../../../booking/presentation/widgets/doctor_card.dart';
import '../../domain/customer_appointments.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/entities/appointment_status.dart';
import '../controllers/appointments_controller.dart';
import '../widgets/appointment_tile.dart';
import '../widgets/customer_cancel.dart';
import '../widgets/status_chip.dart';
import 'customer_appointment_detail_screen.dart';

/// Tab "Lịch hẹn" của Customer.
class CustomerAppointmentsScreen extends StatefulWidget {
  const CustomerAppointmentsScreen({super.key});

  @override
  State<CustomerAppointmentsScreen> createState() => _CustomerAppointmentsScreenState();
}

class _CustomerAppointmentsScreenState extends State<CustomerAppointmentsScreen> {
  /// Lịch đang được hủy (khoá nút, tránh bấm hai lần).
  String? _cancellingId;

  static const _labels = {
    CustomerAppointmentFilter.upcoming: AppStrings.cFilterUpcoming,
    CustomerAppointmentFilter.past: AppStrings.cFilterPast,
    CustomerAppointmentFilter.cancelled: AppStrings.cFilterCancelled,
  };

  static const _empty = {
    CustomerAppointmentFilter.upcoming: AppStrings.cEmptyUpcoming,
    CustomerAppointmentFilter.past: AppStrings.cEmptyPast,
    CustomerAppointmentFilter.cancelled: AppStrings.cEmptyCancelled,
  };

  Future<void> _cancel(Appointment appointment) async {
    await confirmCancelAppointment(
      context,
      appointment,
      onBusy: (busy) {
        if (mounted) setState(() => _cancellingId = busy ? appointment.id : null);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<CustomerNavController>();
    final controller = context.watch<AppointmentsController>();
    final doctors = context.watch<DoctorsController>();
    final now = controller.now;
    final filter = nav.appointmentFilter;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 10, 20, 10),
                child: Text(
                  AppStrings.myAppointments,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    for (final value in CustomerAppointmentFilter.values)
                      Expanded(
                        child: _FilterButton(
                          name: value.name,
                          label: _labels[value]!,
                          count: controller.status == LoadStatus.ready
                              ? customerAppointments(controller.items, value, now).length
                              : null,
                          selected: value == filter,
                          onTap: () => nav.setAppointmentFilter(value),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(child: _body(controller, doctors, nav, filter, now)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(
    AppointmentsController controller,
    DoctorsController doctors,
    CustomerNavController nav,
    CustomerAppointmentFilter filter,
    DateTime now,
  ) {
    if (controller.status == LoadStatus.error) {
      return SingleChildScrollView(
        child: ErrorRetryView(
          message: controller.errorMessage ?? AppStrings.errUnknown,
          onRetry: controller.retry,
        ),
      );
    }
    if (controller.status == LoadStatus.loading) return const LoadingView();

    final items = customerAppointments(controller.items, filter, now);
    if (items.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EmptyView(message: _empty[filter]!),
              if (filter == CustomerAppointmentFilter.upcoming)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 60),
                  child: FilledButton.icon(
                    key: const ValueKey('appointments_book_now'),
                    onPressed: nav.openBooking,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text(AppStrings.bookNow),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    final rows = <({DateTime? header, Appointment? item})>[];
    for (var i = 0; i < items.length; i++) {
      final a = items[i];
      if (i == 0 || !AppDateUtils.isSameDay(items[i - 1].startAt, a.startAt)) {
        rows.add((header: AppDateUtils.dayOnly(a.startAt), item: null));
      }
      rows.add((header: null, item: a));
    }

    return ListView.builder(
      key: const ValueKey('customer_appointments_list'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final row = rows[i];
        final header = row.header;
        if (header != null) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
            child: Text(
              AppDateUtils.dayLabel(header, now),
              key: ValueKey('cday_${AppDateUtils.isoDate(header)}'),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          );
        }
        final a = row.item!;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _AppointmentCard(
            appointment: a,
            room: doctors.byId(a.doctorId ?? '')?.room ?? '',
            now: now,
            cancelling: _cancellingId == a.id,
            onCancel: () => _cancel(a),
          ),
        );
      },
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.name,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: selected ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('cfilter_$name'),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? AppColors.primary : AppColors.border),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: foreground),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      '$count',
                      key: ValueKey('cfilter_count_$name'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white70 : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Thẻ một lịch hẹn của khách.
class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.appointment,
    required this.room,
    required this.now,
    required this.cancelling,
    required this.onCancel,
  });

  final Appointment appointment;
  final String room;
  final DateTime now;
  final bool cancelling;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final group = groupOf(a, now);
    final blocked = cancelBlockReason(a, now);
    return SectionCard(
      key: ValueKey('cappt_${a.id}'),
      onTap: () => CustomerAppointmentDetailScreen.open(context, a.id),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DateBlock(date: a.startAt, now: now),
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
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [a.serviceName, if (room.isNotEmpty) room].join('  •  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded,
                              size: 15, color: AppColors.textSecondary),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              AppDateUtils.timeRange(a.startAt, a.endAt),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          BookingCodeChip(code: a.shortCode),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 8,
              children: [
                StatusChip(status: a.status),
                if (group == CustomerAppointmentFilter.upcoming && blocked == null)
                  OutlinedButton(
                    key: ValueKey('cancel_${a.id}'),
                    onPressed: cancelling ? null : onCancel,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(96, 38),
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                    child: cancelling
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(AppStrings.cancelAppointment),
                  ),
              ],
            ),
            if (group == CustomerAppointmentFilter.past &&
                a.status == AppointmentStatus.pending) ...[
              const SizedBox(height: 8),
              Text(
                AppStrings.noteNeverConfirmed,
                key: ValueKey('never_confirmed_${a.id}'),
                style: const TextStyle(fontSize: 12.5, color: AppColors.warningDark),
              ),
            ],
            if (group == CustomerAppointmentFilter.upcoming && blocked != null) ...[
              const SizedBox(height: 8),
              Text(
                blocked,
                key: ValueKey('cancel_blocked_${a.id}'),
                style: const TextStyle(fontSize: 12.5, color: AppColors.warningDark),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Ô ngày: "Hôm nay" hoặc thứ + ngày/tháng.
class DateBlock extends StatelessWidget {
  const DateBlock({super.key, required this.date, required this.now});

  final DateTime date;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            AppDateUtils.isSameDay(date, now) ? AppStrings.today : AppDateUtils.weekdayShort(date),
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDark,
            ),
          ),
          Text(
            '${date.day}/${date.month}',
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
          if (date.year != now.year)
            Text(
              '${date.year}',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDark,
              ),
            ),
        ],
      ),
    );
  }
}
