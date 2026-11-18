import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/name_utils.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/avatar_image.dart';

/// Ảnh đại diện của NGƯỜI DÙNG ĐANG ĐĂNG NHẬP: có ảnh thì hiện ảnh, chưa có (hoặc dữ liệu hỏng)
/// thì hiện chữ cái đầu của tên như trước. Mọi nơi hiển thị ảnh của chính mình (thẻ tài khoản,
/// phần đầu Trang chủ của Nhân viên và Khách hàng, màn Cập nhật thông tin) dùng widget này với
/// `AuthController.currentUser.avatar` -> đổi ảnh một lần là mọi nơi đổi theo.
class UserAvatar extends StatefulWidget {
  const UserAvatar({
    super.key,
    required this.name,
    required this.avatar,
    this.radius = 24,
    this.background = AppColors.primaryLight,
  });

  final String name;

  /// Chuỗi base64 đã lưu (`AppUser.avatar`); rỗng = chưa có ảnh.
  final String avatar;
  final double radius;
  final Color background;

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  Uint8List? _bytes;
  MemoryImage? _image;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(UserAvatar old) {
    super.didUpdateWidget(old);
    // Chỉ giải mã lại khi ảnh thật sự đổi – tránh nháy ảnh mỗi lần dựng lại.
    if (old.avatar != widget.avatar) _decode();
  }

  void _decode() {
    _bytes = AvatarImage.decode(widget.avatar);
    _image = _bytes == null ? null : MemoryImage(_bytes!);
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) {
      return InitialAvatar(
        initial: NameUtils.initial(widget.name),
        radius: widget.radius,
        background: widget.background,
      );
    }
    return CircleAvatar(
      key: const ValueKey('user_avatar_image'),
      radius: widget.radius,
      backgroundColor: widget.background,
      backgroundImage: image,
      // Ảnh lỗi khi vẽ (rất hiếm) -> không crash, chỉ còn nền.
      onBackgroundImageError: (_, _) {},
    );
  }
}
