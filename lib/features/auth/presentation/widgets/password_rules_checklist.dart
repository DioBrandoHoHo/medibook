import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';

/// Checklist 4 điều kiện mật khẩu, đổi màu ngay khi người dùng gõ.
class PasswordRulesChecklist extends StatelessWidget {
  const PasswordRulesChecklist({super.key, required this.rules});

  final PasswordRules rules;

  @override
  Widget build(BuildContext context) {
    final items = [
      (AppStrings.ruleMinLength, rules.hasMinLength),
      (AppStrings.ruleUppercase, rules.hasUppercase),
      (AppStrings.ruleDigit, rules.hasDigit),
      (AppStrings.ruleSpecial, rules.hasSpecialChar),
    ];
    final passed = items.where((e) => e.$2).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thanh độ mạnh
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: passed / items.length),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 5,
                backgroundColor: AppColors.border,
                color: Color.lerp(AppColors.warning, AppColors.success, value),
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final (label, ok) in items) _RuleRow(label: label, ok: ok),
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.label, required this.ok});
  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 250);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          AnimatedContainer(
            duration: duration,
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ok ? AppColors.success : Colors.transparent,
              border: Border.all(color: ok ? AppColors.success : AppColors.textSecondary, width: 1.4),
            ),
            child: AnimatedOpacity(
              duration: duration,
              opacity: ok ? 1 : 0,
              child: const Icon(Icons.check_rounded, size: 13, color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: duration,
              style: TextStyle(
                fontSize: 13,
                color: ok ? AppColors.success : AppColors.textSecondary,
                fontWeight: ok ? FontWeight.w600 : FontWeight.w400,
              ),
              child: Text(label, semanticsLabel: '$label: ${ok ? 'đã đạt' : 'chưa đạt'}'),
            ),
          ),
        ],
      ),
    );
  }
}
