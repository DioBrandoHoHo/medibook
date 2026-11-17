import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/constants/app_strings.dart';
import 'package:medibook/core/errors/app_failure.dart';
import 'package:medibook/core/utils/validators.dart';
import 'package:medibook/features/auth/domain/entities/recovery_email.dart';
import 'package:medibook/features/auth/domain/entities/user_role.dart';
import 'package:medibook/features/auth/presentation/controllers/auth_controller.dart';

import '../mocks/fake_repositories.dart';
import 'test_helpers.dart';

// Kiểm thử Quên mật khẩu + Email khôi phục (dang_ky_dang_nhap.txt – phần bổ sung).

const _phone = '0912345678';
const _password = 'Khach@123';
const _email = 'nguyenbinh@gmail.com';

FakeAuthRepository _auth({bool signedIn = false}) => FakeAuthRepository()
  ..seed(
    phone: _phone,
    password: _password,
    fullName: 'Nguyễn Văn Bình',
    profilePromptDismissed: true,
    signedIn: signedIn,
  )
  ..seed(
    phone: '0900000001',
    password: 'Staff@123',
    fullName: 'Trần Thu Trang',
    role: UserRole.staff,
    profilePromptDismissed: true,
  );

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
  await tester.pumpAndSettle();
}

String _textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key), skipOffstage: false).first).data!;

Future<void> _tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key), skipOffstage: false).first);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey(key)).first);
  await tester.pumpAndSettle();
}

Finder _input(String key) =>
    find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(TextField));

/// Khách đã đăng nhập mở màn Email khôi phục từ tab Cá nhân.
Future<void> _openRecovery(WidgetTester tester) async {
  await _openTab(tester, AppStrings.tabProfile);
  await _tapKey(tester, 'recovery_email');
}

Future<void> _requestRecovery(WidgetTester tester, String email, String password) async {
  await tester.enterText(_input('recovery_email_field'), email);
  await tester.enterText(_input('recovery_password'), password);
  await _tapKey(tester, 'recovery_submit');
}

/// Mở màn Quên mật khẩu từ màn Đăng nhập rồi gửi yêu cầu với [phone].
Future<void> _forgot(WidgetTester tester, String phone) async {
  await _tapKey(tester, 'forgot_password');
  await tester.enterText(_input('forgot_phone'), phone);
  await _tapKey(tester, 'forgot_submit');
}

