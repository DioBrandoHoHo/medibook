import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/features/appointments/domain/customer_appointments.dart';
import 'package:medibook/features/appointments/domain/entities/appointment_status.dart';
import 'package:medibook/features/booking/domain/availability.dart';
import 'package:medibook/features/home/domain/customer_home_summary.dart';
import 'package:medibook/features/home/domain/staff_home_summary.dart';

import '../../tool/seed_data.dart';

// Bộ dữ liệu ghi sẵn lên Firebase (tool/seed_data.dart).

/// Ngày ghi = Thứ Ba 17/11/2026 14:20.
final _seedAt = DateTime(2026, 11, 17, 14, 20);
const _me = 'cust_uid';

void main() {
  final data = buildSeedData(now: _seedAt, customerId: _me, customerName: 'Nguyễn Văn Bình');
  final mine = data.appointments.where((a) => a.customerId == _me).toList();

  test('id không trùng; mọi bản ghi isDemo', () {
    expect(data.appointments.map((a) => a.id).toSet().length, data.appointments.length);
    expect(data.notifications.map((n) => n.id).toSet().length, data.notifications.length);
    expect(data.appointments.every((a) => a.isDemo && a.doctorId != null), isTrue);
  });

  test('bác sĩ: mỗi chuyên khoa 3–5 người, đủ thông tin, id + phòng không trùng', () {
    final bySpecialty = <String, int>{};
    for (final d in data.doctors) {
      bySpecialty[d.specialty] = (bySpecialty[d.specialty] ?? 0) + 1;
    }
    expect(bySpecialty.keys, hasLength(5));
    for (final entry in bySpecialty.entries) {
      expect(entry.value, inInclusiveRange(3, 5), reason: entry.key);
    }
    expect(data.doctors.map((d) => d.id).toSet().length, data.doctors.length);
    expect(data.doctors.map((d) => d.room).toSet().length, data.doctors.length);
    expect(data.doctors.every((d) => d.bio.isNotEmpty && d.fee > 0 && d.experienceYears > 0), isTrue);
    // Lịch hẹn chỉ trỏ tới bác sĩ có trong danh sách, và bác sĩ nào cũng có lịch.
    final ids = {for (final d in data.doctors) d.id};
    expect(data.appointments.every((a) => ids.contains(a.doctorId)), isTrue);
    expect({for (final a in data.appointments) a.doctorId}, ids);
  });

  test('không bác sĩ nào có 2 lịch còn hiệu lực trùng khung', () {
    final slots = busySlotsOf(data.appointments);
    expect(slots.map((s) => s.id).toSet().length, slots.length);
  });

  test('khung giữ chỗ khớp lịch còn hiệu lực từ hôm nay', () {
    final today = DateTime(2026, 11, 17);
    final expected = busySlotsOf(data.appointments).where((s) => !s.startAt.isBefore(today));
    expect(data.busySlots.map((s) => s.id).toSet(), expected.map((s) => s.id).toSet());
  });

  test('khách hàng mẫu có đủ 3 nhóm vào ngày ghi và cả vào ngày demo (thứ Sáu 20/11)', () {
    for (final now in [_seedAt, DateTime(2026, 11, 20, 9), DateTime(2026, 11, 20, 16)]) {
      for (final group in CustomerAppointmentFilter.values) {
        expect(customerAppointments(mine, group, now), isNotEmpty, reason: '$group lúc $now');
      }
      // Số "Sắp tới" ở Trang chủ khớp tab Lịch hẹn.
      expect(
        customerAppointments(mine, CustomerAppointmentFilter.upcoming, now).length,
        CustomerHomeSummary.from(mine, now).upcomingTotal,
      );
    }
    // Có lịch sang năm 2027, lịch chờ quá giờ, lịch bị từ chối.
    expect(mine.any((a) => a.startAt.year == 2027), isTrue);
    expect(mine.any((a) => a.status == AppointmentStatus.pending && a.startAt.isBefore(_seedAt)), isTrue);
    expect(mine.any((a) => a.status == AppointmentStatus.rejected), isTrue);
    // Khách mẫu không có 2 lịch còn hiệu lực trùng giờ.
    final active = mine.where((a) => a.isActive).toList();
    for (var i = 0; i < active.length; i++) {
      for (var j = i + 1; j < active.length; j++) {
        expect(active[i].startAt == active[j].startAt, isFalse);
      }
    }
  });

  test('ngày nào trong khoảng demo Staff cũng có lịch hôm nay và lịch chờ xử lý', () {
    for (var d = 0; d <= 30; d++) {
      final now = DateTime(2026, 11, 17 + d, 9);
      final s = StaffHomeSummary.from(data.appointments, now);
      expect(s.todayTotal, greaterThan(0), reason: 'ngày +$d');
    }
    expect(StaffHomeSummary.from(data.appointments, _seedAt).pendingAllDays, greaterThan(0));
  });

  test('thông báo: lịch chờ sắp tới chưa đọc; lịch hủy đã đọc; trỏ đúng lịch hẹn', () {
    final ids = {for (final a in data.appointments) a.id};
    expect(data.notifications, isNotEmpty);
    expect(data.notifications.every((n) => ids.contains(n.appointmentId)), isTrue);
    expect(data.notifications.where((n) => !n.isRead).every((n) => n.title == 'Lịch đặt mới'), isTrue);
    expect(data.notifications.every((n) => n.createdAt.isBefore(_seedAt)), isTrue);
  });

  test('số lượng cố định (ghi lại không sinh bản ghi thừa)', () {
    final again = buildSeedData(
      now: _seedAt.add(const Duration(days: 3)),
      customerId: _me,
      customerName: 'Nguyễn Văn Bình',
    );
    expect(again.appointments.map((a) => a.id).toSet(), data.appointments.map((a) => a.id).toSet());
  });
}
