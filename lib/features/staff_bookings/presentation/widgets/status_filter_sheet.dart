import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../appointments/domain/entities/appointment_status.dart';
import '../../../appointments/presentation/widgets/status_chip.dart';

/// Bảng chọn "Lọc theo trạng thái" của màn Lịch đặt (bộ lọc nâng cao).
/// Trả về tập trạng thái đã chọn, hoặc `null` nếu người dùng đóng bảng mà không áp dụng.
class StatusFilterSheet extends StatefulWidget {
  const StatusFilterSheet({super.key, required this.initial, this.counts});

  final Set<AppointmentStatus> initial;

  /// Số lịch của từng trạng thái (trong bộ lọc chính đang chọn) để hiện cạnh mỗi lựa chọn.
  /// `null` -> chỉ hiện tên trạng thái.
  final Map<AppointmentStatus, int>? counts;

  static Future<Set<AppointmentStatus>?> show(
    BuildContext context,
    Set<AppointmentStatus> initial, {
    Map<AppointmentStatus, int>? counts,
  }) {
    return showModalBottomSheet<Set<AppointmentStatus>>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      // Cao theo nội dung (không bị giới hạn 9/16 màn hình) để không tràn khi nhãn dài / chữ to.
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatusFilterSheet(initial: initial, counts: counts),
    );
  }

  @override
  State<StatusFilterSheet> createState() => _StatusFilterSheetState();
}

class _StatusFilterSheetState extends State<StatusFilterSheet> {
  // Thứ tự hiển thị theo bảng trạng thái trong đặc tả.
  static const _order = [
    AppointmentStatus.pending,
    AppointmentStatus.confirmed,
    AppointmentStatus.cancelled,
    AppointmentStatus.rejected,
  ];

  late final Set<AppointmentStatus> _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                AppStrings.statusFilter,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                AppStrings.statusFilterHint,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final status in _order)
                    FilterChip(
                      key: ValueKey('status_option_${status.name}'),
                      label: Text(
                        widget.counts == null
                            ? StatusStyle.labelOf(status)
                            : '${StatusStyle.labelOf(status)}  ${widget.counts![status] ?? 0}',
                      ),
                      selected: _selected.contains(status),
                      showCheckmark: true,
                      checkmarkColor: StatusStyle.colorsOf(status).$2,
                      selectedColor: StatusStyle.colorsOf(status).$1,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _selected.contains(status)
                            ? StatusStyle.colorsOf(status).$2
                            : AppColors.textPrimary,
                      ),
                      side: BorderSide(
                        color: _selected.contains(status)
                            ? StatusStyle.colorsOf(status).$2
                            : AppColors.border,
                      ),
                      shape: const StadiumBorder(),
                      onSelected: (on) =>
                          setState(() => on ? _selected.add(status) : _selected.remove(status)),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('status_reset'),
                      onPressed: () => Navigator.of(context).pop(<AppointmentStatus>{}),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      child: const Text(AppStrings.reset),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('status_apply'),
                      onPressed: () => Navigator.of(context).pop(_selected),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      child: const Text(AppStrings.apply),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
