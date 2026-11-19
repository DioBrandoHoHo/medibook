import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../core/utils/name_utils.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/entities/appointment_status.dart';
import '../controllers/appointments_controller.dart';
import '../widgets/appointment_actions.dart';
import '../widgets/appointment_tile.dart';
import '../widgets/status_chip.dart';

/// Chi tiết lịch hẹn cho Staff.
class AppointmentDetailScreen extends StatefulWidget {
  const AppointmentDetailScreen({super.key, required this.appointmentId});

  final String appointmentId;

  static Future<void> open(BuildContext context, String appointmentId) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AppointmentDetailScreen(appointmentId: appointmentId),
      ),
    );
  }

  @override
  State<AppointmentDetailScreen> createState() => _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  bool _busy = false;
  DateTime _now = DateTime.now();

  Future<void> _handle(Appointment appointment, {required bool confirm}) async {
    setState(() => _busy = true);
    await runAppointmentAction(context, appointment, confirm: confirm);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppointmentsController>();
    final appointment = controller.byId(widget.appointmentId);
    _now = controller.now;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text(AppStrings.appointmentDetail),
        backgroundColor: AppColors.surface,
      ),
      body: appointment == null
          ? const Center(
              child: EmptyView(
                message: AppStrings.appointmentNotFound,
                icon: Icons.search_off_rounded,
              ),
            )
          : _buildContent(appointment),
      bottomNavigationBar:
          appointment != null && appointment.isPending && !appointment.isOverdueAt(_now)
          ? _buildActions(appointment)
          : null,
    );
  }

  Widget _buildContent(Appointment a) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _Card(
          child: Row(
            children: [
              InitialAvatar(initial: NameUtils.initial(a.customerName), radius: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      AppStrings.fieldCustomer,
                      style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      a.customerName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusChip(status: a.status),
                        BookingCodeChip(code: a.shortCode),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _StatusNote(status: a.status),
        if (a.isOverdueAt(_now)) ...[
          const SizedBox(height: 8),
          Container(
            key: const ValueKey('expired_note'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.errorLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline_rounded, size: 20, color: AppColors.error),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppStrings.noteExpired,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        _Card(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.medical_services_outlined,
                label: AppStrings.fieldService,
                value: a.serviceName,
              ),
              if (a.doctorName != null)
                _InfoRow(
                  icon: Icons.person_pin_outlined,
                  label: AppStrings.fieldDoctor,
                  value: a.doctorName!,
                ),
              _InfoRow(
                icon: Icons.calendar_today_rounded,
                label: AppStrings.fieldDate,
                value: AppDateUtils.weekdayDate(a.startAt),
              ),
              _InfoRow(
                icon: Icons.access_time_rounded,
                label: AppStrings.fieldTime,
                value: AppDateUtils.timeRange(a.startAt, a.endAt),
              ),
              _InfoRow(
                icon: Icons.tag_rounded,
                label: AppStrings.fieldCode,
                value: a.id,
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActions(Appointment a) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('reject_button'),
                  onPressed: _busy ? null : () => _handle(a, confirm: false),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  label: const Text(AppStrings.rejectAppointment),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('confirm_button'),
                  onPressed: _busy ? null : () => _handle(a, confirm: true),
                  icon: const Icon(Icons.check_rounded, size: 20),
                  label: const Text(AppStrings.confirmAppointment),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: child,
    );
  }
}

/// Dòng giải thích trạng thái hiện tại của lịch, tô màu theo trạng thái.
class _StatusNote extends StatelessWidget {
  const _StatusNote({required this.status});

  final AppointmentStatus status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = StatusStyle.colorsOf(status);
    final message = switch (status) {
      AppointmentStatus.pending => AppStrings.notePending,
      AppointmentStatus.confirmed => AppStrings.noteConfirmed,
      AppointmentStatus.rejected => AppStrings.noteRejected,
      AppointmentStatus.cancelled => AppStrings.noteCancelled,
    };
    return Container(
      key: const ValueKey('status_note'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(StatusStyle.iconOf(status), size: 20, color: foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: AppColors.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 96,
            child: Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
