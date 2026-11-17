import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/app/router/app_routes.dart';
import 'package:medibook/app/router/route_guard.dart';
import 'package:medibook/features/auth/domain/entities/app_user.dart';
import 'package:medibook/features/auth/domain/entities/user_role.dart';

AppUser _user(UserRole role, {bool completed = false}) => AppUser(
      id: '1',
      fullName: 'A',
      phone: '0912345678',
      role: role,
      profileCompleted: completed,
    );

void main() {
  group('RouteGuard.redirect', () {
    test('chưa đăng nhập vào trang cần đăng nhập -> /auth', () {
      for (final r in [AppRoutes.customerShell, AppRoutes.staffShell, AppRoutes.profilePrompt]) {
        expect(RouteGuard.redirect(r, null), AppRoutes.auth, reason: r);
      }
    });

    test('Welcome và Auth luôn vào được', () {
      expect(RouteGuard.redirect(AppRoutes.welcome, null), isNull);
      expect(RouteGuard.redirect(AppRoutes.auth, null), isNull);
    });

    test('Customer không vào được khu vực Staff và ngược lại', () {
      expect(RouteGuard.redirect(AppRoutes.staffShell, _user(UserRole.customer)),
          AppRoutes.customerShell);
      expect(RouteGuard.redirect(AppRoutes.customerShell, _user(UserRole.staff)),
          AppRoutes.staffShell);
      expect(RouteGuard.redirect(AppRoutes.staffShell, _user(UserRole.staff)), isNull);
    });
  });

  group('RouteGuard.afterAuth', () {
    test('hồ sơ chưa hoàn thiện -> hỏi cập nhật hồ sơ', () {
      expect(RouteGuard.afterAuth(_user(UserRole.customer)), AppRoutes.profilePrompt);
      expect(RouteGuard.afterAuth(_user(UserRole.staff)), AppRoutes.profilePrompt);
    });

    test('hồ sơ đã hoàn thiện -> vào thẳng trang chính theo vai trò', () {
      expect(RouteGuard.afterAuth(_user(UserRole.customer, completed: true)),
          AppRoutes.customerShell);
      expect(RouteGuard.afterAuth(_user(UserRole.staff, completed: true)), AppRoutes.staffShell);
    });
  });
}
