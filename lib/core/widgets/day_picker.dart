import 'package:flutter/material.dart';

import '../constants/app_strings.dart';
import '../theme/app_colors.dart';
import '../utils/app_date_utils.dart';
import 'day_strip.dart';
import 'month_calendar_sheet.dart';

/// Ngày đầu tiên chọn được trong tháng chứa [month], trong khoảng [firstDay]..[lastDay].
DateTime? firstSelectableInMonth(
  DateTime month, {
  required DateTime firstDay,
  required DateTime lastDay,
  bool Function(DateTime day)? isEnabled,
}) {
  final start = AppDateUtils.monthStart(month);
  for (var d = 1; d <= AppDateUtils.daysInMonth(start); d++) {
    final day = DateTime(start.year, start.month, d);
    if (day.isBefore(firstDay) || day.isAfter(lastDay)) continue;
    if (isEnabled == null || isEnabled(day)) return day;
  }
  return null;
}

/// Ngày được chọn khi chuyển sang tháng trước / sau.
DateTime? monthJumpTarget(
  DateTime selected,
  int direction, {
  required DateTime firstDay,
  required DateTime lastDay,
  bool Function(DateTime day)? isEnabled,
}) {
  final firstMonth = AppDateUtils.monthStart(firstDay);
  final lastMonth = AppDateUtils.monthStart(lastDay);
  for (var month = AppDateUtils.addMonths(selected, direction);
      !month.isBefore(firstMonth) && !month.isAfter(lastMonth);
      month = AppDateUtils.addMonths(month, direction)) {
    final day = firstSelectableInMonth(
      month,
      firstDay: firstDay,
      lastDay: lastDay,
      isEnabled: isEnabled,
    );
    if (day != null) return day;
  }
  return null;
}

/// Bộ chọn ngày cho màn hình điện thoại.
class DayPicker extends StatelessWidget {
  const DayPicker({
    super.key,
    required this.today,
    required this.selected,
    required this.lastDay,
    required this.onSelect,
    this.isEnabled,
    this.disabledLabel,
    this.note,
  });

  final DateTime today;
  final DateTime selected;
  final DateTime lastDay;
  final ValueChanged<DateTime> onSelect;
  final bool Function(DateTime day)? isEnabled;
  final String? disabledLabel;
  final String? note;

  Future<void> _openCalendar(BuildContext context) async {
    final picked = await showMonthCalendar(
      context,
      today: today,
      selected: selected,
      firstDay: today,
      lastDay: lastDay,
      isEnabled: isEnabled,
      disabledLabel: disabledLabel,
      note: note,
    );
    if (picked != null) onSelect(picked);
  }

  @override
  Widget build(BuildContext context) {
    final prev = monthJumpTarget(selected, -1,
        firstDay: today, lastDay: lastDay, isEnabled: isEnabled);
    final next = monthJumpTarget(selected, 1,
        firstDay: today, lastDay: lastDay, isEnabled: isEnabled);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              IconButton(
                key: const ValueKey('month_prev'),
                tooltip: AppStrings.prevMonth,
                onPressed: prev == null ? null : () => onSelect(prev),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Center(
                  child: TextButton(
                    key: const ValueKey('month_label'),
                    onPressed: () => _openCalendar(context),
                    style: TextButton.styleFrom(foregroundColor: AppColors.primaryDark),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_month_outlined, size: 19),
                          const SizedBox(width: 6),
                          Text(
                            AppDateUtils.monthLabel(selected),
                            key: const ValueKey('month_label_text'),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          const Icon(Icons.arrow_drop_down_rounded),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('month_next'),
                tooltip: AppStrings.nextMonth,
                onPressed: next == null ? null : () => onSelect(next),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
        DayStrip(
          today: today,
          selected: selected,
          dayCount: AppDateUtils.daysBetween(today, lastDay) + 1,
          onSelect: onSelect,
          isEnabled: isEnabled,
          showMonth: true,
        ),
      ],
    );
  }
}
