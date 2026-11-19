import 'package:flutter/material.dart';

import '../constants/app_strings.dart';
import '../theme/app_colors.dart';
import '../utils/app_date_utils.dart';

/// Mở bảng lịch tháng để chọn ngày.
Future<DateTime?> showMonthCalendar(
  BuildContext context, {
  required DateTime today,
  required DateTime selected,
  required DateTime firstDay,
  required DateTime lastDay,
  bool Function(DateTime day)? isEnabled,
  String? disabledLabel,
  String? note,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: Colors.white,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => MonthCalendarSheet(
      today: today,
      selected: selected,
      firstDay: firstDay,
      lastDay: lastDay,
      isEnabled: isEnabled,
      disabledLabel: disabledLabel,
      note: note,
    ),
  );
}

class MonthCalendarSheet extends StatefulWidget {
  const MonthCalendarSheet({
    super.key,
    required this.today,
    required this.selected,
    required this.firstDay,
    required this.lastDay,
    this.isEnabled,
    this.disabledLabel,
    this.note,
  });

  final DateTime today;
  final DateTime selected;
  final DateTime firstDay;
  final DateTime lastDay;
  final bool Function(DateTime day)? isEnabled;

  /// Chữ nhỏ dưới ngày nằm trong khoảng nhưng bị [isEnabled] loại (VD "Hết ca").
  final String? disabledLabel;

  /// Dòng ghi chú dưới bảng lịch (VD khoảng ngày được đặt).
  final String? note;

  @override
  State<MonthCalendarSheet> createState() => _MonthCalendarSheetState();
}

class _MonthCalendarSheetState extends State<MonthCalendarSheet> {
  /// Ngày 1 của tháng đang xem.
  late DateTime _month = AppDateUtils.monthStart(widget.selected);

  /// Đang ở chế độ chọn tháng / năm.
  bool _pickingMonth = false;

  /// Năm đang xem ở chế độ chọn tháng.
  late int _year = _month.year;

  DateTime get _firstMonth => AppDateUtils.monthStart(widget.firstDay);
  DateTime get _lastMonth => AppDateUtils.monthStart(widget.lastDay);

  bool _monthInRange(DateTime month) =>
      !month.isBefore(_firstMonth) && !month.isAfter(_lastMonth);

  bool _inRange(DateTime day) => !day.isBefore(widget.firstDay) && !day.isAfter(widget.lastDay);

  void _goMonth(int delta) => setState(() => _month = AppDateUtils.addMonths(_month, delta));

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _pickingMonth ? _yearHeader() : _monthHeader(),
            const SizedBox(height: 8),
            _pickingMonth ? _monthGrid() : _dayGrid(),
            if (widget.note != null) ...[
              const SizedBox(height: 12),
              Text(
                widget.note!,
                key: const ValueKey('cal_note'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _monthHeader() {
    final canPrev = _monthInRange(AppDateUtils.addMonths(_month, -1));
    final canNext = _monthInRange(AppDateUtils.addMonths(_month, 1));
    return Row(
      children: [
        IconButton(
          key: const ValueKey('cal_prev'),
          tooltip: AppStrings.prevMonth,
          onPressed: canPrev ? () => _goMonth(-1) : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Center(
            child: TextButton(
              key: const ValueKey('cal_title'),
              onPressed: () => setState(() {
                _pickingMonth = true;
                _year = _month.year;
              }),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppDateUtils.monthLabel(_month),
                      key: const ValueKey('cal_title_text'),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textPrimary),
                  ],
                ),
              ),
            ),
          ),
        ),
        IconButton(
          key: const ValueKey('cal_next'),
          tooltip: AppStrings.nextMonth,
          onPressed: canNext ? () => _goMonth(1) : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }

  Widget _dayGrid() {
    final cells = AppDateUtils.monthCells(_month);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (final name in AppDateUtils.weekdaysShort)
              Expanded(
                child: Center(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var row = 0; row < cells.length; row += 7)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                for (final day in cells.sublist(row, row + 7))
                  Expanded(child: day == null ? const SizedBox(height: 46) : _dayCell(day)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _dayCell(DateTime day) {
    final inRange = _inRange(day);
    final isSelected = AppDateUtils.isSameDay(day, widget.selected);
    final allowed = inRange && (widget.isEnabled?.call(day) ?? true);
    final isToday = AppDateUtils.isSameDay(day, widget.today);
    final Color foreground = isSelected
        ? Colors.white
        : allowed
            ? AppColors.textPrimary
            : AppColors.textSecondary.withValues(alpha: 0.5);
    final showLabel = widget.disabledLabel != null && inRange && !allowed;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: isSelected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('cal_day_${AppDateUtils.isoDate(day)}'),
          onTap: allowed ? () => Navigator.of(context).pop(day) : null,
          child: Container(
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: isToday && !isSelected ? Border.all(color: AppColors.primary) : null,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected || isToday ? FontWeight.w800 : FontWeight.w600,
                      color: foreground,
                    ),
                  ),
                  if (showLabel)
                    Text(
                      widget.disabledLabel!,
                      style: TextStyle(fontSize: 9, color: foreground),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _yearHeader() {
    final canPrev = _year > widget.firstDay.year;
    final canNext = _year < widget.lastDay.year;
    return Row(
      children: [
        IconButton(
          key: const ValueKey('cal_year_prev'),
          tooltip: AppStrings.prevYear,
          onPressed: canPrev ? () => setState(() => _year--) : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                AppStrings.pickMonthYear,
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
              Text(
                '$_year',
                key: const ValueKey('cal_year'),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          key: const ValueKey('cal_year_next'),
          tooltip: AppStrings.nextYear,
          onPressed: canNext ? () => setState(() => _year++) : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }

  Widget _monthGrid() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < 3; row++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                for (var m = row * 4 + 1; m <= row * 4 + 4; m++)
                  Expanded(child: _monthCell(DateTime(_year, m))),
              ],
            ),
          ),
      ],
    );
  }

  Widget _monthCell(DateTime month) {
    final allowed = _monthInRange(month);
    final isCurrent = AppDateUtils.isSameMonth(month, _month);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: isCurrent
            ? AppColors.primary
            : allowed
                ? Colors.white
                : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('cal_month_${month.month}'),
          onTap: allowed
              ? () => setState(() {
                    _month = month;
                    _pickingMonth = false;
                  })
              : null,
          child: Container(
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isCurrent ? AppColors.primary : AppColors.border),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Tháng ${month.month}',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: isCurrent
                      ? Colors.white
                      : allowed
                          ? AppColors.textPrimary
                          : AppColors.textSecondary.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
