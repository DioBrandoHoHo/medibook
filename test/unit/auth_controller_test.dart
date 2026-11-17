import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/constants/app_strings.dart';
import 'package:medibook/core/errors/app_failure.dart';
import 'package:medibook/features/auth/domain/entities/user_role.dart';
import 'package:medibook/features/auth/presentation/controllers/auth_controller.dart';
import 'package:medibook/features/profile/presentation/controllers/profile_controller.dart';

import '../mocks/fake_repositories.dart';

void main() {
  late FakeAuthRepository repo;
  late AuthController auth;

  setUp(() {
    repo = FakeAuthRepository();
    auth = AuthController(repo);
  });

  test('đăng ký thành công tạo tài khoản Customer, lưu họ tên + SĐT đã chuẩn hoá', () async {
    final ok = await auth.register(fullName: ' Nguyễn An ', phone: '+84 912 345 678', password: 'Abc@1234');
    expect(ok, isTrue);
    expect(auth.currentUser!.role, UserRole.customer);
    expect(auth.currentUser!.fullName, 'Nguyễn An');
    expect(auth.currentUser!.phone, '0912345678');
    expect(auth.currentUser!.profileCompleted, isFalse);
  });

  test('đăng ký trùng SĐT (khác cách viết) -> lỗi gắn vào ô SĐT', () async {
    repo.seed(phone: '0912345678', password: 'Abc@1234');
    final ok = await auth.register(fullName: 'B', phone: '84912345678', password: 'Abc@1234');
    expect(ok, isFalse);
    expect(auth.phoneError, AppStrings.errPhoneExists);
    expect(auth.currentUser, isNull);
  });

  test('đăng nhập SĐT chưa đăng ký -> "Số điện thoại chưa được đăng ký"', () async {
    final ok = await auth.login(phone: '0912345678', password: 'x');
    expect(ok, isFalse);
    expect(auth.phoneError, AppStrings.errPhoneNotRegistered);
  });

  test('đăng nhập sai mật khẩu -> thông báo chung theo đặc tả', () async {
    repo.seed(phone: '0912345678', password: 'Abc@1234');
    final ok = await auth.login(phone: '0912345678', password: 'Sai@1234');
    expect(ok, isFalse);
    expect(auth.generalError, AppStrings.errWrongCredentials);
    expect(auth.phoneError, isNull);
  });

  test('đăng nhập tài khoản Staff trả về đúng vai trò', () async {
    repo.seed(phone: '0987654321', password: 'Staff@123', role: UserRole.staff);
    expect(await auth.login(phone: '0987654321', password: 'Staff@123'), isTrue);
    expect(auth.currentUser!.role, UserRole.staff);
  });

  test('mất mạng -> thông báo dễ hiểu, không crash, isLoading trở về false', () async {
    repo.nextError = const NetworkFailure();
    final ok = await auth.login(phone: '0912345678', password: 'x');
    expect(ok, isFalse);
    expect(auth.generalError, AppStrings.errNetwork);
    expect(auth.isLoading, isFalse);
  });

  test('clearErrors xoá lỗi hệ thống khi người dùng sửa dữ liệu', () async {
    await auth.login(phone: '0912345678', password: 'x');
    auth.clearErrors();
    expect(auth.phoneError, isNull);
    expect(auth.generalError, isNull);
  });

  test('lưu hồ sơ cập nhật họ tên và đặt profileCompleted = true', () async {
    await auth.register(fullName: 'A', phone: '0912345678', password: 'Abc@1234');
    final profileRepo = FakeProfileRepository();
    final profile = ProfileController(profileRepo, auth);
    expect(await profile.save(fullName: 'Trần Bình'), isTrue);
    expect(auth.currentUser!.fullName, 'Trần Bình');
    expect(auth.currentUser!.profileCompleted, isTrue);
    expect(profileRepo.savedNames, ['Trần Bình']);
  });
}
