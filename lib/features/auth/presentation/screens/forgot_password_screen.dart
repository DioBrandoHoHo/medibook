import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_form_parts.dart';

/// Màn "Quên mật khẩu" (dang_ky_dang_nhap.txt – phần bổ sung): nhập SĐT -> hệ thống gửi liên kết
/// đặt lại mật khẩu tới email khôi phục ĐÃ xác minh của tài khoản.
/// Mật khẩu mới được đặt trên trang của Firebase; app không nhận hay lưu mật khẩu ở bước này.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialPhone = ''});

  /// SĐT đang gõ dở ở form Đăng nhập (điền sẵn).
  final String initialPhone;

  static Future<void> open(BuildContext context, {String initialPhone = ''}) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ForgotPasswordScreen(initialPhone: initialPhone)),
    );
  }

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _phone = TextEditingController(text: widget.initialPhone);

  bool _busy = false;
  String? _phoneError;
  String? _generalError;

  /// Email (đã che bớt) vừa được gửi liên kết. Khác null = đã gửi xong.
  String? _sentTo;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _phoneError = null;
      _generalError = null;
    });
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _busy = true);
    final (maskedEmail, failure) = await context.read<AuthController>().sendPasswordReset(_phone.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _sentTo = maskedEmail;
      if (failure is AuthFailure && failure.field == AuthField.phone) {
        _phoneError = failure.message;
      } else {
        _generalError = failure?.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sentTo = _sentTo;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text(AppStrings.forgotTitle),
        backgroundColor: AppColors.surface,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppColors.cardShadow,
              ),
              child: sentTo == null ? _form() : _sent(sentTo),
            ),
          ],
        ),
      ),
    );
  }

  Widget _form() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _RoundIcon(icon: Icons.lock_reset_rounded),
          const SizedBox(height: 14),
          const Text(
            AppStrings.forgotIntro,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.4, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          if (_generalError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _generalError!,
                key: const ValueKey('forgot_error'),
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          KeyedSubtree(
            key: const ValueKey('forgot_phone'),
            child: PhoneField(
              controller: _phone,
              validator: Validators.phone,
              serverError: _phoneError,
              onChanged: (_) {
                if (_phoneError != null) setState(() => _phoneError = null);
              },
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const ValueKey('forgot_submit'),
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                  )
                : const Text(AppStrings.sendResetLink),
          ),
        ],
      ),
    );
  }

  Widget _sent(String maskedEmail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _RoundIcon(icon: Icons.mark_email_read_rounded, color: AppColors.success),
        const SizedBox(height: 14),
        const Text(
          AppStrings.resetSentTitle,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          AppStrings.resetSentBody(maskedEmail),
          key: const ValueKey('forgot_sent'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        FilledButton(
          key: const ValueKey('forgot_back'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(AppStrings.backToLogin),
        ),
      ],
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, this.color = AppColors.primary});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 32),
      ),
    );
  }
}
