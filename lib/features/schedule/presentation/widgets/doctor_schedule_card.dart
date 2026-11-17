import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../core/utils/name_utils.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../appointments/presentation/screens/appointment_detail_screen.dart';
import '../../../booking/domain/entities/doctor.dart';
import '../../domain/entities/time_slot.dart';
import '../../domain/schedule_builder.dart';
import '../../domain/work_shift.dart';
import 'slot_style.dart';

/// Thẻ lịch làm việc của MỘT bác sĩ: thông tin bác sĩ, nút chọn Sáng / Chiều
/// và lưới các khung 30 phút của buổi đang xem.
class DoctorScheduleCard extends StatelessWidget {
  const DoctorScheduleCard({
    super.key,
    required this.doctor,
    required this.shift,
    required this.slots,
    required this.onShiftChanged,
  });

  final Doctor doctor;
  final WorkShift shift;

  /// Các khung của [shift] (đã tính sẵn từ danh sách lịch hẹn chung).
  final List<TimeSlot> slots;
  final ValueChanged<WorkShift> onShiftChanged;

  static String shiftLabel(WorkShift shift) =>
      shift == WorkShift.morning ? AppStrings.shiftMorning : AppStrings.shiftAfternoon;

  @override
  Widget build(BuildContext context) {
    final summary = SlotSummary.of(slots);
    final details = [doctor.specialty, doctor.room].where((s) => s.isNotEmpty).join('  •  ');
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              InitialAvatar(initial: NameUtils.initial(doctor.name), radius: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctor.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        details,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Số khung còn trống của buổi đang xem.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: summary.free > 0 ? AppColors.successLight : AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  AppStrings.freeOf(summary.free, summary.total),
                  key: ValueKey('free_${doctor.id}'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: summary.free > 0 ? AppColors.success : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ShiftToggle(doctorId: doctor.id, shift: shift, onChanged: onShiftChanged),
          const SizedBox(height: 10),
          _SlotGrid(doctorId: doctor.id, slots: slots),
        ],
      ),
    );
  }
}

/// Nút chọn buổi Sáng / Chiều của một bác sĩ.
class _ShiftToggle extends StatelessWidget {
  const _ShiftToggle({required this.doctorId, required this.shift, required this.onChanged});

  final String doctorId;
  final WorkShift shift;
  final ValueChanged<WorkShift> onChanged;

  static String _hours(WorkShift s) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(s.startHour)}:${two(s.startMinute)} – ${two(s.endHour)}:${two(s.endMinute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final option in WorkShift.values)
            Expanded(
              child: Material(
                color: option == shift ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(11),
                clipBehavior: Clip.antiAlias,
                elevation: option == shift ? 1 : 0,
                shadowColor: const Color(0x331E3A8A),
                child: InkWell(
                  key: ValueKey('shift_${doctorId}_${option.name}'),
                  onTap: () => onChanged(option),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          option == WorkShift.morning
                              ? Icons.wb_sunny_outlined
                              : Icons.wb_twilight_rounded,
                          size: 16,
                          color: option == shift ? AppColors.primary : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '${DoctorScheduleCard.shiftLabel(option)}  ${_hours(option)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: option == shift ? FontWeight.w700 : FontWeight.w500,
                              color: option == shift ? AppColors.primary : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Lưới khung giờ, 4 khung một hàng.
class _SlotGrid extends StatelessWidget {
  const _SlotGrid({required this.doctorId, required this.slots});

  final String doctorId;
  final List<TimeSlot> slots;

  static const _columns = 4;
  static const _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - _gap * (_columns - 1)) / _columns;
        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: [
            for (final slot in slots)
              SizedBox(width: width, child: _SlotTile(doctorId: doctorId, slot: slot)),
          ],
        );
      },
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({required this.doctorId, required this.slot});

  final String doctorId;
  final TimeSlot slot;

  @override
  Widget build(BuildContext context) {
    final style = SlotStyle.of(slot.state);
    final appointment = slot.appointment;
    final time = AppDateUtils.time(slot.start);
    return Semantics(
      label: '$time ${SlotStyle.legendLabel(slot.state)}',
      child: Material(
        color: style.background,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('slot_${doctorId}_${time.replaceAll(':', '')}'),
          // Chỉ khung có lịch mới bấm được -> mở Chi tiết của đúng lịch đó.
          onTap: appointment == null
              ? null
              : () => AppointmentDetailScreen.open(context, appointment.id),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: style.border),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: slot.state == SlotState.free
                            ? AppColors.textPrimary
                            : style.foreground,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      style.label,
                      key: ValueKey('slot_label_${doctorId}_${time.replaceAll(':', '')}'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: style.foreground,
                      ),
                    ),
                  ],
                ),
                if (slot.hasConflict)
                  Positioned(
                    top: -2,
                    right: 6,
                    child: Tooltip(
                      message: AppStrings.slotConflict,
                      child: Icon(
                        Icons.error_rounded,
                        key: ValueKey('slot_conflict_${doctorId}_${time.replaceAll(':', '')}'),
                        size: 14,
                        color: slot.state == SlotState.booked ? Colors.white : AppColors.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
