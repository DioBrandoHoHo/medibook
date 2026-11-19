import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../core/utils/name_utils.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/availability.dart';

/// Thẻ trắng bo góc có bóng nhẹ.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.child, this.onTap, this.radius = 20});

  final Widget child;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: AppColors.cardShadow,
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? child : InkWell(onTap: onTap, child: child),
      ),
    );
  }
}

/// Một bác sĩ trong danh sách.
class DoctorCard extends StatelessWidget {
  const DoctorCard({
    super.key,
    required this.item,
    required this.onTap,
    this.wantedStart,
  });

  final DoctorAvailability item;
  final VoidCallback onTap;

  /// Khung giờ khách đang muốn khám.
  final DateTime? wantedStart;

  @override
  Widget build(BuildContext context) {
    final doctor = item.doctor;
    final details = [
      if (doctor.room.isNotEmpty) doctor.room,
      if (doctor.experienceYears > 0) AppStrings.experience(doctor.experienceYears),
    ].join('  •  ');
    return SectionCard(
      key: ValueKey('doctor_card_${doctor.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
        child: Row(
          children: [
            InitialAvatar(initial: NameUtils.initial(doctor.name), radius: 26),
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
                  const SizedBox(height: 2),
                  Text(
                    doctor.specialty,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      details,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _AvailabilityBadge(item: item, wantedStart: wantedStart),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _AvailabilityBadge extends StatelessWidget {
  const _AvailabilityBadge({required this.item, required this.wantedStart});

  final DoctorAvailability item;
  final DateTime? wantedStart;

  @override
  Widget build(BuildContext context) {
    final free = item.freeCount > 0;
    final wanted = wantedStart;
    final String text;
    if (!free) {
      text = AppStrings.fullDay;
    } else if (wanted != null) {
      text = AppStrings.freeAt(AppDateUtils.time(wanted));
    } else {
      text = AppStrings.freeSlots(item.freeCount);
    }
    final color = free ? AppColors.success : AppColors.textSecondary;
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: free ? AppColors.successLight : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(free ? Icons.event_available_rounded : Icons.event_busy_rounded,
              size: 14, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              key: ValueKey('doctor_free_${item.doctor.id}'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
    if (!free || wanted != null) return badge;
    return Row(
      children: [
        Flexible(flex: 3, child: badge),
        const SizedBox(width: 8),
        Flexible(
          flex: 2,
          child: Text(
            AppStrings.nearest(AppDateUtils.time(item.nextFree!)),
            key: ValueKey('doctor_next_${item.doctor.id}'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
