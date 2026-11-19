import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/route_guard.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/validators.dart';
import '../controllers/auth_controller.dart';
import 'auth_error_banner.dart';
import 'auth_form_parts.dart';
import 'password_field.dart';
import 'password_rules_checklist.dart';

/// Form Đăng ký Customer.
class RegisterForm extends StatefulWidget {
  const RegisterForm({super.key, this.initialPhone = '', this.onPhoneChanged, this.onGoToLogin});

  /// SĐT đang gõ ở chế độ Đăng nhập.
  final String initialPhone;
  final ValueChanged<String>? onPhoneChanged;

  /// Chuyển sang Đăng nhập (khi số đã được đăng ký).
  final VoidCallback? onGoToLogin;

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _confirmKey = GlobalKey<FormFieldState<String>>();
  final _fullName = TextEditingController();
  late final _phone = TextEditingController(text: widget.initialPhone);
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  PasswordRules _rules = PasswordRules.check('');
  bool _submitted = false;

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _onPasswordChanged(String value) {
    setState(() => _rules = PasswordRules.check(value));
    if (_confirm.text.isNotEmpty) _confirmKey.currentState?.validate();
    context.read<AuthController>().clearErrors();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthController>();
    final ok = await auth.register(
      fullName: _fullName.text,
      phone: _phone.text,
      password: _password.text,
    );
    if (!mounted || !ok) return;
    TextInput.finishAutofillContext();
    context.go(RouteGuard.afterAuth(auth.currentUser!));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return Form(
      key: _formKey,
      autovalidateMode: _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthErrorBanner(message: auth.generalError),
            TextFormField(
              controller: _fullName,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              inputFormatters: [
                LengthLimitingTextInputFormatter(Validators.fullNameMaxLength + 10),
              ],
              validator: Validators.fullName,
              decoration: const InputDecoration(
                labelText: AppStrings.fullName,
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 14),
            PhoneField(
              controller: _phone,
              validator: Validators.phone,
              serverError: auth.phoneError,
              onChanged: (value) {
                auth.clearErrors();
                widget.onPhoneChanged?.call(value);
              },
            ),
            if (auth.phoneError == AppStrings.errPhoneExists && widget.onGoToLogin != null)
              PhoneShortcut(
                key: const ValueKey('goto_login'),
                label: AppStrings.loginWithThisPhone,
                onTap: widget.onGoToLogin!,
              ),
            const SizedBox(height: 14),
            PasswordField(
              key: const ValueKey('register-password'),
              controller: _password,
              label: AppStrings.password,
              autofillHints: const [AutofillHints.newPassword],
              validator: Validators.newPassword,
              onChanged: _onPasswordChanged,
            ),
            const SizedBox(height: 10),
            PasswordRulesChecklist(rules: _rules),
            const SizedBox(height: 14),
            PasswordField(
              key: const ValueKey('register-confirm'),
              fieldKey: _confirmKey,
              controller: _confirm,
              label: AppStrings.confirmPassword,
              textInputAction: TextInputAction.done,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (v) => Validators.confirmPassword(v, _password.text),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),
            AuthSubmitButton(
              label: AppStrings.register,
              isLoading: auth.isLoading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
