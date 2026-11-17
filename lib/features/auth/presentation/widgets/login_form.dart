import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/route_guard.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/validators.dart';
import '../controllers/auth_controller.dart';
import '../screens/forgot_password_screen.dart';
import 'auth_error_banner.dart';
import 'auth_form_parts.dart';
import 'password_field.dart';

/// Form Đăng nhập (Mục 5): SĐT + mật khẩu.
class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthController>();
    final ok = await auth.login(phone: _phone.text, password: _password.text);
    if (!mounted || !ok) return;
    context.go(RouteGuard.afterAuth(auth.currentUser!));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return Form(
      key: _formKey,
      autovalidateMode: _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthErrorBanner(message: auth.generalError),
          PhoneField(
            controller: _phone,
            validator: Validators.phone,
            serverError: auth.phoneError,
            onChanged: (_) => auth.clearErrors(),
          ),
          const SizedBox(height: 14),
          PasswordField(
            controller: _password,
            label: AppStrings.password,
            validator: Validators.loginPassword,
            textInputAction: TextInputAction.done,
            onChanged: (_) => auth.clearErrors(),
            onSubmitted: (_) => _submit(),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const ValueKey('forgot_password'),
              onPressed: auth.isLoading
                  ? null
                  : () => ForgotPasswordScreen.open(context, initialPhone: _phone.text),
              child: const Text(AppStrings.forgotPassword),
            ),
          ),
          const SizedBox(height: 10),
          AuthSubmitButton(
            label: AppStrings.login,
            isLoading: auth.isLoading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
