import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../domain/staff_home_summary.dart';

/// Thẻ "Có X lịch đặt mới cần xử lý". X = số lịch Pending ở mọi ngày.
///
/// Dưới tiêu đề có thêm dòng chia nhỏ X (hôm nay / ngày khác) và lịch chờ gần nhất – tất cả lấy từ [StaffHomeSummary], thẻ không tự đếm.
/// Nhờ dòng "Hôm nay …" người dùng hiểu vì sao X có thể lớn hơn chỉ số "Chờ xác nhận" hôm nay.
class PendingNoticeCard extends StatelessWidget {
  const PendingNoticeCard({
    super.key,
    required this.summary,
    required this.now,
    required this.onTap,
  });

  final StaffHomeSummary summary;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = summary.pendingAllDays;
    final hasPending = count > 0;
    // Có lịch chờ = việc cần làm -> thẻ trắng nổi bật với điểm nhấn cam (màu của "Chờ xác nhận");
    // không còn lịch chờ -> thẻ xanh nhạt nhẹ nhàng.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: hasPending ? AppColors.cardShadow : null,
      ),
      child: Material(
        color: hasPending ? Colors.white : AppColors.primaryLight,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('pending_notice'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 8, 13),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: hasPending ? AppColors.warningLight : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    hasPending ? Icons.campaign_rounded : Icons.task_alt_rounded,
                    color: hasPending ? AppColors.warningDark : AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasPending ? AppStrings.pendingNotice(count) : AppStrings.noPendingNotice,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 3),
                      if (hasPending) ..._details() else _line(AppStrings.noPendingHint),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: hasPending ? AppColors.warningDark : AppColors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _details() {
    final next = summary.nextPending;
    return [
      _line(
        '${AppStrings.pendingToday(summary.todayPending)}  •  '
        '${AppStrings.pendingOtherDays(summary.pendingOtherDays)}',
        key: const ValueKey('pending_breakdown'),
      ),
      if (next != null)
        _line(
          AppStrings.nextPendingAt(
            AppDateUtils.shortDayLabel(next.startAt, now),
            AppDateUtils.time(next.startAt),
          ),
          key: const ValueKey('pending_next'),
        ),
    ];
  }

  Widget _line(String text, {Key? key}) => Text(
    text,
    key: key,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
  );
}
