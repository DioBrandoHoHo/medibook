import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';

/// Ô mật khẩu có nút con mắt. Mỗi instance tự giữ trạng thái ẩn/hiện riêng
/// nên các ô Mật khẩu / Xác nhận mật khẩu không ảnh hưởng lẫn nhau (Mục 4.3).
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.onChanged,
    this.fieldKey,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.autovalidateMode,
    this.autofillHints,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final GlobalKey<FormFieldState<String>>? fieldKey;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final AutovalidateMode? autovalidateMode;

  /// Gợi ý cho trình quản lý mật khẩu của điện thoại (VD [AutofillHints.password]).
  /// `null` = không gợi ý (các màn khác giữ nguyên hành vi cũ).
  final Iterable<String>? autofillHints;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: widget.fieldKey,
      controller: widget.controller,
      obscureText: _obscure,
      enableSuggestions: false,
      autocorrect: false,
      textInputAction: widget.textInputAction,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      validator: widget.validator,
      autovalidateMode: widget.autovalidateMode,
      autofillHints: widget.autofillHints,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: _obscure ? AppStrings.showPassword : AppStrings.hidePassword,
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
            child: Icon(
              _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              key: ValueKey(_obscure),
            ),
          ),
        ),
      ),
    );
  }
}
