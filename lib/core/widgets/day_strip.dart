import 'package:flutter/material.dart';

import '../constants/app_strings.dart';
import '../theme/app_colors.dart';
import '../utils/app_date_utils.dart';

/// Dải chọn ngày.
class DayStrip extends StatefulWidget {
  const DayStrip({
    super.key,
    required this.today,
    required this.selected,
    required this.onSelect,
    this.dayCount = 14,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.isEnabled,
    this.showMonth = false,
  });

  final DateTime today;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;
  final int dayCount;
  final EdgeInsets padding;

  /// Ngày nào chọn được.
  final bool Function(DateTime day)? isEnabled;

  /// Hiện thêm dòng tháng dưới số ngày (dùng khi dải dài qua nhiều tháng).
  final bool showMonth;

  static const _cellWidth = 54.0;
  static const _gap = 8.0;

  @override
  State<DayStrip> createState() => _DayStripState();
}

class _DayStripState extends State<DayStrip> {
  late final ScrollController _scroll;

  int get _selectedIndex => AppDateUtils.daysBetween(widget.today, widget.selected)
      .clamp(0, widget.dayCount - 1);

  @override
  void initState() {
    super.initState();
    final offset = (_selectedIndex - 1) * (DayStrip._cellWidth + DayStrip._gap);
    _scroll = ScrollController(initialScrollOffset: offset < 0 ? 0 : offset);
  }

  @override
  void didUpdateWidget(DayStrip old) {
    super.didUpdateWidget(old);
    if (!AppDateUtils.isSameDay(old.selected, widget.selected) ||
        !AppDateUtils.isSameDay(old.today, widget.today)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    }
  }

  /// Cuộn để ngày đang chọn nằm giữa vùng nhìn.
  void _reveal() {
    if (!mounted || !_scroll.hasClients) return;
    final position = _scroll.position;
    final target = (widget.padding.left +
            _selectedIndex * (DayStrip._cellWidth + DayStrip._gap) -
            (position.viewportDimension - DayStrip._cellWidth) / 2)
        .clamp(0.0, position.maxScrollExtent);
    if ((target - position.pixels).abs() < 1) return;
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = widget.today;
    return SizedBox(
      height: widget.showMonth ? 76 : 68,
      child: ListView.separated(
        key: const ValueKey('day_strip'),
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: widget.padding,
        itemCount: widget.dayCount,
        separatorBuilder: (_, _) => const SizedBox(width: DayStrip._gap),
        itemBuilder: (context, i) {
          final day = DateTime(today.year, today.month, today.day + i);
          final isSelected = AppDateUtils.isSameDay(day, widget.selected);
          final enabled = isSelected || (widget.isEnabled?.call(day) ?? true);
          final Color foreground = isSelected
              ? Colors.white
              : enabled
                  ? AppColors.textPrimary
                  : AppColors.textSecondary.withValues(alpha: 0.55);
          final Color secondary = isSelected
              ? Colors.white
              : enabled
                  ? AppColors.textSecondary
                  : AppColors.textSecondary.withValues(alpha: 0.55);
          return Material(
            color: isSelected
                ? AppColors.primary
                : enabled
                    ? Colors.white
                    : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: ValueKey('day_$i'),
              onTap: enabled ? () => widget.onSelect(day) : null,
              child: Container(
                width: DayStrip._cellWidth,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        i == 0 ? AppStrings.today : AppDateUtils.weekdayShort(day),
                        style: TextStyle(
                          fontSize: i == 0 ? 11 : 12.5,
                          fontWeight: FontWeight.w600,
                          color: secondary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: foreground,
                          height: 1.1,
                        ),
                      ),
                      if (widget.showMonth)
                        Text(
                          AppStrings.monthShort(day.month),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: secondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
