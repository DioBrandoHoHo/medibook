import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/constants/app_strings.dart';
import 'package:medibook/core/errors/app_failure.dart';
import 'package:medibook/features/auth/domain/entities/user_gender.dart';
import 'package:medibook/features/auth/domain/entities/user_role.dart';

import '../mocks/fake_clinic_repositories.dart';
import '../mocks/fake_repositories.dart';
import 'test_helpers.dart';

const _phone = '0900000001';
const _password = 'Staff@123';

FakeAuthRepository _staffRepo({
  String email = '',
  DateTime? birthDate,
  UserGender? gender,
}) =>
    FakeAuthRepository()
      ..seed(
        phone: _phone,
        password: _password,
        fullName: 'Trần Thu Trang',
        role: UserRole.staff,
        signedIn: true,
        email: email,
        birthDate: birthDate,
        gender: gender,
      );

/// Mở app với Staff đã đăng nhập rồi sang tab Tài khoản.
Future<void> _pumpAccount(
  WidgetTester tester,
  FakeAuthRepository auth, {
  FakeProfileRepository? profile,
}) async {
  await pumpApp(
    tester,
    auth,
    profileRepo: profile,
    appointmentRepo: FakeAppointmentRepository(),
    clock: () => DateTime(2026, 11, 15, 10),
  );
  await _openTab(tester, AppStrings.tabAccount);
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
  await tester.pumpAndSettle();
}

String _textOf(WidgetTester tester, String key) =>
    // skipOffstage: false -> đọc được cả dòng đã cuộn khỏi màn hình.
    tester.widget<Text>(find.byKey(ValueKey(key), skipOffstage: false)).data!;

Future<void> _tapKey(WidgetTester tester, String key) async {
  // Phần tử nằm dưới mép màn hình (VD thẻ Bảo mật) đã được dựng nhưng chưa hiện,
  // nên phải tìm cả phần tử ngoài màn hình rồi cuộn tới trước khi bấm.
  await tester.ensureVisible(find.byKey(ValueKey(key), skipOffstage: false));
  await tester.pumpAndSettle();
  final finder = find.byKey(ValueKey(key));
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _saveProfile(WidgetTester tester) async {
  await tapButton(tester, AppStrings.save);
}

Finder _passwordInput(String key) =>
    find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(TextField));

Future<void> _fillPasswords(
  WidgetTester tester, {
  required String current,
  required String next,
  required String confirm,
}) async {
  await tester.enterText(_passwordInput('current_password'), current);
  await tester.enterText(_passwordInput('new_password'), next);
  await tester.enterText(_passwordInput('confirm_new_password'), confirm);
  await tester.pumpAndSettle();
  await _tapKey(tester, 'submit_change_password');
}

