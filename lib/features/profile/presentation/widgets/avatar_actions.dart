import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/avatar_picker.dart';
import '../../domain/avatar_image.dart';
import '../controllers/profile_controller.dart';

/// Luồng đổi ảnh đại diện.
Future<void> changeAvatar(
  BuildContext context,
  ProfileController profile, {
  required ValueNotifier<bool> busy,
}) async {
  if (busy.value || profile.isSaving) return;
  final user = context.read<AuthController>().currentUser;
  if (user == null) return;
  final picker = context.read<AvatarPicker>();
  final messenger = ScaffoldMessenger.of(context);
  void show(String message) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  final action = await showModalBottomSheet<_AvatarAction>(
    context: context,
    backgroundColor: Colors.white,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _AvatarSheet(hasAvatar: user.hasAvatar),
  );
  if (action == null || !context.mounted) return;

  if (action == _AvatarAction.remove) {
    final ok = await _confirmRemove(context);
    if (ok != true) return;
    busy.value = true;
    final saved = await profile.saveAvatar('');
    busy.value = false;
    show(saved ? AppStrings.avatarRemoved : (profile.error ?? AppStrings.errUnknown));
    return;
  }

  // Chọn từ thư viện
  final picked = await picker.pickFromGallery();
  switch (picked) {
    case AvatarPickCancelled():
      return;
    case AvatarPickDenied():
      show(AppStrings.avatarPermissionDenied);
      return;
    case AvatarPickFailed():
      show(AppStrings.avatarPickFailed);
      return;
    case AvatarPicked(:final bytes):
      busy.value = true;
      String encoded;
      try {
        encoded = await picker.prepare(bytes);
      } on AvatarImageException catch (e) {
        busy.value = false;
        show(
          e.error == AvatarImageError.tooLarge
              ? AppStrings.avatarTooLarge
              : AppStrings.avatarUnsupported,
        );
        return;
      } catch (_) {
        busy.value = false;
        show(AppStrings.avatarUnsupported);
        return;
      }
      busy.value = false;
      if (!context.mounted) return;

      final confirmed = await _preview(context, encoded);
      if (confirmed != true) return;
      busy.value = true;
      final saved = await profile.saveAvatar(encoded);
      busy.value = false;
      show(saved ? AppStrings.avatarSaved : (profile.error ?? AppStrings.errUnknown));
  }
}

enum _AvatarAction { gallery, remove }

class _AvatarSheet extends StatelessWidget {
  const _AvatarSheet({required this.hasAvatar});

  final bool hasAvatar;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                AppStrings.avatarTitle,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              key: const ValueKey('avatar_pick_gallery'),
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
              title: const Text(
                AppStrings.avatarPickGallery,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                AppStrings.avatarPickHint,
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
              onTap: () => Navigator.of(context).pop(_AvatarAction.gallery),
            ),
            if (hasAvatar)
              ListTile(
                key: const ValueKey('avatar_remove'),
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                title: const Text(
                  AppStrings.avatarRemove,
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.error),
                ),
                onTap: () => Navigator.of(context).pop(_AvatarAction.remove),
              ),
          ],
        ),
      ),
    );
  }
}

Future<bool?> _confirmRemove(BuildContext context) => showDialog<bool>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    title: const Text(AppStrings.avatarRemoveTitle),
    content: const Text(AppStrings.avatarRemoveMessage),
    actions: [
      TextButton(
        key: const ValueKey('avatar_remove_cancel'),
        onPressed: () => Navigator.of(dialogContext).pop(false),
        child: const Text(AppStrings.cancel),
      ),
      TextButton(
        key: const ValueKey('avatar_remove_confirm'),
        onPressed: () => Navigator.of(dialogContext).pop(true),
        style: TextButton.styleFrom(foregroundColor: AppColors.error),
        child: const Text(AppStrings.avatarRemoveShort),
      ),
    ],
  ),
);

/// Xem trước ảnh đã cắt vuông trong khung tròn trước khi lưu.
Future<bool?> _preview(BuildContext context, String encoded) => showDialog<bool>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    title: const Text(AppStrings.avatarPreviewTitle),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          key: const ValueKey('avatar_preview_image'),
          radius: 72,
          backgroundColor: AppColors.primaryLight,
          backgroundImage: MemoryImage(base64Decode(encoded)),
        ),
        const SizedBox(height: 14),
        const Text(
          AppStrings.avatarPreviewHint,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    ),
    actions: [
      TextButton(
        key: const ValueKey('avatar_preview_cancel'),
        onPressed: () => Navigator.of(dialogContext).pop(false),
        child: const Text(AppStrings.cancel),
      ),
      FilledButton(
        key: const ValueKey('avatar_preview_save'),
        onPressed: () => Navigator.of(dialogContext).pop(true),
        child: const Text(AppStrings.avatarSave),
      ),
    ],
  ),
);
