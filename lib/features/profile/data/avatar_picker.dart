import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/avatar_image.dart';

/// Kết quả chọn ảnh từ thư viện.
sealed class AvatarPickResult {
  const AvatarPickResult();
}

/// Đã chọn được ảnh.
class AvatarPicked extends AvatarPickResult {
  const AvatarPicked(this.bytes);

  final Uint8List bytes;
}

/// Người dùng đóng thư viện mà không chọn ảnh.
class AvatarPickCancelled extends AvatarPickResult {
  const AvatarPickCancelled();
}

/// Không được cấp quyền truy cập ảnh.
class AvatarPickDenied extends AvatarPickResult {
  const AvatarPickDenied();
}

/// Lỗi khác khi mở thư viện / đọc file.
class AvatarPickFailed extends AvatarPickResult {
  const AvatarPickFailed();
}

/// Lấy ảnh từ thư viện của điện thoại và chuẩn bị ảnh để lưu.
/// Tách thành interface để test thay bằng bản giả (không mở thư viện, không chạy isolate).
abstract interface class AvatarPicker {
  Future<AvatarPickResult> pickFromGallery();

  /// Cắt vuông + thu nhỏ + nén ([AvatarImage.process]). Ném [AvatarImageException].
  Future<String> prepare(Uint8List bytes);
}

/// Bản thật dùng `image_picker`. Trên Android 13+ đây là Photo Picker của hệ thống – KHÔNG cần
/// xin quyền đọc bộ nhớ; Android cũ hơn dùng trình chọn file của hệ thống.
/// `maxWidth/maxHeight` để hệ thống thu nhỏ trước, giảm bộ nhớ khi app cắt và nén lại.
class ImagePickerAvatarPicker implements AvatarPicker {
  ImagePickerAvatarPicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<AvatarPickResult> pickFromGallery() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 92,
        requestFullMetadata: false,
      );
      if (file == null) return const AvatarPickCancelled();
      return AvatarPicked(await file.readAsBytes());
    } on PlatformException catch (e) {
      final code = e.code.toLowerCase();
      if (code.contains('denied') || code.contains('permission')) {
        return const AvatarPickDenied();
      }
      return const AvatarPickFailed();
    } catch (_) {
      return const AvatarPickFailed();
    }
  }

  /// Chạy ở isolate riêng để giải mã / nén ảnh không làm giật giao diện.
  @override
  Future<String> prepare(Uint8List bytes) => compute(AvatarImage.process, bytes);
}
