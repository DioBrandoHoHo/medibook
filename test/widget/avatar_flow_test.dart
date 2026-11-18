import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:medibook/core/constants/app_strings.dart';
import 'package:medibook/core/errors/app_failure.dart';
import 'package:medibook/features/auth/domain/entities/user_role.dart';
import 'package:medibook/features/profile/data/avatar_picker.dart';
import 'package:medibook/features/profile/domain/avatar_image.dart';

import '../mocks/fake_clinic_repositories.dart';
import '../mocks/fake_repositories.dart';
import 'test_helpers.dart';

/// Bộ chọn ảnh giả: trả kết quả đặt trước, xử lý ảnh đồng bộ (không mở thư viện, không isolate).
class FakeAvatarPicker implements AvatarPicker {
  AvatarPickResult next = const AvatarPickCancelled();
  AvatarImageException? prepareError;
  int pickCount = 0;

  @override
  Future<AvatarPickResult> pickFromGallery() async {
    pickCount++;
    return next;
  }

  @override
  Future<String> prepare(Uint8List bytes) async {
    final e = prepareError;
    if (e != null) throw e;
    return AvatarImage.process(bytes);
  }
}

Uint8List _png() {
  final image = img.Image(width: 64, height: 48);
  img.fill(image, color: img.ColorRgb8(30, 120, 220));
  return Uint8List.fromList(img.encodePng(image));
}

FakeAuthRepository _auth(UserRole role, {String avatar = ''}) => FakeAuthRepository()
  ..seed(
    phone: '0900000001',
    password: 'Matkhau@1',
    fullName: role == UserRole.staff ? 'Trần Thu Trang' : 'Nguyễn Văn Bình',
    role: role,
    signedIn: true,
    profilePromptDismissed: true,
    avatar: avatar,
  );

Future<void> _pump(
  WidgetTester tester,
  FakeAuthRepository auth,
  FakeProfileRepository profile,
  FakeAvatarPicker picker,
) async {
  await pumpApp(
    tester,
    auth,
    profileRepo: profile,
    appointmentRepo: FakeAppointmentRepository(),
    clock: () => DateTime(2026, 11, 18, 10),
    avatarPicker: picker,
  );
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

Finder _imageIn(String key) => find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byKey(const ValueKey('user_avatar_image')),
    );

