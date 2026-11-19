import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/widgets/password_field.dart';
import '../../../auth/presentation/widgets/password_rules_checklist.dart';

/// Đổi mật khẩu.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ChangePasswordScreen()),
    );
  }

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  bool _busy = false;

  /// Lỗi từ hệ thống gắn với ô Mật khẩu hiện tại.
  String? _currentError;

  /// Lỗi chung (mất mạng, thao tác quá nhiều lần...).
  String? _generalError;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _currentError = null;
      _generalError = null;
    });
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthController>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    FocusScope.of(context).unfocus();

    setState(() => _busy = true);
    final failure = await auth.changePassword(
      currentPassword: _current.text,
      newPassword: _next.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (failure == null) {
      messenger.showSnackBar(const SnackBar(content: Text(AppStrings.passwordChanged)));
      navigator.pop();
      return;
    }
    setState(() {
      if (failure is AuthFailure && failure.field == AuthField.password) {
        _currentError = failure.message;
      } else {
        _generalError = failure.message;
      }
    });
    _formKey.currentState!.validate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text(AppStrings.changePassword),
        backgroundColor: AppColors.surface,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
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
                    if (_generalError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _generalError!,
                          key: const ValueKey('change_password_error'),
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    KeyedSubtree(
                      key: const ValueKey('current_password'),
                      child: PasswordField(
                        controller: _current,
                        label: AppStrings.currentPassword,
                        validator: (value) =>
                            Validators.loginPassword(value) ?? _currentError,
                        onChanged: (_) {
                          if (_currentError != null) setState(() => _currentError = null);
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    KeyedSubtree(
                      key: const ValueKey('new_password'),
                      child: PasswordField(
                        controller: _next,
                        label: AppStrings.newPassword,
                        validator: (value) => Validators.changedPassword(value, _current.text),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(height: 10),
                    PasswordRulesChecklist(rules: PasswordRules.check(_next.text)),
                    const SizedBox(height: 14),
                    KeyedSubtree(
                      key: const ValueKey('confirm_new_password'),
                      child: PasswordField(
                        controller: _confirm,
                        label: AppStrings.confirmNewPassword,
                        textInputAction: TextInputAction.done,
                        validator: (value) => Validators.confirmPassword(value, _next.text),
                        onSubmitted: (_) => _busy ? null : _submit(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const ValueKey('submit_change_password'),
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                      )
                    : const Text(AppStrings.changePassword),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
