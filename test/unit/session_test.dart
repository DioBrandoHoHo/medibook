import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/app/router/app_routes.dart';
import 'package:medibook/app/router/route_guard.dart';
import 'package:medibook/core/errors/app_failure.dart';
import 'package:medibook/features/auth/data/models/user_model.dart';
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

  group('Tự đăng nhập lại', () {
    test('còn phiên -> khôi phục đúng người dùng & vai trò, đích là trang chính', () async {
      repo.seed(phone: '0987654321', password: 'Staff@123', role: UserRole.staff, signedIn: true);
      final user = await auth.restoreSession();
      expect(user!.role, UserRole.staff);
      expect(RouteGuard.afterRestore(user), AppRoutes.staffShell);
    });

    test('không có phiên -> null, đích là Welcome', () async {
      expect(await auth.restoreSession(), isNull);
      expect(RouteGuard.afterRestore(null), AppRoutes.welcome);
    });

    test('lỗi khi khôi phục -> coi như chưa đăng nhập, không ném lỗi', () async {
      repo.seed(phone: '0912345678', password: 'Abc@1234', signedIn: true);
      repo.nextError = const NetworkFailure();
      expect(await auth.restoreSession(), isNull);
      expect(auth.currentUser, isNull);
    });

    test('quá thời gian chờ -> coi như chưa đăng nhập', () async {
      final slow = AuthController(_NeverRestoreRepository(), restoreTimeout: Duration.zero);
      expect(await slow.restoreSession(), isNull);
    });
  });

  group('Đăng xuất', () {
    test('xoá phiên trên máy và người dùng hiện tại', () async {
      repo.seed(phone: '0912345678', password: 'Abc@1234');
      await auth.login(phone: '0912345678', password: 'Abc@1234');
      await auth.logout();
      expect(auth.currentUser, isNull);
      expect(await repo.restoreSession(), isNull, reason: 'mở lại app không tự vào nữa');
    });

    test('Firebase báo lỗi khi đăng xuất -> vẫn xoá phiên cục bộ', () async {
      repo.seed(phone: '0912345678', password: 'Abc@1234');
      await auth.login(phone: '0912345678', password: 'Abc@1234');
      repo.nextError = const NetworkFailure();
      await auth.logout();
      expect(auth.currentUser, isNull);
      expect(repo.logoutCalls, 1);
    });
  });

  group('"Để sau" (profilePromptDismissed)', () {
    test('bấm Để sau -> lưu cờ và không hỏi lại ở lần đăng nhập sau', () async {
      repo.seed(phone: '0912345678', password: 'Abc@1234');
      await auth.login(phone: '0912345678', password: 'Abc@1234');
      expect(RouteGuard.afterAuth(auth.currentUser!), AppRoutes.profilePrompt);

      ProfileController(FakeProfileRepository(repo), auth).dismissPrompt();
      await Future<void>.delayed(Duration.zero);

      final again = AuthController(repo);
      await again.login(phone: '0912345678', password: 'Abc@1234');
      expect(again.currentUser!.profilePromptDismissed, isTrue);
      expect(RouteGuard.afterAuth(again.currentUser!), AppRoutes.customerShell);
    });

    test('document cũ thiếu trường profilePromptDismissed được hiểu là false', () {
      final user = UserModel.fromMap('id', {'fullName': 'A', 'phone': '0912345678'});
      expect(user.profilePromptDismissed, isFalse);
      expect(user.shouldAskProfileUpdate, isTrue);
    });

    test('tài khoản mới tạo luôn có profilePromptDismissed = false', () {
      final map = UserModel.newCustomerMap(fullName: 'A', phone: '0912345678');
      expect(map['profilePromptDismissed'], isFalse);
      expect(map['role'], 'customer');
    });
  });
}

/// Repository mà restoreSession không bao giờ trả về (mô phỏng mạng treo).
class _NeverRestoreRepository extends FakeAuthRepository {
  @override
  Future<Never> restoreSession() => Future<Never>.delayed(const Duration(days: 1));
}
