import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../core/utils/text_utils.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../booking/presentation/controllers/doctors_controller.dart';
import '../../../booking/presentation/screens/doctor_detail_screen.dart';
import '../../../booking/presentation/widgets/doctor_card.dart';
import '../../domain/customer_appointments.dart';
import '../../domain/entities/appointment.dart';
import '../controllers/appointments_controller.dart';
import '../widgets/customer_cancel.dart';
import '../widgets/status_chip.dart';

/// Chi tiết lịch hẹn cho Customer.
class CustomerAppointmentDetailScreen extends StatefulWidget {
  const CustomerAppointmentDetailScreen({super.key, required this.appointmentId});

  final String appointmentId;

  static Future<void> open(BuildContext context, String appointmentId) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CustomerAppointmentDetailScreen(appointmentId: appointmentId),
      ),
    );
  }

  @override
  State<CustomerAppointmentDetailScreen> createState() => _State();
}

class _State extends State<CustomerAppointmentDetailScreen> {
  bool _busy = false;

  Future<void> _cancel(Appointment appointment) async {
    await confirmCancelAppointment(
      context,
      appointment,
      onBusy: (busy) {
        if (mounted) setState(() => _busy = busy);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppointmentsController>();
    final a = controller.byId(widget.appointmentId);
    final now = controller.now;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text(AppStrings.appointmentDetail),
        backgroundColor: AppColors.surface,
      ),
      body: a == null
          ? const Center(
              child: EmptyView(
                message: AppStrings.appointmentNotFound,
                icon: Icons.search_off_rounded,
              ),
            )
          : _content(context, a, now),
      bottomNavigationBar: a == null ? null : _bottomBar(context, a, now),
    );
  }

  Widget _content(BuildContext context, Appointment a, DateTime now) {
    final doctor = context.watch<DoctorsController>().byId(a.doctorId ?? '');
    final user = context.watch<AuthController>().currentUser;
    final (background, foreground) = StatusStyle.colorsOf(a.status);
    final blocked = cancelBlockReason(a, now);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(18)),
          child: Row(
            children: [
              Icon(StatusStyle.iconOf(a.status), color: foreground, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      StatusStyle.labelOf(a.status),
                      key: const ValueKey('cdetail_status'),
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: foreground),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      customerStatusNote(a, now),
                      key: const ValueKey('cdetail_note'),
                      style: TextStyle(fontSize: 13, color: foreground),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                _Row(name: 'code', label: AppStrings.fieldCode, value: a.shortCode),
                if (a.doctorName != null)
                  _Row(name: 'doctor', label: AppStrings.fieldDoctor, value: a.doctorName!),
                if (doctor != null && doctor.specialty.isNotEmpty)
                  _Row(name: 'specialty', label: AppStrings.fieldSpecialty, value: doctor.specialty),
                _Row(name: 'service', label: AppStrings.fieldService, value: a.serviceName),
                _Row(
                  name: 'date',
                  label: AppStrings.fieldDate,
                  value: AppDateUtils.weekdayDate(a.startAt),
                ),
                _Row(
                  name: 'time',
                  label: AppStrings.fieldTime,
                  value: AppDateUtils.timeRange(a.startAt, a.endAt),
                ),
                if (doctor != null && doctor.room.isNotEmpty)
                  _Row(name: 'room', label: AppStrings.fieldRoom, value: doctor.room),
                if (doctor != null && doctor.fee > 0)
                  _Row(name: 'fee', label: AppStrings.feeLabel, value: TextUtils.money(doctor.fee)),
                _Row(
                  name: 'patient',
                  label: AppStrings.fieldPatient,
                  value: [a.customerName, if (user != null) user.phone].join('\n'),
                  isLast: true,
                ),
              ],
            ),
          ),
        ),
        if (a.isActive && a.startAt.isAfter(now)) ...[
          const SizedBox(height: 12),
          Text(
            blocked ?? AppStrings.cancelRuleHint,
            key: const ValueKey('cdetail_cancel_hint'),
            style: TextStyle(
              fontSize: 12.5,
              color: blocked == null ? AppColors.textSecondary : AppColors.warningDark,
            ),
          ),
        ],
      ],
    );
  }

  Widget? _bottomBar(BuildContext context, Appointment a, DateTime now) {
    final Widget button;
    if (canCancel(a, now)) {
      button = OutlinedButton(
        key: const ValueKey('cdetail_cancel'),
        onPressed: _busy ? null : () => _cancel(a),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: const BorderSide(color: AppColors.error),
        ),
        child: _busy
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
            : const Text(AppStrings.cancelAppointment),
      );
    } else if (groupOf(a, now) != CustomerAppointmentFilter.upcoming &&
        a.doctorId != null &&
        context.watch<DoctorsController>().byId(a.doctorId!) != null) {
      button = FilledButton(
        key: const ValueKey('cdetail_rebook'),
        onPressed: () => DoctorDetailScreen.open(context, doctorId: a.doctorId!),
        child: const Text(AppStrings.rebook),
      );
    } else {
      return null;
    }
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 10), child: button),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.name, required this.label, required this.value, this.isLast = false});

  final String name;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(
              value,
              key: ValueKey('cdetail_$name'),
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