void main() {
  testWidgets('thông tin lúc tạo tài khoản hiện đúng; trường chưa có dữ liệu ghi "Chưa cập nhật"',
      (tester) async {
    await _pumpAccount(tester, _staffRepo());

    expect(find.text(AppStrings.accountTitle), findsWidgets);
    expect(_textOf(tester, 'account_name'), 'Trần Thu Trang');
    expect(_textOf(tester, 'account_phone'), _phone);
    expect(find.text(AppStrings.roleStaff), findsOneWidget);
    expect(_textOf(tester, 'info_full_name'), 'Trần Thu Trang');
    expect(_textOf(tester, 'info_phone'), _phone);
    expect(_textOf(tester, 'info_email'), AppStrings.notUpdated);
    expect(_textOf(tester, 'info_birth_date'), AppStrings.notUpdated);
    expect(_textOf(tester, 'info_gender'), AppStrings.notUpdated);
    expect(find.byKey(const ValueKey('incomplete_notice')), findsOneWidget);
    // Địa chỉ email nội bộ dùng để đăng nhập không bao giờ lộ ra.
    expect(find.textContaining('medibook.local'), findsNothing);
  });

  testWidgets('hồ sơ đã đủ -> hiện đủ dữ liệu, không còn dòng nhắc', (tester) async {
    await _pumpAccount(
      tester,
      _staffRepo(
        email: 'trang@medibook.vn',
        birthDate: DateTime(1995, 8, 15),
        gender: UserGender.female,
      ),
    );

    expect(_textOf(tester, 'info_email'), 'trang@medibook.vn');
    expect(_textOf(tester, 'info_birth_date'), '15/08/1995');
    expect(_textOf(tester, 'info_gender'), AppStrings.genderFemale);
    expect(find.byKey(const ValueKey('incomplete_notice')), findsNothing);
  });

  testWidgets('sửa hồ sơ -> tab Tài khoản và lời chào Trang tổng quan cùng đổi; mở lại app vẫn còn',
      (tester) async {
    final auth = _staffRepo();
    await _pumpAccount(tester, auth);

    await _tapKey(tester, 'edit_profile');
    expect(find.text(AppStrings.profileEditTitle), findsOneWidget);
    // Form điền sẵn dữ liệu lúc tạo tài khoản; SĐT bị khoá.
    expect(tester.widget<TextFormField>(fieldByLabel(AppStrings.fullName)).controller!.text,
        'Trần Thu Trang');
    final phoneField = tester.widget<TextFormField>(fieldByLabel(AppStrings.phone));
    expect(phoneField.controller!.text, _phone);
    expect(phoneField.enabled, isFalse);

    await tester.enterText(fieldByLabel(AppStrings.fullName), 'Trần Thị Thu Hà');
    await tester.enterText(find.byKey(const ValueKey('email_field')), 'ha@medibook.vn');
    await tester.enterText(find.byKey(const ValueKey('birth_date_field')), '15081995');
    await tester.pumpAndSettle();
    // Tự chèn dấu "/".
    expect(
      tester.widget<TextFormField>(find.byKey(const ValueKey('birth_date_field'))).controller!.text,
      '15/08/1995',
    );
    await _tapKey(tester, 'gender_female');
    await _saveProfile(tester);

    // Quay lại tab Tài khoản với dữ liệu mới.
    expect(find.text(AppStrings.profileEditTitle), findsNothing);
    expect(_textOf(tester, 'account_name'), 'Trần Thị Thu Hà');
    expect(_textOf(tester, 'info_full_name'), 'Trần Thị Thu Hà');
    expect(_textOf(tester, 'info_email'), 'ha@medibook.vn');
    expect(_textOf(tester, 'info_birth_date'), '15/08/1995');
    expect(_textOf(tester, 'info_gender'), AppStrings.genderFemale);
    expect(find.byKey(const ValueKey('incomplete_notice')), findsNothing);
    // Nơi lưu trữ cũng đã đổi; SĐT giữ nguyên.
    final stored = auth.storedUser(_phone)!;
    expect(stored.fullName, 'Trần Thị Thu Hà');
    expect(stored.email, 'ha@medibook.vn');
    expect(stored.phone, _phone);

    // Trang tổng quan đọc cùng hồ sơ -> lời chào đổi theo, không cần đăng nhập lại.
    await _openTab(tester, AppStrings.tabOverview);
    expect(_textOf(tester, 'greeting_name'), 'Trần Thị Thu Hà');

    // Thoát app rồi mở lại.
    await tester.pump(const Duration(seconds: 5)); // chờ thanh thông báo tự ẩn
    await tester.pumpAndSettle();
    await _pumpAccount(tester, auth);
    expect(_textOf(tester, 'account_name'), 'Trần Thị Thu Hà');
    expect(_textOf(tester, 'info_email'), 'ha@medibook.vn');
    expect(_textOf(tester, 'info_birth_date'), '15/08/1995');
  });

  testWidgets('email / ngày sinh sai -> báo lỗi tại ô nhập, không ghi dữ liệu', (tester) async {
    final auth = _staffRepo();
    final profile = FakeProfileRepository(auth);
    await _pumpAccount(tester, auth, profile: profile);

    await _tapKey(tester, 'incomplete_notice'); // dòng nhắc cũng mở màn chỉnh sửa
    await tester.enterText(find.byKey(const ValueKey('email_field')), 'khong-phai-email');
    await tester.enterText(find.byKey(const ValueKey('birth_date_field')), '31022000');
    await _saveProfile(tester);

    expect(find.text(AppStrings.errEmailInvalid), findsOneWidget);
    expect(find.text(AppStrings.errBirthDateInvalid), findsOneWidget);
    expect(find.text(AppStrings.profileEditTitle), findsOneWidget); // vẫn ở màn chỉnh sửa
    expect(profile.savedNames, isEmpty);
    expect(auth.storedUser(_phone)!.email, isEmpty);
  });

  testWidgets('bỏ trống họ tên -> báo lỗi; lưu thất bại -> giữ dữ liệu cũ và báo lỗi', (tester) async {
    final auth = _staffRepo();
    final profile = FakeProfileRepository(auth);
    await _pumpAccount(tester, auth, profile: profile);
    await _tapKey(tester, 'edit_profile');

    await tester.enterText(fieldByLabel(AppStrings.fullName), '   ');
    await _saveProfile(tester);
    expect(find.text(AppStrings.errFullNameRequired), findsOneWidget);

    profile.nextError = const NetworkFailure();
    await tester.enterText(fieldByLabel(AppStrings.fullName), 'Tên Mới');
    await _saveProfile(tester);
    expect(_textOf(tester, 'profile_error'), AppStrings.errNetwork);
    expect(find.text(AppStrings.profileEditTitle), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(_textOf(tester, 'account_name'), 'Trần Thu Trang'); // không đổi
  });

  testWidgets('bấm lại giới tính đang chọn để bỏ chọn', (tester) async {
    final auth = _staffRepo(gender: UserGender.male);
    await _pumpAccount(tester, auth);
    await _tapKey(tester, 'edit_profile');

    expect(tester.widget<ChoiceChip>(find.byKey(const ValueKey('gender_male'))).selected, isTrue);
    await _tapKey(tester, 'gender_male');
    expect(tester.widget<ChoiceChip>(find.byKey(const ValueKey('gender_male'))).selected, isFalse);
    await _saveProfile(tester);

    expect(_textOf(tester, 'info_gender'), AppStrings.notUpdated);
    expect(auth.storedUser(_phone)!.gender, isNull);
  });

  testWidgets('đổi mật khẩu: báo đúng từng lỗi nhập liệu', (tester) async {
    await _pumpAccount(tester, _staffRepo());
    await _tapKey(tester, 'change_password');
    expect(find.text(AppStrings.currentPassword), findsOneWidget);

    // Bỏ trống tất cả.
    await _tapKey(tester, 'submit_change_password');
    expect(find.text(AppStrings.errPasswordRequired), findsNWidgets(2));
    expect(find.text(AppStrings.errConfirmRequired), findsOneWidget);

    // Mật khẩu mới không đạt điều kiện + xác nhận không khớp.
    await _fillPasswords(tester, current: _password, next: 'yeu', confirm: 'khac');
    expect(find.text(AppStrings.errPasswordRules), findsOneWidget);
    expect(find.text(AppStrings.errPasswordMismatch), findsOneWidget);

    // Trùng mật khẩu hiện tại.
    await _fillPasswords(tester, current: _password, next: _password, confirm: _password);
    expect(find.text(AppStrings.errNewPasswordSame), findsOneWidget);
  });

  testWidgets('đổi mật khẩu: sai mật khẩu hiện tại -> báo dưới ô đó, ở lại màn hình', (tester) async {
    final auth = _staffRepo();
    await _pumpAccount(tester, auth);
    await _tapKey(tester, 'change_password');

    await _fillPasswords(tester, current: 'Sai@1234', next: 'New@5678', confirm: 'New@5678');
    expect(find.text(AppStrings.errCurrentPasswordWrong), findsOneWidget);
    expect(find.text(AppStrings.currentPassword), findsOneWidget);

    // Sửa lại ô mật khẩu hiện tại thì lỗi cũ biến mất.
    await tester.enterText(_passwordInput('current_password'), _password);
    await tester.pumpAndSettle();
    await _tapKey(tester, 'submit_change_password');
    expect(find.text(AppStrings.errCurrentPasswordWrong), findsNothing);
    expect(find.text(AppStrings.passwordChanged), findsOneWidget);
  });

  testWidgets('đổi mật khẩu thành công -> về tab Tài khoản, vẫn đăng nhập; đăng nhập lại bằng mật khẩu mới',
      (tester) async {
    final auth = _staffRepo();
    await _pumpAccount(tester, auth);
    await _tapKey(tester, 'change_password');
    await _fillPasswords(tester, current: _password, next: 'New@5678', confirm: 'New@5678');

    expect(find.text(AppStrings.passwordChanged), findsOneWidget);
    expect(find.byKey(const ValueKey('account_name'), skipOffstage: false), findsOneWidget); // vẫn trong khu vực Staff

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'logout_button');
    await _tapKey(tester, 'logout_agree');

    // Mật khẩu cũ không còn dùng được, mật khẩu mới thì được.
    await tester.enterText(fieldByLabel(AppStrings.phone), _phone);
    await tester.enterText(fieldByLabel(AppStrings.password), _password);
    await tapButton(tester, AppStrings.login);
    expect(find.text(AppStrings.errWrongCredentials), findsOneWidget);

    await tester.enterText(fieldByLabel(AppStrings.password), 'New@5678');
    await tapButton(tester, AppStrings.login);
    // Đăng nhập được (hồ sơ chưa hoàn thiện nên app hỏi cập nhật thông tin trước, đúng luồng cũ).
    expect(find.text(AppStrings.errWrongCredentials), findsNothing);
    expect(find.text(AppStrings.profilePromptQuestion), findsOneWidget);
  });

  testWidgets('đổi mật khẩu khi mất mạng -> báo lỗi chung, không thoát màn hình', (tester) async {
    final auth = _staffRepo();
    await _pumpAccount(tester, auth);
    await _tapKey(tester, 'change_password');

    auth.nextError = const NetworkFailure();
    await _fillPasswords(tester, current: _password, next: 'New@5678', confirm: 'New@5678');
    expect(_textOf(tester, 'change_password_error'), AppStrings.errNetwork);
    expect(find.text(AppStrings.currentPassword), findsOneWidget);
  });

  testWidgets('đăng xuất: có hỏi lại; Hủy thì ở lại; Đồng ý thì về Đăng nhập và mở lại app không tự vào',
      (tester) async {
    final auth = _staffRepo();
    await _pumpAccount(tester, auth);

    await _tapKey(tester, 'logout_button');
    expect(find.text(AppStrings.logoutConfirm), findsOneWidget);
    await _tapKey(tester, 'logout_cancel');
    expect(find.byKey(const ValueKey('account_name'), skipOffstage: false), findsOneWidget);
    expect(auth.logoutCalls, 0);

    await _tapKey(tester, 'logout_button');
    await _tapKey(tester, 'logout_agree');
    expect(auth.logoutCalls, 1);
    expect(find.byKey(const ValueKey('account_name'), skipOffstage: false), findsNothing);
    expect(find.widgetWithText(FilledButton, AppStrings.login), findsOneWidget);

    // Mở lại app: không còn phiên -> màn Welcome, không vào khu vực Staff.
    await pumpApp(tester, auth, appointmentRepo: FakeAppointmentRepository());
    expect(find.text(AppStrings.startBooking), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
