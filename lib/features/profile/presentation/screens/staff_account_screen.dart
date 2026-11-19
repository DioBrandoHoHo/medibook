import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/domain/entities/user_gender.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/widgets/logout_dialog.dart';
import '../../domain/repositories/profile_repository.dart';
import '../controllers/profile_controller.dart';
import '../widgets/avatar_actions.dart';
import '../widgets/user_avatar.dart';
import 'change_password_screen.dart';
import 'recovery_email_screen.dart';

/// Tab "Tài khoản" của Staff (thong_tin.txt).
///
/// Màn này KHÔNG giữ bản sao hồ sơ: mọi thông tin đọc từ `AuthController.currentUser`
/// – cùng đối tượng được nạp từ document `users/{uid}` tạo lúc đăng ký. Vì vậy thông tin
/// lúc tạo tài khoản, ở đây và ở lời chào Trang tổng quan luôn là một.
class StaffAccountScreen extends StatelessWidget {
  const StaffAccountScreen({super.key});

  static String genderLabel(UserGender gender) => switch (gender) {
    UserGender.male => AppStrings.genderMale,
    UserGender.female => AppStrings.genderFemale,
    UserGender.other => AppStrings.genderOther,
  };

  @override
  Widget build(BuildContext context) =>
      const AccountView(title: AppStrings.accountTitle, roleLabel: AppStrings.roleStaff);
}

/// Bố cục trang thông tin tài khoản, dùng chung cho tab "Tài khoản" của Staff và tab
/// "Cá nhân" của Customer (thong_tin.txt phần 1 + 2). Hai vai trò chỉ khác tiêu đề,
/// nhãn vai trò và khối [extra] chèn giữa thẻ tài khoản và thẻ thông tin cá nhân.
class AccountView extends StatefulWidget {
  const AccountView({super.key, required this.title, required this.roleLabel, this.extra});

  final String title;
  final String roleLabel;
  final Widget? extra;

  @override
  State<AccountView> createState() => _AccountViewState();
}

class _AccountViewState extends State<AccountView> {
  /// Dùng lại ProfileController (cùng luồng lưu với màn Cập nhật thông tin) để lưu ảnh đại diện.
  late final ProfileController _profile;

