import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_strings.dart';

/// Ô nhập SĐT dùng chung cho Đăng nhập & Đăng ký.
class PhoneField extends StatelessWidget {
  const PhoneField({
    super.key,
    required this.controller,
    required this.validator,
    this.serverError,
    this.onChanged,
  });

  final TextEditingController controller;
  final FormFieldValidator<String> validator;

  /// Lỗi trả về từ hệ thống (VD "Số điện thoại đã được đăng ký"), hiển thị ngay dưới ô.
  final String? serverError;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.telephoneNumber],
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
        LengthLimitingTextInputFormatter(15),
      ],
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: AppStrings.phone,
        prefixIcon: const Icon(Icons.phone_iphone_rounded),
        errorText: serverError,
      ),
    );
  }
}

/// Nút gửi form có trạng thái đang xử lý.
class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: isLoading
            ? const SizedBox(
                key: ValueKey('loading'),
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
              )
            : Text(label, key: const ValueKey('label')),
      ),
    );
  }
}