void main() {
  testWidgets('Nhân viên: đổi ảnh -> xem trước -> lưu; ảnh hiện ở Tài khoản và phần đầu Tổng quan',
      (tester) async {
    final auth = _auth(UserRole.staff);
    final profile = FakeProfileRepository(auth);
    final picker = FakeAvatarPicker()..next = AvatarPicked(_png());
    await _pump(tester, auth, profile, picker);
    expect(_imageIn('staff_avatar'), findsNothing); // chưa có ảnh -> chữ cái đầu
    await _openTab(tester, AppStrings.tabAccount);

    await _tap(tester, 'account_avatar');
    expect(find.text(AppStrings.avatarPickGallery), findsOneWidget);
    expect(find.byKey(const ValueKey('avatar_remove')), findsNothing); // chưa có ảnh để xoá
    await _tap(tester, 'avatar_pick_gallery');
    expect(find.byKey(const ValueKey('avatar_preview_image')), findsOneWidget);
    await _tap(tester, 'avatar_preview_save');

    expect(find.text(AppStrings.avatarSaved), findsOneWidget);
    expect(profile.savedAvatars, hasLength(1));
    expect(_imageIn('account_avatar'), findsOneWidget);
    await _openTab(tester, AppStrings.tabOverview);
    expect(_imageIn('staff_avatar'), findsOneWidget);
  });

  testWidgets('Khách hàng: đổi ảnh ở tab Cá nhân -> phần đầu Trang chủ đổi theo', (tester) async {
    final auth = _auth(UserRole.customer);
    final profile = FakeProfileRepository(auth);
    final picker = FakeAvatarPicker()..next = AvatarPicked(_png());
    await _pump(tester, auth, profile, picker);
    await _openTab(tester, AppStrings.tabProfile);

    await _tap(tester, 'account_avatar');
    await _tap(tester, 'avatar_pick_gallery');
    await _tap(tester, 'avatar_preview_save');
    expect(_imageIn('account_avatar'), findsOneWidget);
    await _openTab(tester, AppStrings.tabHome);
    expect(_imageIn('staff_avatar'), findsOneWidget); // header dùng chung key avatar
  });

  testWidgets('ảnh còn sau khi đóng / mở lại app và trên màn Cập nhật thông tin', (tester) async {
    final auth = _auth(UserRole.staff);
    final profile = FakeProfileRepository(auth);
    final picker = FakeAvatarPicker()..next = AvatarPicked(_png());
    await _pump(tester, auth, profile, picker);
    await _openTab(tester, AppStrings.tabAccount);
    await _tap(tester, 'account_avatar');
    await _tap(tester, 'avatar_pick_gallery');
    await _tap(tester, 'avatar_preview_save');

    // "Mở lại app" với cùng nguồn dữ liệu.
    await tester.pumpWidget(const SizedBox());
    await _pump(tester, auth, profile, picker);
    expect(_imageIn('staff_avatar'), findsOneWidget);
    await _openTab(tester, AppStrings.tabAccount);
    expect(_imageIn('account_avatar'), findsOneWidget);
    await _tap(tester, 'edit_profile');
    expect(find.byKey(const ValueKey('user_avatar_image')), findsOneWidget);
  });

  testWidgets('đóng thư viện không chọn / Hủy ở bước xem trước -> không lưu, không báo lỗi',
      (tester) async {
    final auth = _auth(UserRole.staff);
    final profile = FakeProfileRepository(auth);
    final picker = FakeAvatarPicker();
    await _pump(tester, auth, profile, picker);
    await _openTab(tester, AppStrings.tabAccount);

    await _tap(tester, 'account_avatar');
    await _tap(tester, 'avatar_pick_gallery');
    expect(picker.pickCount, 1);
    expect(find.byType(SnackBar), findsNothing);

    picker.next = AvatarPicked(_png());
    await _tap(tester, 'account_avatar');
    await _tap(tester, 'avatar_pick_gallery');
    await _tap(tester, 'avatar_preview_cancel');
    expect(profile.savedAvatars, isEmpty);
    expect(_imageIn('account_avatar'), findsNothing);
  });

  testWidgets('không có quyền / lỗi mở thư viện / ảnh hỏng / ảnh quá lớn -> thông báo dễ hiểu',
      (tester) async {
    final auth = _auth(UserRole.staff);
    final profile = FakeProfileRepository(auth);
    final picker = FakeAvatarPicker();
    await _pump(tester, auth, profile, picker);
    await _openTab(tester, AppStrings.tabAccount);

    Future<void> attempt(AvatarPickResult result, String message) async {
      picker.next = result;
      await _tap(tester, 'account_avatar');
      await _tap(tester, 'avatar_pick_gallery');
      expect(find.text(message), findsOneWidget);
      ScaffoldMessenger.of(tester.element(find.byKey(const ValueKey('account_avatar'))))
          .removeCurrentSnackBar();
      await tester.pumpAndSettle();
    }

    await attempt(const AvatarPickDenied(), AppStrings.avatarPermissionDenied);
    await attempt(const AvatarPickFailed(), AppStrings.avatarPickFailed);
    await attempt(AvatarPicked(Uint8List.fromList([1, 2, 3, 4])), AppStrings.avatarUnsupported);
    picker.prepareError = const AvatarImageException(AvatarImageError.tooLarge);
    await attempt(AvatarPicked(_png()), AppStrings.avatarTooLarge);

    expect(profile.savedAvatars, isEmpty);
    expect(find.byKey(const ValueKey('avatar_busy')), findsNothing);
  });

  testWidgets('lưu thất bại (mất mạng) -> báo lỗi, giữ ảnh cũ', (tester) async {
    final auth = _auth(UserRole.staff);
    final profile = FakeProfileRepository(auth)..nextAvatarError = const NetworkFailure();
    final picker = FakeAvatarPicker()..next = AvatarPicked(_png());
    await _pump(tester, auth, profile, picker);
    await _openTab(tester, AppStrings.tabAccount);

    await _tap(tester, 'account_avatar');
    await _tap(tester, 'avatar_pick_gallery');
    await _tap(tester, 'avatar_preview_save');
    expect(find.text(const NetworkFailure().message), findsOneWidget);
    expect(_imageIn('account_avatar'), findsNothing);
  });

  testWidgets('xoá ảnh: có hỏi lại; Hủy giữ nguyên, Xoá thì về chữ cái đầu', (tester) async {
    final encoded = AvatarImage.process(_png());
    final auth = _auth(UserRole.customer, avatar: encoded);
    final profile = FakeProfileRepository(auth);
    await _pump(tester, auth, profile, FakeAvatarPicker());
    await _openTab(tester, AppStrings.tabProfile);
    expect(_imageIn('account_avatar'), findsOneWidget);

    await _tap(tester, 'account_avatar');
    await _tap(tester, 'avatar_remove');
    await _tap(tester, 'avatar_remove_cancel');
    expect(_imageIn('account_avatar'), findsOneWidget);

    await _tap(tester, 'account_avatar');
    await _tap(tester, 'avatar_remove');
    await _tap(tester, 'avatar_remove_confirm');
    expect(find.text(AppStrings.avatarRemoved), findsOneWidget);
    expect(_imageIn('account_avatar'), findsNothing);
    expect(profile.savedAvatars, ['']);
  });

  testWidgets('ảnh lưu trên máy chủ bị hỏng -> hiện chữ cái đầu, không crash', (tester) async {
    final auth = _auth(UserRole.staff, avatar: '%%%hỏng%%%');
    await _pump(tester, auth, FakeProfileRepository(auth), FakeAvatarPicker());
    await _openTab(tester, AppStrings.tabAccount);
    expect(_imageIn('account_avatar'), findsNothing);
    expect(find.descendant(of: find.byKey(const ValueKey('account_avatar')), matching: find.text('T')),
        findsOneWidget);
  });

  group('Cập nhật thông tin – hỏi trước khi bỏ thay đổi', () {
    testWidgets('không sửa gì -> quay lại ngay, không hỏi', (tester) async {
      final auth = _auth(UserRole.staff);
      await _pump(tester, auth, FakeProfileRepository(auth), FakeAvatarPicker());
      await _openTab(tester, AppStrings.tabAccount);
      await _tap(tester, 'edit_profile');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.discardChangesTitle), findsNothing);
      expect(find.text(AppStrings.profileEditTitle), findsNothing);
    });

    testWidgets('đã sửa -> hỏi; Tiếp tục sửa thì ở lại; Bỏ thay đổi thì quay lại, dữ liệu không đổi',
        (tester) async {
      final auth = _auth(UserRole.staff);
      final profile = FakeProfileRepository(auth);
      await _pump(tester, auth, profile, FakeAvatarPicker());
      await _openTab(tester, AppStrings.tabAccount);
      await _tap(tester, 'edit_profile');
      await tester.enterText(fieldByLabel(AppStrings.fullName), 'Tên sửa dở');
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.discardChangesTitle), findsOneWidget);
      await _tap(tester, 'discard_keep_editing');
      expect(find.text(AppStrings.profileEditTitle), findsOneWidget);
      expect(find.text('Tên sửa dở'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await _tap(tester, 'discard_confirm');
      expect(find.text(AppStrings.profileEditTitle), findsNothing);
      expect(profile.savedNames, isEmpty);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('account_name'))).data,
        'Trần Thu Trang',
      );
    });

    testWidgets('đã sửa rồi bấm Lưu -> quay lại không bị hỏi', (tester) async {
      final auth = _auth(UserRole.staff);
      final profile = FakeProfileRepository(auth);
      await _pump(tester, auth, profile, FakeAvatarPicker());
      await _openTab(tester, AppStrings.tabAccount);
      await _tap(tester, 'edit_profile');
      await tester.enterText(fieldByLabel(AppStrings.fullName), 'Tên mới');
      await tapButton(tester, AppStrings.save);
      expect(find.text(AppStrings.discardChangesTitle), findsNothing);
      expect(profile.savedNames, ['Tên mới']);
      expect(tester.widget<Text>(find.byKey(const ValueKey('account_name'))).data, 'Tên mới');
    });
  });
}
