import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Xử lý ảnh đại diện trước khi lưu.
abstract final class AvatarImage {
  static const outputSize = 256;
  static const jpegQuality = 82;

  /// Kích thước tối đa của ảnh gốc.
  static const maxInputBytes = 20 * 1024 * 1024;

  /// Độ dài tối đa của chuỗi ảnh.
  static const maxEncodedLength = 200000;

  /// Ảnh gốc -> chuỗi base64 của JPEG vuông đã nén.
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

  /// Giải mã chuỗi đã lưu để hiển thị.
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
