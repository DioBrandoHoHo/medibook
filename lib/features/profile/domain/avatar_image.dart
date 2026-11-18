import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Xử lý ảnh đại diện trước khi lưu – hàm thuần Dart (không phụ thuộc Flutter / Firebase).
///
/// Lựa chọn kỹ thuật:
/// - Cắt VUÔNG ở giữa ảnh (ảnh đại diện luôn hiển thị trong khung tròn), xoay đúng chiều theo EXIF.
/// - Thu về [outputSize] x [outputSize] px: đủ nét cho khung lớn nhất trong app (đường kính
///   ~80dp ở màn hình 3x = 240px) mà vẫn nhỏ.
/// - JPEG chất lượng [jpegQuality]: ảnh 256px thường chỉ 15–35 KB, base64 ~20–45 KB – nhỏ hơn
///   nhiều giới hạn 1 MB của một document Firestore và giới hạn [maxEncodedLength] trong Rules.
abstract final class AvatarImage {
  static const outputSize = 256;
  static const jpegQuality = 82;

  /// Ảnh gốc lớn hơn mức này bị từ chối ngay (tránh giải mã ảnh khổng lồ gây treo / hết bộ nhớ).
  static const maxInputBytes = 20 * 1024 * 1024;

  /// Phải khớp `UserModel.maxAvatarLength` và Security Rules.
  static const maxEncodedLength = 200000;

  /// Ảnh gốc -> chuỗi base64 của JPEG vuông đã nén. Ném [AvatarImageException] nếu ảnh quá lớn
  /// hoặc không đọc được (định dạng không hỗ trợ, file hỏng).
  static String process(Uint8List bytes) {
    if (bytes.isEmpty) throw const AvatarImageException(AvatarImageError.unsupported);
    if (bytes.length > maxInputBytes) {
      throw const AvatarImageException(AvatarImageError.tooLarge);
    }
    img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      decoded = null;
    }
    if (decoded == null || decoded.width == 0 || decoded.height == 0) {
      throw const AvatarImageException(AvatarImageError.unsupported);
    }
    final oriented = img.bakeOrientation(decoded);
    final side = oriented.width < oriented.height ? oriented.width : oriented.height;
    final square = img.copyCrop(
      oriented,
      x: (oriented.width - side) ~/ 2,
      y: (oriented.height - side) ~/ 2,
      width: side,
      height: side,
    );
    final resized = side > outputSize
        ? img.copyResize(
            square,
            width: outputSize,
            height: outputSize,
            interpolation: img.Interpolation.average,
          )
        : square;
    final encoded = base64Encode(img.encodeJpg(resized, quality: jpegQuality));
    if (encoded.length > maxEncodedLength) {
      throw const AvatarImageException(AvatarImageError.tooLarge);
    }
    return encoded;
  }

  /// Giải mã chuỗi đã lưu để hiển thị. Chuỗi hỏng -> `null` (giao diện quay về chữ cái đầu).
  static Uint8List? decode(String avatar) {
    if (avatar.isEmpty) return null;
    try {
      return base64Decode(avatar);
    } catch (_) {
      return null;
    }
  }
}

enum AvatarImageError { tooLarge, unsupported }

class AvatarImageException implements Exception {
  const AvatarImageException(this.error);

  final AvatarImageError error;
}
