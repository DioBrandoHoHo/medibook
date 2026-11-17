import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/constants/app_strings.dart';
import 'package:medibook/core/errors/app_failure.dart';
import 'package:medibook/core/utils/app_date_utils.dart';
import 'package:medibook/core/utils/validators.dart';
import 'package:medibook/features/auth/data/models/user_model.dart';
import 'package:medibook/features/auth/domain/entities/user_gender.dart';
import 'package:medibook/features/auth/domain/entities/user_role.dart';
import 'package:medibook/features/auth/presentation/controllers/auth_controller.dart';
import 'package:medibook/features/profile/presentation/controllers/profile_controller.dart';

import '../mocks/fake_repositories.dart';

final _now = DateTime(2026, 11, 15, 10);

void main() {
  group('Email liên hệ (không bắt buộc)', () {
    test('để trống hoặc chỉ có khoảng trắng -> hợp lệ', () {
      expect(Validators.optionalEmail(null), isNull);
      expect(Validators.optionalEmail(''), isNull);
      expect(Validators.optionalEmail('   '), isNull);
    });

    test('đúng định dạng -> hợp lệ', () {
      expect(Validators.optionalEmail('trang.tt@medibook.vn'), isNull);
      expect(Validators.optionalEmail('  a@b.co  '), isNull);
    });

    test('sai định dạng hoặc quá 100 ký tự -> báo lỗi', () {
      for (final bad in ['abc', 'a@b', '@b.com', 'a b@c.com', 'a@@b.com', 'a@b.c']) {
        expect(Validators.optionalEmail(bad), AppStrings.errEmailInvalid, reason: bad);
      }
      expect(Validators.optionalEmail('${'a' * 95}@b.com'), AppStrings.errEmailInvalid);
    });
  });

  group('Ngày sinh (không bắt buộc)', () {
    test('để trống -> hợp lệ', () {
      expect(Validators.optionalBirthDate('', _now), isNull);
      expect(Validators.optionalBirthDate(null, _now), isNull);
    });

    test('ngày có thật trong quá khứ -> hợp lệ, kể cả hôm nay và 29/02 năm nhuận', () {
      expect(Validators.optionalBirthDate('15/08/1995', _now), isNull);
      expect(Validators.optionalBirthDate('1/2/2000', _now), isNull);
      expect(Validators.optionalBirthDate('29/02/2024', _now), isNull);
      expect(Validators.optionalBirthDate('15/11/2026', _now), isNull);
    });

    test('ngày không tồn tại, ở tương lai, quá 120 năm, sai dạng -> báo lỗi', () {
      for (final bad in [
        '31/02/2000',
        '29/02/2023',
        '00/01/2000',
        '15/13/2000',
        '16/11/2026', // ngày mai
        '01/01/1900', // quá 120 năm
        '1995-08-15',
        '15/08/95',
        'abc',
      ]) {
        expect(Validators.optionalBirthDate(bad, _now), AppStrings.errBirthDateInvalid, reason: bad);
      }
    });

    test('đổi qua lại giữa dạng hiển thị và dạng lưu trữ không lệch ngày', () {
      final date = AppDateUtils.parseDisplayDate('05/03/1990')!;
      expect(AppDateUtils.isoDate(date), '1990-03-05');
      expect(AppDateUtils.parseIsoDate('1990-03-05'), date);
      expect(AppDateUtils.date(date), '05/03/1990');
      expect(AppDateUtils.parseIsoDate('1990-02-31'), isNull);
      expect(AppDateUtils.parseIsoDate(19900305), isNull);
      expect(AppDateUtils.parseIsoDate(null), isNull);
    });
  });

  group('Mật khẩu mới ở màn Đổi mật khẩu', () {
    test('phải đủ 4 điều kiện và khác mật khẩu hiện tại', () {
      expect(Validators.changedPassword('', 'Old@1234'), AppStrings.errPasswordRequired);
      expect(Validators.changedPassword('yeu', 'Old@1234'), AppStrings.errPasswordRules);
      expect(Validators.changedPassword('Old@1234', 'Old@1234'), AppStrings.errNewPasswordSame);
      expect(Validators.changedPassword('New@5678', 'Old@1234'), isNull);
    });
  });

  group('UserModel – đọc / ghi document users/{uid}', () {
    test('document chỉ có dữ liệu lúc đăng ký -> các trường mới là "chưa cập nhật"', () {
      final map = UserModel.newCustomerMap(fullName: 'Nguyễn An', phone: '0912345678');
      final user = UserModel.fromMap('u1', map);
      expect(user.fullName, 'Nguyễn An');
      expect(user.phone, '0912345678');
      expect(user.email, isEmpty);
      expect(user.birthDate, isNull);
      expect(user.gender, isNull);
      expect(user.hasMissingInfo, isTrue);
    });

    test('ghi rồi đọc lại hồ sơ đầy đủ -> giữ nguyên giá trị', () {
      final update = UserModel.profileUpdateMap(
        fullName: 'Trần Thu Trang',
        email: 'trang@medibook.vn',
        birthDate: DateTime(1995, 8, 15),
        gender: UserGender.female,
      );
      expect(update['birthDate'], '1995-08-15');
      expect(update['gender'], 'female');
      expect(update.containsKey('phone'), isFalse); // không bao giờ ghi SĐT / vai trò
      expect(update.containsKey('role'), isFalse);

      final user = UserModel.fromMap('u1', {'phone': '0900000001', 'role': 'staff', ...update});
      expect(user.role, UserRole.staff);
      expect(user.email, 'trang@medibook.vn');
      expect(user.birthDate, DateTime(1995, 8, 15));
      expect(user.gender, UserGender.female);
      expect(user.hasMissingInfo, isFalse);
    });

    test('document nhập tay sai kiểu dữ liệu -> không lỗi, coi như chưa cập nhật', () {
      final user = UserModel.fromMap('u1', {
        'fullName': 123,
        'phone': '0900000001',
        'role': 'staff',
        'email': 42,
        'birthDate': '15/08/1995',
        'gender': 'x',
      });
      expect(user.fullName, isEmpty);
      expect(user.email, isEmpty);
      expect(user.birthDate, isNull);
      expect(user.gender, isNull);
    });
  });

  group('Đồng bộ hồ sơ (thong_tin.txt mục 2)', () {
    late FakeAuthRepository repo;
    late FakeProfileRepository profileRepo;
    late AuthController auth;
    late ProfileController profile;

    setUp(() async {
      repo = FakeAuthRepository()
        ..seed(
          phone: '0900000001',
          password: 'Staff@123',
          fullName: 'Trần Thu Trang',
          role: UserRole.staff,
          signedIn: true,
        );
      profileRepo = FakeProfileRepository(repo);
      auth = AuthController(repo);
      await auth.restoreSession();
      profile = ProfileController(profileRepo, auth);
    });

    test('dữ liệu lúc tạo tài khoản có ngay trong hồ sơ đang đăng nhập', () {
      expect(auth.currentUser!.fullName, 'Trần Thu Trang');
      expect(auth.currentUser!.phone, '0900000001');
    });

    test('lưu thành công: nơi lưu trữ và hồ sơ trong app cùng đổi, SĐT / vai trò giữ nguyên', () async {
      final ok = await profile.save(
        fullName: '  Trần Thị Thu Trang ',
        email: ' trang@medibook.vn ',
        birthDate: DateTime(1995, 8, 15),
        gender: UserGender.female,
      );
      expect(ok, isTrue);

      final inApp = auth.currentUser!;
      final stored = repo.storedUser('0900000001')!;
      for (final user in [inApp, stored]) {
        expect(user.fullName, 'Trần Thị Thu Trang');
        expect(user.email, 'trang@medibook.vn');
        expect(user.birthDate, DateTime(1995, 8, 15));
        expect(user.gender, UserGender.female);
        expect(user.phone, '0900000001');
        expect(user.role, UserRole.staff);
        expect(user.profileCompleted, isTrue);
      }
    });

    test('lưu thất bại: hồ sơ trong app và nơi lưu trữ đều giữ nguyên, có thông báo lỗi', () async {
      profileRepo.nextError = const NetworkFailure();
      final ok = await profile.save(fullName: 'Tên Mới', email: 'moi@medibook.vn');
      expect(ok, isFalse);
      expect(profile.error, AppStrings.errNetwork);
      expect(auth.currentUser!.fullName, 'Trần Thu Trang');
      expect(auth.currentUser!.email, isEmpty);
      expect(repo.storedUser('0900000001')!.fullName, 'Trần Thu Trang');
    });

    test('xoá dữ liệu tuỳ chọn đã nhập -> trở về "chưa cập nhật"', () async {
      await profile.save(
        fullName: 'Trần Thu Trang',
        email: 'trang@medibook.vn',
        birthDate: DateTime(1995, 8, 15),
        gender: UserGender.female,
      );
      await profile.save(fullName: 'Trần Thu Trang');
      expect(auth.currentUser!.email, isEmpty);
      expect(auth.currentUser!.birthDate, isNull);
      expect(auth.currentUser!.gender, isNull);
    });

    test('mở lại app -> đọc lại đúng dữ liệu đã lưu', () async {
      await profile.save(fullName: 'Trần Thị Thu Trang', email: 'trang@medibook.vn');
      final reopened = AuthController(repo);
      await reopened.restoreSession();
      expect(reopened.currentUser!.fullName, 'Trần Thị Thu Trang');
      expect(reopened.currentUser!.email, 'trang@medibook.vn');
    });
  });

  group('Đổi mật khẩu', () {
    late FakeAuthRepository repo;
    late AuthController auth;

    setUp(() async {
      repo = FakeAuthRepository()
        ..seed(phone: '0900000001', password: 'Staff@123', role: UserRole.staff, signedIn: true);
      auth = AuthController(repo);
      await auth.restoreSession();
    });

    test('sai mật khẩu hiện tại -> lỗi gắn với ô mật khẩu, mật khẩu không đổi', () async {
      final failure =
          await auth.changePassword(currentPassword: 'Sai@1234', newPassword: 'New@5678');
      expect(failure, isA<AuthFailure>());
      expect((failure! as AuthFailure).field, AuthField.password);
      expect(failure.message, AppStrings.errCurrentPasswordWrong);
      expect(await auth.login(phone: '0900000001', password: 'Staff@123'), isTrue);
    });

    test('thành công -> vẫn đăng nhập; mật khẩu mới dùng được, mật khẩu cũ thì không', () async {
      final failure =
          await auth.changePassword(currentPassword: 'Staff@123', newPassword: 'New@5678');
      expect(failure, isNull);
      expect(auth.currentUser, isNotNull);

      await auth.logout();
      expect(await auth.login(phone: '0900000001', password: 'Staff@123'), isFalse);
      expect(auth.generalError, AppStrings.errWrongCredentials);
      expect(await auth.login(phone: '0900000001', password: 'New@5678'), isTrue);
    });

    test('mất mạng -> trả về lỗi mạng', () async {
      repo.nextError = const NetworkFailure();
      final failure =
          await auth.changePassword(currentPassword: 'Staff@123', newPassword: 'New@5678');
      expect(failure, isA<NetworkFailure>());
    });
  });
}
