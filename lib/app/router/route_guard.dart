import '../../features/auth/domain/entities/app_user.dart';
import '../../features/auth/domain/entities/user_role.dart';
import 'app_routes.dart';

/// Logic điều hướng theo phiên & vai trò.
abstract final class RouteGuard {
  static const _protected = {
    AppRoutes.profilePrompt,
    AppRoutes.profileEdit,
    AppRoutes.customerShell,
    AppRoutes.staffShell,
  };

  /// Trang chính theo vai trò.
  static String homeFor(UserRole role) =>
      role == UserRole.staff ? AppRoutes.staffShell : AppRoutes.customerShell;

  /// Đích đến ngay sau khi đăng nhập/đăng ký thành công.
  static String afterAuth(AppUser user) =>
      user.shouldAskProfileUpdate ? AppRoutes.profilePrompt : homeFor(user.role);

  /// Đích đến khi mở app.
  static String afterRestore(AppUser? user) =>
      user == null ? AppRoutes.welcome : homeFor(user.role);

  /// Trả về route cần chuyển hướng, hoặc `null` nếu được phép vào [location].
  static String? redirect(String location, AppUser? user) {
    if (_protected.contains(location) && user == null) return AppRoutes.auth;
    if (user == null) return null;
    final home = homeFor(user.role);
    final isShell = location == AppRoutes.customerShell || location == AppRoutes.staffShell;
    if (isShell && location != home) return home;
    return null;
  }
}
