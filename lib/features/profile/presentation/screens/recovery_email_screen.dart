import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/domain/entities/recovery_email.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/widgets/password_field.dart';

/// Màn "Email khôi phục mật khẩu".
class RecoveryEmailScreen extends StatefulWidget {
  const RecoveryEmailScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const RecoveryEmailScreen()),
    );
  }

  @override
  State<RecoveryEmailScreen> createState() => _RecoveryEmailScreenState();
}

class _RecoveryEmailScreenState extends State<RecoveryEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  RecoveryEmail? _status;
  bool _loading = true;
  String? _loadError;

  bool _busy = false;
  String? _passwordError;
  String? _generalError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load(prefill: true);
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _load({bool prefill = false}) async {
    final auth = context.read<AuthController>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final (status, failure) = await auth.recoveryEmailStatus();
    if (!mounted) return;
    if (failure == AuthFailure.sessionExpired) {
      var renewed = await auth.resumeAfterEmailChange() == null;
      if (!renewed && mounted) {
        setState(() => _loading = false);
        renewed = await _askPassword();
      }
      if (!mounted) return;
      if (renewed) {
        messenger.showSnackBar(const SnackBar(content: Text(AppStrings.recoveryVerifiedDone)));
        await _load();
        return;
      }
      navigator.pop();
      await auth.logout();
      messenger.showSnackBar(const SnackBar(content: Text(AppStrings.reloginAfterVerify)));
      return;
    }
    setState(() {
      _loading = false;
      _status = status;
      _loadError = failure?.message;
      if (prefill && status != null && _email.text.isEmpty) {
        _email.text = status.pending ?? status.verified ?? auth.currentUser?.email ?? '';
      }
    });
  }

  /// Hỏi lại mật khẩu để tiếp tục phiên.
  Future<bool> _askPassword() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ResumeSessionDialog(),
    );
    return ok == true;
  }

  Future<void> _submit() async {
    setState(() {
      _passwordError = null;
      _generalError = null;
    });
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthController>();
    final messenger = ScaffoldMessenger.of(context);
    FocusScope.of(context).unfocus();

    setState(() => _busy = true);
    final failure = await auth.requestRecoveryEmail(
      email: _email.text.trim(),
      currentPassword: _password.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (failure == null) {
      _password.clear();
      messenger.showSnackBar(const SnackBar(content: Text(AppStrings.verifySent)));
      await _load();
      return;
    }
    setState(() {
      if (failure is AuthFailure && failure.field == AuthField.password) {
        _passwordError = failure.message;
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
        title: const Text(AppStrings.recoveryEmail),
        backgroundColor: AppColors.surface,
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_loading && _status == null) return const LoadingView();
    if (_loadError != null && _status == null) {
      return SingleChildScrollView(
        child: ErrorRetryView(message: _loadError!, onRetry: _load),
      );
    }
    final status = _status ?? const RecoveryEmail();
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _StatusCard(status: status, checking: _loading, onCheck: _load),
          const SizedBox(height: 14),
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
                const Text(
                  AppStrings.recoveryIntro,
                  style: TextStyle(fontSize: 13.5, height: 1.4, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                if (_generalError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _generalError!,
                      key: const ValueKey('recovery_error'),
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                TextFormField(
                  key: const ValueKey('recovery_email_field'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  validator: Validators.requiredEmail,
                  decoration: const InputDecoration(
                    labelText: AppStrings.email,
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                    fillColor: AppColors.surface,
                  ),
                ),
                const SizedBox(height: 14),
                KeyedSubtree(
                  key: const ValueKey('recovery_password'),
                  child: PasswordField(
                    controller: _password,
                    label: AppStrings.currentPassword,
                    textInputAction: TextInputAction.done,
                    validator: (value) => Validators.loginPassword(value) ?? _passwordError,
                    onChanged: (_) {
                      if (_passwordError != null) setState(() => _passwordError = null);
                    },
                    onSubmitted: (_) => _busy ? null : _submit(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const ValueKey('recovery_submit'),
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                  )
                : const Text(AppStrings.sendVerifyLink),
          ),
        ],
      ),
    );
  }
}

/// Hộp nhập lại mật khẩu sau khi email khôi phục được xác minh.
class _ResumeSessionDialog extends StatefulWidget {
  const _ResumeSessionDialog();

  @override
  State<_ResumeSessionDialog> createState() => _ResumeSessionDialogState();
}

class _ResumeSessionDialogState extends State<_ResumeSessionDialog> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_password.text.isEmpty) {
      setState(() => _error = AppStrings.errPasswordRequired);
      return;
    }
    final auth = context.read<AuthController>();
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    final failure = await auth.resumeAfterEmailChange(password: _password.text);
    if (!mounted) return;
    if (failure == null) {
      navigator.pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _error = failure.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(AppStrings.resumeTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(AppStrings.resumeBody, style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 14),
          KeyedSubtree(
            key: const ValueKey('resume_password'),
            child: PasswordField(
              controller: _password,
              label: AppStrings.password,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _busy ? null : _continue(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, key: const ValueKey('resume_error'), style: const TextStyle(color: AppColors.error)),
          ],
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('resume_skip'),
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text(AppStrings.resumeSkip),
        ),
        FilledButton(
          key: const ValueKey('resume_continue'),
          onPressed: _busy ? null : _continue,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text(AppStrings.resumeContinue),
        ),
      ],
    );
  }
}

/// Thẻ trạng thái.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status, required this.checking, required this.onCheck});

  final RecoveryEmail status;
  final bool checking;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    final verified = status.verified;
    final pending = status.pending;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (verified == null && pending == null)
            const _StatusLine(
              name: 'none',
              icon: Icons.mail_lock_outlined,
              color: AppColors.textSecondary,
              label: AppStrings.recoveryNone,
              value: AppStrings.recoveryEmailHint,
            ),
          if (verified != null)
            _StatusLine(
              name: 'verified',
              icon: Icons.verified_rounded,
              color: AppColors.success,
              label: AppStrings.recoveryVerified,
              value: verified,
            ),
          if (pending != null) ...[
            if (verified != null) const SizedBox(height: 12),
            _StatusLine(
              name: 'pending',
              icon: Icons.hourglass_top_rounded,
              color: AppColors.warningDark,
              label: AppStrings.recoveryPending,
              value: pending,
            ),
            const SizedBox(height: 8),
            const Text(
              AppStrings.recoveryPendingHint,
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('recovery_check'),
                onPressed: checking ? null : onCheck,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(AppStrings.recoveryCheck),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.name,
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final String name;
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                key: ValueKey('recovery_label_$name'),
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: color),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                key: ValueKey('recovery_value_$name'),
                style: const TextStyle(fontSize: 14.5, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
