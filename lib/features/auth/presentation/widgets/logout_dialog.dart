import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../controllers/auth_controller.dart';

/// Hỏi lại rồi đăng xuất. Dùng chung cho tab Tài khoản (Staff) và tab Cá nhân (Customer).
/// Đồng ý -> xoá phiên; router tự đưa về màn Đăng nhập.
Future<void> confirmLogout(BuildContext context) async {
  final auth = context.read<AuthController>();
  final agreed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Text(AppStrings.logout),
      titleTextStyle: const TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      content: const Text(AppStrings.logoutConfirm),
      actions: [
        TextButton(
          key: const ValueKey('logout_cancel'),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text(AppStrings.cancel),
        ),
        TextButton(
          key: const ValueKey('logout_agree'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text(AppStrings.logout),
        ),
      ],
    ),
  );
  if (agreed == true) await auth.logout();
}
