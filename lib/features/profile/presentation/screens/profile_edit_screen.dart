import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/route_guard.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../auth/domain/entities/user_gender.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/repositories/profile_repository.dart';
import '../controllers/profile_controller.dart';
import '../widgets/user_avatar.dart';

/// Cập nhật thông tin cá nhân (thong_tin.txt mục 4).
/// Mọi trường được điền sẵn từ hồ sơ hiện có – họ tên & SĐT chính là dữ liệu lúc đăng ký.
class ProfileEditScreen extends StatelessWidget {
  const ProfileEditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => ProfileController(ctx.read<ProfileRepository>(), ctx.read<AuthController>()),
      child: const _ProfileEditView(),
    );
  }
}

class _ProfileEditView extends StatefulWidget {
  const _ProfileEditView();

  @override
  State<_ProfileEditView> createState() => _ProfileEditViewState();
}

class _ProfileEditViewState extends State<_ProfileEditView> {
  static const _genderLabels = {
    UserGender.male: AppStrings.genderMale,
    UserGender.female: AppStrings.genderFemale,
    UserGender.other: AppStrings.genderOther,
  };

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullName;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _birthDate;
  UserGender? _gender;

  /// Giá trị lúc mở màn – để biết người dùng đã sửa gì chưa.
  late final String _initialName;
  late final String _initialEmail;
  late final String _initialBirth;
  late final UserGender? _initialGender;

  /// Chỉ hỏi khi màn được mở chồng lên một màn khác (có chỗ để quay lại).
  bool _canGuard = false;

  /// Đã lưu xong / đã đồng ý bỏ thay đổi -> cho phép rời màn.
  bool _allowPop = false;

  bool get _isDirty =>
      _fullName.text.trim() != _initialName ||
      _email.text.trim() != _initialEmail ||
      _birthDate.text.trim() != _initialBirth ||
      _gender != _initialGender;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _canGuard = Navigator.of(context).canPop();
  }

  void _onFieldChanged() => setState(() {});

  Future<void> _onPopBlocked(bool didPop) async {
    if (didPop) return;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(AppStrings.discardChangesTitle),
        content: const Text(AppStrings.discardChangesMessage),
        actions: [
          TextButton(
            key: const ValueKey('discard_keep_editing'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(AppStrings.keepEditing),
          ),
          TextButton(
            key: const ValueKey('discard_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text(AppStrings.discardChanges),
          ),
        ],
      ),
    );
    if (discard != true || !mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthController>().currentUser;
    final birthDate = user?.birthDate;
    _fullName = TextEditingController(text: user?.fullName ?? '');
    _phone = TextEditingController(text: user?.phone ?? '');
    _email = TextEditingController(text: user?.email ?? '');
    _birthDate = TextEditingController(text: birthDate == null ? '' : AppDateUtils.date(birthDate));
    _gender = user?.gender;
    _initialName = _fullName.text.trim();
    _initialEmail = _email.text.trim();
    _initialBirth = _birthDate.text.trim();
    _initialGender = _gender;
    for (final c in [_fullName, _email, _birthDate]) {
      c.addListener(_onFieldChanged);
    }
  }

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _email.dispose();
    _birthDate.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final birthText = _birthDate.text.trim();
    final ok = await context.read<ProfileController>().save(
      fullName: _fullName.text,
      email: _email.text,
      birthDate: birthText.isEmpty ? null : AppDateUtils.parseDisplayDate(birthText),
      gender: _gender,
    );
    if (!mounted || !ok) return;
    setState(() => _allowPop = true); // đã lưu -> rời màn không cần hỏi
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text(AppStrings.profileSaved)));
    // Mở từ tab Tài khoản / Cá nhân -> quay lại; mở từ bước hỏi hồ sơ -> vào trang chính theo vai trò.
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RouteGuard.homeFor(context.read<AuthController>().currentUser!.role));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProfileController>();
    // Đang sửa dở mà quay lại -> hỏi "Bỏ thay đổi?" (chỉ khi mở từ tab Tài khoản / Cá nhân).
    return PopScope(
      canPop: !_canGuard || _allowPop || !_isDirty,
      onPopInvokedWithResult: (didPop, _) => _onPopBlocked(didPop),
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          title: const Text(AppStrings.profileEditTitle),
          backgroundColor: AppColors.surface,
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Center(
                  // Ảnh đã lưu (nếu có); chưa có ảnh thì chữ cái đầu đổi theo họ tên đang gõ.
                  child: UserAvatar(
                    name: _fullName.text,
                    avatar: context.watch<AuthController>().currentUser?.avatar ?? '',
                    radius: 40,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (controller.error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Text(
                            controller.error!,
                            key: const ValueKey('profile_error'),
                            style: const TextStyle(color: AppColors.error),
                          ),
                        ),
                      TextFormField(
                        controller: _fullName,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        validator: Validators.fullName,
                        onChanged: (_) => setState(() {}), // cập nhật chữ cái ảnh đại diện
                        decoration: const InputDecoration(
                          labelText: AppStrings.fullName,
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _phone,
                        readOnly: true,
                        enabled: false,
                        decoration: const InputDecoration(
                          labelText: AppStrings.phone,
                          prefixIcon: Icon(Icons.phone_iphone_rounded),
                          helperText: AppStrings.phoneReadOnlyHint,
                          helperMaxLines: 2,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const ValueKey('email_field'),
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        validator: Validators.optionalEmail,
                        decoration: const InputDecoration(
                          labelText: '${AppStrings.email} (${AppStrings.optional})',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const ValueKey('birth_date_field'),
                        controller: _birthDate,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [_DateInputFormatter()],
                        validator: (value) => Validators.optionalBirthDate(value, DateTime.now()),
                        decoration: const InputDecoration(
                          labelText: '${AppStrings.birthDate} (${AppStrings.optional})',
                          hintText: AppStrings.birthDateHint,
                          prefixIcon: Icon(Icons.cake_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '${AppStrings.gender} (${AppStrings.optional})',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final entry in _genderLabels.entries)
                            ChoiceChip(
                              key: ValueKey('gender_${entry.key.name}'),
                              label: Text(entry.value),
                              selected: _gender == entry.key,
                              showCheckmark: false,
                              selectedColor: AppColors.primary,
                              backgroundColor: Colors.white,
                              labelStyle: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: _gender == entry.key ? Colors.white : AppColors.textPrimary,
                              ),
                              side: BorderSide(
                                color: _gender == entry.key ? AppColors.primary : AppColors.border,
                              ),
                              shape: const StadiumBorder(),
                              // Bấm lại lựa chọn đang chọn để bỏ chọn.
                              onSelected: (on) => setState(() => _gender = on ? entry.key : null),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: controller.isSaving ? null : _save,
                  child: controller.isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : const Text(AppStrings.save),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tự chèn dấu "/" khi gõ ngày sinh: 15081995 -> 15/08/1995.
class _DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 8) digits = digits.substring(0, 8);
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 2 || i == 4) buffer.write('/');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
