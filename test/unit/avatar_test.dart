import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:medibook/core/errors/app_failure.dart';
import 'package:medibook/features/auth/data/models/user_model.dart';
import 'package:medibook/features/auth/domain/entities/user_role.dart';
import 'package:medibook/features/auth/presentation/controllers/auth_controller.dart';
import 'package:medibook/features/profile/domain/avatar_image.dart';
import 'package:medibook/features/profile/presentation/controllers/profile_controller.dart';

import '../mocks/fake_repositories.dart';

/// Ảnh PNG [w]x[h]: nửa trái đỏ, nửa phải xanh (để kiểm tra cắt ở GIỮA).
Uint8List pngImage(int w, int h) {
  final image = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      image.setPixelRgb(x, y, x < w ~/ 2 ? 255 : 0, 0, x < w ~/ 2 ? 0 : 255);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

img.Image decodeResult(String encoded) => img.decodeJpg(base64Decode(encoded))!;

void main() {
  group('AvatarImage.process', () {
    test('ảnh ngang lớn -> JPEG vuông 256x256, cắt ở giữa, dung lượng nhỏ', () {
      final out = AvatarImage.process(pngImage(1200, 600));
      final image = decodeResult(out);
      expect(image.width, AvatarImage.outputSize);
      expect(image.height, AvatarImage.outputSize);
      // Cắt vuông ở giữa ảnh 1200x600 -> lấy x 300..900: nửa trái đỏ, nửa phải xanh.
      expect(image.getPixel(20, 128).r, greaterThan(200));
      expect(image.getPixel(236, 128).b, greaterThan(200));
      expect(out.length, lessThan(AvatarImage.maxEncodedLength));
      expect(base64Decode(out).length, lessThan(40 * 1024));
    });

    test('ảnh dọc cũng thành vuông', () {
      final image = decodeResult(AvatarImage.process(pngImage(300, 900)));
      expect((image.width, image.height), (256, 256));
    });

    test('ảnh nhỏ hơn 256px: chỉ cắt vuông, không phóng to', () {
      final image = decodeResult(AvatarImage.process(pngImage(120, 80)));
      expect((image.width, image.height), (80, 80));
    });

    test('dữ liệu không phải ảnh / rỗng -> unsupported', () {
      for (final bytes in [Uint8List(0), Uint8List.fromList(utf8.encode('không phải ảnh'))]) {
        expect(
          () => AvatarImage.process(bytes),
          throwsA(isA<AvatarImageException>()
              .having((e) => e.error, 'error', AvatarImageError.unsupported)),
        );
      }
    });

    test('file gốc quá 20 MB -> tooLarge (từ chối trước khi giải mã)', () {
      expect(
        () => AvatarImage.process(Uint8List(AvatarImage.maxInputBytes + 1)),
        throwsA(isA<AvatarImageException>()
            .having((e) => e.error, 'error', AvatarImageError.tooLarge)),
      );
    });

    test('decode: chuỗi hỏng / rỗng -> null; chuỗi đúng -> bytes', () {
      expect(AvatarImage.decode(''), isNull);
      expect(AvatarImage.decode('%%% không phải base64'), isNull);
      expect(AvatarImage.decode(AvatarImage.process(pngImage(50, 50))), isNotNull);
    });
  });

  group('UserModel – trường avatar', () {
    Map<String, dynamic> doc(Object? avatar) => {
          'fullName': 'A',
          'phone': '0900000001',
          'role': 'staff',
          'avatar': avatar,
        };

    test('đọc đúng chuỗi ảnh; thiếu / sai kiểu / quá dài -> chưa có ảnh', () {
      expect(UserModel.fromMap('u', doc('abc')).avatar, 'abc');
      expect(UserModel.fromMap('u', doc(null)).hasAvatar, isFalse);
      expect(UserModel.fromMap('u', doc(123)).avatar, '');
      expect(UserModel.fromMap('u', doc('x' * (UserModel.maxAvatarLength + 1))).avatar, '');
      expect(UserModel.fromMap('u', {'fullName': 'A', 'phone': '1', 'role': 'customer'}).avatar,
          '');
    });

    test('maxAvatarLength khớp giới hạn của bước xử lý ảnh', () {
      expect(UserModel.maxAvatarLength, AvatarImage.maxEncodedLength);
    });
  });

  group('ProfileController.saveAvatar', () {
    late FakeAuthRepository authRepo;
    late FakeProfileRepository profileRepo;
    late AuthController auth;
    late ProfileController profile;

    setUp(() async {
      authRepo = FakeAuthRepository()
        ..seed(
          phone: '0900000001',
          password: 'Staff@123',
          fullName: 'Trần Thu Trang',
          role: UserRole.staff,
          signedIn: true,
        );
      profileRepo = FakeProfileRepository(authRepo);
      auth = AuthController(authRepo);
      await auth.restoreSession();
      profile = ProfileController(profileRepo, auth);
    });

    test('lưu thành công -> currentUser có ảnh, dữ liệu gốc cũng có (đăng nhập lại vẫn còn)',
        () async {
      final encoded = AvatarImage.process(pngImage(400, 400));
      expect(await profile.saveAvatar(encoded), isTrue);
      expect(auth.currentUser!.avatar, encoded);
      expect(profileRepo.savedAvatars, [encoded]);
      // Mở lại app: đọc lại từ "Firestore" giả.
      final reopened = AuthController(authRepo);
      await reopened.restoreSession();
      expect(reopened.currentUser!.avatar, encoded);
      // Các trường khác không bị đụng tới.
      expect(auth.currentUser!.fullName, 'Trần Thu Trang');
      expect(auth.currentUser!.role, UserRole.staff);
    });

    test('lưu thất bại -> giữ ảnh cũ, báo lỗi', () async {
      profileRepo.nextAvatarError = const NetworkFailure();
      expect(await profile.saveAvatar('abc'), isFalse);
      expect(auth.currentUser!.hasAvatar, isFalse);
      expect(profile.error, const NetworkFailure().message);
      expect(profile.isSaving, isFalse);
    });

    test('xoá ảnh = lưu chuỗi rỗng', () async {
      await profile.saveAvatar('abc');
      expect(await profile.saveAvatar(''), isTrue);
      expect(auth.currentUser!.hasAvatar, isFalse);
    });

    test('lưu hồ sơ (họ tên...) không làm mất ảnh đã có', () async {
      await profile.saveAvatar('abc');
      await profile.save(fullName: 'Tên mới');
      expect(auth.currentUser!.avatar, 'abc');
      expect(auth.currentUser!.fullName, 'Tên mới');
    });
  });
}