  /// Đang xử lý / lưu ảnh -> vòng xoay trên ảnh, chặn bấm lần hai.
  final _avatarBusy = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _profile = ProfileController(context.read<ProfileRepository>(), context.read<AuthController>());
  }

  @override
  void dispose() {
    _profile.dispose();
    _avatarBusy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title;
    final roleLabel = widget.roleLabel;
    final extra = widget.extra;
    final user = context.watch<AuthController>().currentUser;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: SafeArea(
          bottom: false,
          child: user == null
              ? const SizedBox.shrink() // đang đăng xuất, router sắp chuyển trang
              : ListView(
                  // Trang ngắn (vài thẻ) -> dựng sẵn cả trang, kể cả phần dưới mép màn hình
                  // (thẻ Bảo mật / Đăng xuất) để cuộn mượt và luôn tìm thấy khi cần.
                  scrollCacheExtent: const ScrollCacheExtent.pixels(2000),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 12),
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    _AccountCard(
                      user: user,
                      roleLabel: roleLabel,
                      busy: _avatarBusy,
                      onAvatarTap: () => changeAvatar(context, _profile, busy: _avatarBusy),
                    ),
                    if (extra != null) ...[const SizedBox(height: 14), extra],
                    if (user.hasMissingInfo) ...[
                      const SizedBox(height: 12),
                      _IncompleteNotice(onTap: () => context.push(AppRoutes.profileEdit)),
                    ],
                    const SizedBox(height: 14),
                    _InfoCard(user: user, onEdit: () => context.push(AppRoutes.profileEdit)),
                    const SizedBox(height: 14),
                    _SecurityCard(
                      onChangePassword: () => ChangePasswordScreen.open(context),
                      onRecoveryEmail: () => RecoveryEmailScreen.open(context),
                      onLogout: () => confirmLogout(context),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Thẻ tài khoản nền xanh: ảnh đại diện, họ tên, vai trò, số điện thoại.
class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.user,
    required this.roleLabel,
    required this.busy,
    required this.onAvatarTap,
  });

  final AppUser user;
  final String roleLabel;
  final ValueListenable<bool> busy;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryBright, AppColors.primary, AppColors.primaryDark],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: -50,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  _EditableAvatar(user: user, busy: busy, onTap: onAvatarTap),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName.isEmpty ? AppStrings.notUpdated : user.fullName,
                          key: const ValueKey('account_name'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                roleLabel,
                                key: const ValueKey('account_role'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.phone_iphone_rounded,
                              size: 14,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                user.phone,
                                key: const ValueKey('account_phone'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: Colors.white.withValues(alpha: 0.95),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ảnh đại diện bấm được để đổi ảnh: biểu tượng máy ảnh nhỏ ở góc gợi ý thao tác,
/// vòng xoay phủ lên khi đang xử lý / lưu.
class _EditableAvatar extends StatelessWidget {
  const _EditableAvatar({required this.user, required this.busy, required this.onTap});

  final AppUser user;
  final ValueListenable<bool> busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppStrings.avatarChange,
      child: Tooltip(
        message: AppStrings.avatarChange,
        child: GestureDetector(
          key: const ValueKey('account_avatar'),
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
                child: UserAvatar(
                  name: user.fullName,
                  avatar: user.avatar,
                  radius: 32,
                  background: Colors.white,
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: busy,
                builder: (_, isBusy, _) => !isBusy
                    ? const SizedBox.shrink()
                    : Positioned.fill(
                        child: Container(
                          key: const ValueKey('avatar_busy'),
                          margin: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.35),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 1.5),
                  ),
                  child: const Icon(Icons.photo_camera_rounded, size: 15, color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dòng nhắc khi còn trường tuỳ chọn chưa có dữ liệu.
class _IncompleteNotice extends StatelessWidget {
  const _IncompleteNotice({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.warningLight,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('incomplete_notice'),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 20, color: AppColors.warningDark),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.incompleteProfile,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.warningDark,
                      ),
                    ),
                    Text(
                      AppStrings.incompleteProfileHint,
                      style: TextStyle(fontSize: 12.5, color: AppColors.warningDark),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.warningDark),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

/// Thẻ "Thông tin cá nhân": các dòng chỉ đọc + nút Chỉnh sửa.
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.user, required this.onEdit});

  final AppUser user;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final birthDate = user.birthDate;
    final gender = user.gender;
    return _Section(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 6, 0),
            child: Row(
              children: [
                const Icon(Icons.badge_outlined, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    AppStrings.profileTitle,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('edit_profile'),
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: const Text(AppStrings.edit, style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          _InfoRow(
            name: 'full_name',
            icon: Icons.person_outline_rounded,
            label: AppStrings.fullName,
            value: user.fullName,
          ),
          _InfoRow(
            name: 'phone',
            icon: Icons.phone_iphone_rounded,
            label: AppStrings.phone,
            value: user.phone,
          ),
          _InfoRow(
            name: 'email',
            icon: Icons.mail_outline_rounded,
            label: AppStrings.email,
            value: user.email,
          ),
          _InfoRow(
            name: 'birth_date',
            icon: Icons.cake_outlined,
            label: AppStrings.birthDate,
            value: birthDate == null ? '' : AppDateUtils.date(birthDate),
          ),
          _InfoRow(
            name: 'gender',
            icon: Icons.wc_rounded,
            label: AppStrings.gender,
            value: gender == null ? '' : StaffAccountScreen.genderLabel(gender),
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.name,
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String name;
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final missing = value.trim().isEmpty;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: AppColors.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 104,
            child: Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(
              // Chưa có dữ liệu -> "Chưa cập nhật", không để trống.
              missing ? AppStrings.notUpdated : value,
              key: ValueKey('info_$name'),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: missing ? FontWeight.w400 : FontWeight.w600,
                fontStyle: missing ? FontStyle.italic : FontStyle.normal,
                color: missing ? AppColors.textSecondary : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thẻ "Bảo mật": Đổi mật khẩu + Đăng xuất.
class _SecurityCard extends StatelessWidget {
  const _SecurityCard({
    required this.onChangePassword,
    required this.onRecoveryEmail,
    required this.onLogout,
  });

  final VoidCallback onChangePassword;
  final VoidCallback onRecoveryEmail;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return _Section(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, color: AppColors.primary, size: 22),
                SizedBox(width: 8),
                Text(
                  AppStrings.securitySection,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            key: const ValueKey('change_password'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: const Icon(Icons.lock_reset_rounded, color: AppColors.primary),
            title: const Text(
              AppStrings.changePassword,
              style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            subtitle: const Text(
              AppStrings.changePasswordHint,
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            onTap: onChangePassword,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.border),
          ListTile(
            key: const ValueKey('recovery_email'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: const Icon(Icons.mark_email_read_outlined, color: AppColors.primary),
            title: const Text(
              AppStrings.recoveryEmail,
              style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            subtitle: const Text(
              AppStrings.recoveryEmailHint,
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            onTap: onRecoveryEmail,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.border),
          ListTile(
            key: const ValueKey('logout_button'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: const Icon(Icons.logout_rounded, color: AppColors.error),
            title: const Text(
              AppStrings.logout,
              style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.error),
            ),
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}
