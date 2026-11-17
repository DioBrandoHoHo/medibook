import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/constants/app_strings.dart';
import 'package:medibook/core/errors/app_failure.dart';
import 'package:medibook/features/appointments/domain/entities/appointment_status.dart';
import 'package:medibook/features/appointments/presentation/controllers/appointments_controller.dart';
import 'package:medibook/features/home/domain/staff_home_summary.dart';
import 'package:medibook/features/notifications/domain/entities/app_notification.dart';
import 'package:medibook/features/notifications/presentation/controllers/notifications_controller.dart';

import '../mocks/fake_clinic_repositories.dart';

void main() {
  final now = DateTime(2026, 11, 14, 10);
  DateTime today(int h) => DateTime(2026, 11, 14, h);

  /// Chờ stream phát dữ liệu xong.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('AppointmentsController', () {
    late FakeNotificationRepository notifications;
    late FakeAppointmentRepository repo;
    late AppointmentsController controller;

    StaffHomeSummary summary() => StaffHomeSummary.from(controller.items, controller.now);

    setUp(() {
      notifications = FakeNotificationRepository();
      repo = FakeAppointmentRepository(
        notifications: notifications,
        initial: [
          appt('p1', today(11)),
          appt('c1', today(12), status: AppointmentStatus.confirmed),
        ],
      );
      controller = AppointmentsController(repo, clock: () => now);
    });

    tearDown(() => controller.dispose());

    test('ban đầu là loading, nhận dữ liệu xong chuyển ready', () async {
      expect(controller.status, LoadStatus.loading);
      controller.start();
      await settle();
      expect(controller.status, LoadStatus.ready);
      expect(controller.items.length, 2);
    });

    test('lỗi tải -> trạng thái error kèm thông báo; retry thành công', () async {
      repo.watchError = const NetworkFailure();
      controller.start();
      await settle();
      expect(controller.status, LoadStatus.error);
      expect(controller.errorMessage, AppStrings.errNetwork);

      repo.watchError = null; // có mạng trở lại
      controller.retry();
      expect(controller.status, LoadStatus.loading);
      await settle();
      expect(controller.status, LoadStatus.ready);
    });

    test('xác nhận lịch: ghi vào nguồn dữ liệu, số liệu tự đổi theo', () async {
      controller.start();
      await settle();
      expect(summary().todayPending, 1);

      expect(await controller.confirm('p1'), isNull);
      await settle();

      expect(repo.items.firstWhere((a) => a.id == 'p1').status, AppointmentStatus.confirmed);
      expect(summary().todayPending, 0);
      expect(summary().todayConfirmed, 2);
      expect(summary().todayTotal, 2);
    });

    test('từ chối lịch: Pending giảm, Hủy/Từ chối tăng, biến mất khỏi sắp diễn ra', () async {
      controller.start();
      await settle();

      expect(await controller.reject('p1'), isNull);
      await settle();

      expect(summary().pendingAllDays, 0);
      expect(summary().todayCancelledOrRejected, 1);
      expect(summary().upcoming.map((a) => a.id), ['c1']);
    });

    test('đổi trạng thái thất bại -> trả về thông báo lỗi, dữ liệu giữ nguyên', () async {
      controller.start();
      await settle();
      repo.nextUpdateError = const PermissionFailure();

      expect(await controller.confirm('p1'), AppStrings.errPermission);
      await settle();
      expect(summary().todayPending, 1);
    });

    test('Customer đặt lịch mới: Pending tăng và có thêm thông báo chưa đọc', () async {
      controller.start();
      await settle();

      await repo.create(
        customerId: 'c9',
        customerName: 'Lê An',
        serviceName: 'Khám mắt',
        startAt: today(15),
        endAt: today(16),
      );
      await settle();

      expect(summary().pendingAllDays, 2);
      expect(summary().todayTotal, 3);
      expect(notifications.items.single.isRead, isFalse);
    });

    test('Customer hủy lịch đã xác nhận: biến mất khỏi sắp diễn ra', () async {
      controller.start();
      await settle();

      await repo.updateStatus('c1', AppointmentStatus.cancelled);
      await settle();

      expect(summary().todayConfirmed, 0);
      expect(summary().todayCancelledOrRejected, 1);
      expect(summary().upcoming.map((a) => a.id), ['p1']);
    });

    test('stop() ngừng lắng nghe và xoá dữ liệu trong bộ nhớ', () async {
      controller.start();
      await settle();
      controller.stop();
      await repo.updateStatus('p1', AppointmentStatus.confirmed);
      await settle();
      expect(controller.items, isEmpty);
      expect(controller.status, LoadStatus.loading);
    });
  });

  group('NotificationsController', () {
    AppNotification note(String id, {bool isRead = false}) => AppNotification(
          id: id,
          title: 'Lịch đặt mới',
          body: 'Nội dung $id',
          createdAt: now.subtract(const Duration(minutes: 5)),
          isRead: isRead,
        );

    test('đếm đúng số chưa đọc; đọc một thông báo thì số giảm', () async {
      final repo = FakeNotificationRepository(
        initial: [note('n1'), note('n2'), note('n3', isRead: true)],
      );
      final controller = NotificationsController(repo)..start();
      addTearDown(controller.dispose);
      await settle();
      expect(controller.unreadCount, 2);

      await controller.markRead('n1');
      await settle();
      expect(controller.unreadCount, 1);
      expect(repo.items.firstWhere((n) => n.id == 'n1').isRead, isTrue);
    });

    test('đánh dấu tất cả đã đọc -> không còn thông báo chưa đọc', () async {
      final repo = FakeNotificationRepository(initial: [note('n1'), note('n2')]);
      final controller = NotificationsController(repo)..start();
      addTearDown(controller.dispose);
      await settle();

      await controller.markAllRead();
      await settle();
      expect(controller.unreadCount, 0);
    });
  });
}
