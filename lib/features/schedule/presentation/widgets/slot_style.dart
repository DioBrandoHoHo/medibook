import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/time_slot.dart';

/// Màu + nhãn của từng trạng thái khung giờ.
class SlotStyle {
  const SlotStyle({
    required this.background,
    required this.border,
    required this.foreground,
    required this.label,
  });

  final Color background;
  final Color border;
  final Color foreground;

  /// Nhãn ngắn hiện trong ô.
  final String label;

  static const legendOrder = [SlotState.free, SlotState.pending, SlotState.booked, SlotState.past];

  static SlotStyle of(SlotState state) => switch (state) {
        SlotState.free => const SlotStyle(
            background: Colors.white,
            border: AppColors.success,
            foreground: AppColors.success,
            label: AppStrings.slotFree,
          ),
        SlotState.pending => const SlotStyle(
            background: AppColors.warningLight,
            border: AppColors.warning,
            foreground: AppColors.warningDark,
            label: AppStrings.slotPending,
          ),
        SlotState.booked => const SlotStyle(
            background: AppColors.primary,
            border: AppColors.primary,
            foreground: Colors.white,
            label: AppStrings.slotBooked,
          ),
        SlotState.past => const SlotStyle(
            background: AppColors.surface,
            border: AppColors.border,
            foreground: AppColors.textSecondary,
            label: AppStrings.slotPast,
          ),
      };

  /// Nhãn đầy đủ ở phần chú thích.
  static String legendLabel(SlotState state) => switch (state) {
        SlotState.free => AppStrings.slotFree,
        SlotState.pending => AppStrings.statusPending,
        SlotState.booked => AppStrings.slotBooked,
        SlotState.past => AppStrings.slotPast,
      };
}