void main() {
  group('Hàm thuần Dart', () {
    test('che bớt email khi hiển thị', () {
      expect(RecoveryEmail.mask('nguyenbinh@gmail.com'), 'ng••••••••@gmail.com');
      expect(RecoveryEmail.mask('ab@x.vn'), 'a•@x.vn');
      expect(RecoveryEmail.mask('a@x.vn'), 'a•@x.vn');
      expect(RecoveryEmail.mask('khong-phai-email'), 'khong-phai-email');
    });

    test('email khôi phục bắt buộc và phải đúng định dạng', () {
      expect(Validators.requiredEmail(''), AppStrings.errEmailRequired);
      expect(Validators.requiredEmail('abc'), AppStrings.errEmailInvalid);
      expect(Validators.requiredEmail('a@b.vn'), isNull);
    });
  });

  group('AuthController', () {
    test('quên mật khẩu: chưa có email khôi phục / chưa xác minh / đã xác minh', () async {
      final repo = _auth();
      final auth = AuthController(repo);

      var (sent, failure) = await auth.sendPasswordReset(_phone);
      expect(sent, isNull);
      expect(failure, AuthFailure.noRecoveryEmail);

      await auth.login(phone: _phone, password: _password);
      expect(await auth.requestRecoveryEmail(email: _email, currentPassword: _password), isNull);
      (sent, failure) = await auth.sendPasswordReset(_phone);
      expect(failure, AuthFailure.recoveryNotVerified);
      expect(repo.resetEmailsSent, isEmpty);

      repo.clickVerifyLink(_phone);
      (sent, failure) = await auth.sendPasswordReset(_phone);
      expect(failure, isNull);
      expect(sent, RecoveryEmail.mask(_email));
      expect(repo.resetEmailsSent, [_email]);
      auth.dispose();
    });

    test('đặt email khôi phục: sai mật khẩu hiện tại, email đã có người dùng, mất mạng', () async {
      final repo = _auth();
      final auth = AuthController(repo);
      await auth.login(phone: '0900000001', password: 'Staff@123');
      await auth.requestRecoveryEmail(email: _email, currentPassword: 'Staff@123');
      repo.clickVerifyLink('0900000001', expireSession: false);
      await auth.logout();

      await auth.login(phone: _phone, password: _password);
      expect(
        await auth.requestRecoveryEmail(email: 'x@y.vn', currentPassword: 'sai'),
        AuthFailure.currentPasswordWrong,
      );
      expect(
        await auth.requestRecoveryEmail(email: _email, currentPassword: _password),
        AuthFailure.emailInUse,
      );
      repo.nextError = const NetworkFailure();
      expect(
        await auth.requestRecoveryEmail(email: 'x@y.vn', currentPassword: _password),
        isA<NetworkFailure>(),
      );
      final (status, _) = await auth.recoveryEmailStatus();
      expect(status!.verified, isNull);
      expect(status.pending, isNull);
      auth.dispose();
    });
  });

  group('Màn Quên mật khẩu', () {
    testWidgets('mở từ màn Đăng nhập, điền sẵn SĐT đang gõ; SĐT sai định dạng bị chặn',
        (tester) async {
      final repo = _auth();
      await pumpApp(tester, repo);
      await openAuth(tester);
      await tester.enterText(fieldByLabel(AppStrings.phone), _phone);
      await _tapKey(tester, 'forgot_password');

      expect(find.text(AppStrings.forgotTitle), findsOneWidget);
      expect(tester.widget<TextField>(_input('forgot_phone')).controller!.text, _phone);

      await tester.enterText(_input('forgot_phone'), '123');
      await _tapKey(tester, 'forgot_submit');
      expect(find.text(AppStrings.errPhoneInvalid), findsOneWidget);
      expect(repo.resetEmailsSent, isEmpty);
    });

    testWidgets('tài khoản chưa thiết lập email khôi phục -> báo rõ, không gửi gì', (tester) async {
      final repo = _auth();
      await pumpApp(tester, repo);
      await openAuth(tester);
      await _forgot(tester, _phone);

      expect(find.text(AppStrings.errNoRecoveryEmail), findsOneWidget);
      expect(repo.resetEmailsSent, isEmpty);
    });

    testWidgets('mất mạng -> báo lỗi dễ hiểu, vẫn ở màn Quên mật khẩu', (tester) async {
      final repo = _auth();
      await pumpApp(tester, repo);
      await openAuth(tester);
      await _tapKey(tester, 'forgot_password');
      await tester.enterText(_input('forgot_phone'), _phone);
      repo.nextError = const NetworkFailure();
      await _tapKey(tester, 'forgot_submit');

      expect(_textOf(tester, 'forgot_error'), AppStrings.errNetwork);
      expect(find.byKey(const ValueKey('forgot_submit')), findsOneWidget);
    });
  });

  group('Email khôi phục + luồng đầy đủ', () {
    testWidgets('thẻ Bảo mật có mục Email khôi phục cho cả Khách hàng lẫn Nhân viên', (tester) async {
      await pumpApp(tester, _auth(signedIn: true));
      await _openRecovery(tester);
      expect(_textOf(tester, 'recovery_label_none'), AppStrings.recoveryNone);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _tapKey(tester, 'logout_button');
      await _tapKey(tester, 'logout_agree');

      await tester.enterText(fieldByLabel(AppStrings.phone), '0900000001');
      await tester.enterText(fieldByLabel(AppStrings.password), 'Staff@123');
      await tapButton(tester, AppStrings.login);
      await _openTab(tester, AppStrings.tabAccount);
      await _tapKey(tester, 'recovery_email');
      expect(_textOf(tester, 'recovery_label_none'), AppStrings.recoveryNone);
    });

    testWidgets('nhập thiếu / sai định dạng / sai mật khẩu hiện tại -> báo lỗi, không gửi thư',
        (tester) async {
      final repo = _auth(signedIn: true);
      await pumpApp(tester, repo);
      await _openRecovery(tester);

      await _requestRecovery(tester, '', _password);
      expect(find.text(AppStrings.errEmailRequired), findsOneWidget);
      await _requestRecovery(tester, 'khong-hop-le', _password);
      expect(find.text(AppStrings.errEmailInvalid), findsOneWidget);
      await _requestRecovery(tester, _email, 'Sai@12345');
      expect(find.text(AppStrings.errCurrentPasswordWrong), findsOneWidget);
      expect(repo.verifyEmailsSent, isEmpty);
    });

    testWidgets('đặt email -> chờ xác minh -> bấm liên kết -> KHÔNG bị đăng xuất -> quên mật khẩu -> '
        'đặt mật khẩu mới -> đăng nhập bằng SĐT + mật khẩu mới', (tester) async {
      final repo = _auth(signedIn: true);
      await pumpApp(tester, repo);
      await _openRecovery(tester);

      // 1. Gửi liên kết xác minh.
      await _requestRecovery(tester, _email, _password);
      expect(repo.verifyEmailsSent, [_email]);
      expect(find.text(AppStrings.verifySent), findsOneWidget);
      expect(_textOf(tester, 'recovery_label_pending'), AppStrings.recoveryPending);
      expect(_textOf(tester, 'recovery_value_pending'), _email);
      await tester.pump(const Duration(seconds: 5)); // chờ thông báo tự ẩn (đang che nút bên dưới)
      await tester.pumpAndSettle();

      // 2. Chưa bấm liên kết mà kiểm tra lại -> vẫn chờ.
      await _tapKey(tester, 'recovery_check');
      expect(_textOf(tester, 'recovery_label_pending'), AppStrings.recoveryPending);

      // 3. Bấm liên kết trong thư -> phiên cũ bị thu hồi -> app tự tiếp tục phiên, ở nguyên màn này.
      repo.clickVerifyLink(_phone);
      await _tapKey(tester, 'recovery_check');
      expect(find.text(AppStrings.recoveryVerifiedDone), findsOneWidget);
      expect(find.byKey(const ValueKey('resume_password')), findsNothing); // không phải nhập lại
      expect(_textOf(tester, 'recovery_label_verified'), AppStrings.recoveryVerified);
      expect(_textOf(tester, 'recovery_value_verified'), _email);
      expect(repo.logoutCalls, 0);
      await tester.pump(const Duration(seconds: 5)); // chờ thông báo tự ẩn
      await tester.pumpAndSettle();

      // Tự đăng xuất để thử Quên mật khẩu.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _tapKey(tester, 'logout_button');
      await _tapKey(tester, 'logout_agree');

      // 4. Quên mật khẩu: gửi tới email đã xác minh (hiển thị che bớt).
      await _forgot(tester, _phone);
      expect(repo.resetEmailsSent, [_email]);
      expect(_textOf(tester, 'forgot_sent'), AppStrings.resetSentBody('ng••••••••@gmail.com'));
      expect(find.textContaining(_email), findsNothing);

      // 5. Người dùng đặt mật khẩu mới trên trang của Firebase rồi quay lại đăng nhập.
      repo.resetPasswordFromEmail(_phone, 'Moi@12345');
      await _tapKey(tester, 'forgot_back');
      await tester.enterText(fieldByLabel(AppStrings.phone), _phone);
      await tester.enterText(fieldByLabel(AppStrings.password), _password);
      await tapButton(tester, AppStrings.login);
      expect(find.text(AppStrings.errWrongCredentials), findsOneWidget); // mật khẩu cũ hết dùng

      await tester.enterText(fieldByLabel(AppStrings.password), 'Moi@12345');
      await tapButton(tester, AppStrings.login);
      expect(find.text(AppStrings.tabProfile), findsOneWidget); // vào khu vực Khách hàng

      // 6. Màn Email khôi phục giờ hiện Đã xác minh.
      await _openRecovery(tester);
      expect(_textOf(tester, 'recovery_label_verified'), AppStrings.recoveryVerified);
      expect(_textOf(tester, 'recovery_value_verified'), _email);
    });

    testWidgets('bấm liên kết rồi quay lại app (đang ở tab khác) -> tự tiếp tục phiên ngay khi app mở lại',
        (tester) async {
      final repo = _auth(signedIn: true);
      await pumpApp(tester, repo);
      await _openRecovery(tester);
      await _requestRecovery(tester, _email, _password);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Người dùng chuyển sang ứng dụng email, bấm liên kết, rồi quay lại app.
      repo.clickVerifyLink(_phone);
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();

      // Phiên đã được nối lại: mở màn Email khôi phục thấy Đã xác minh, không hỏi mật khẩu.
      expect(await repo.recoveryEmailStatus(phone: _phone), isA<RecoveryEmail>());
      await _tapKey(tester, 'recovery_email');
      expect(find.byKey(const ValueKey('resume_password')), findsNothing);
      expect(_textOf(tester, 'recovery_label_verified'), AppStrings.recoveryVerified);
      expect(repo.logoutCalls, 0);
    });

    testWidgets('tắt app trước khi bấm liên kết -> mở lại chỉ hỏi mật khẩu tại chỗ; sai báo lỗi, đúng thì tiếp tục',
        (tester) async {
      final repo = _auth(signedIn: true);
      await pumpApp(tester, repo);
      await _openRecovery(tester);
      await _requestRecovery(tester, _email, _password);

      // Mở lại app (mật khẩu tạm trong bộ nhớ đã mất), rồi mới bấm liên kết.
      await pumpApp(tester, repo);
      repo.clickVerifyLink(_phone);
      await _openRecovery(tester);
      expect(find.text(AppStrings.resumeTitle), findsOneWidget);

      await tester.enterText(_input('resume_password'), 'Sai@12345');
      await _tapKey(tester, 'resume_continue');
      expect(find.text(AppStrings.errWrongCredentials), findsOneWidget);

      await tester.enterText(_input('resume_password'), _password);
      await _tapKey(tester, 'resume_continue');
      expect(find.text(AppStrings.resumeTitle), findsNothing);
      expect(_textOf(tester, 'recovery_label_verified'), AppStrings.recoveryVerified);
      expect(repo.logoutCalls, 0);
    });

    testWidgets('hộp nhập mật khẩu: bấm "Để sau" -> về màn Đăng nhập như trước', (tester) async {
      final repo = _auth(signedIn: true);
      await pumpApp(tester, repo);
      await _openRecovery(tester);
      await _requestRecovery(tester, _email, _password);
      await pumpApp(tester, repo);
      repo.clickVerifyLink(_phone);
      await _openRecovery(tester);

      await _tapKey(tester, 'resume_skip');
      expect(find.text(AppStrings.reloginAfterVerify), findsOneWidget);
      expect(find.widgetWithText(FilledButton, AppStrings.login), findsOneWidget);
    });

    testWidgets('email đã gửi nhưng chưa xác minh -> Quên mật khẩu báo chưa xác minh', (tester) async {
      final repo = _auth(signedIn: true);
      await pumpApp(tester, repo);
      await _openRecovery(tester);
      await _requestRecovery(tester, _email, _password);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _tapKey(tester, 'logout_button');
      await _tapKey(tester, 'logout_agree');

      await _forgot(tester, _phone);
      expect(find.text(AppStrings.errRecoveryNotVerified), findsOneWidget);
      expect(repo.resetEmailsSent, isEmpty);
    });
  });
}
