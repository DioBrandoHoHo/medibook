// Bộ dữ liệu ghi SẴN lên Firebase (thay cho nút "Tạo lại dữ liệu mẫu" đã bỏ ngày 17/11/2026).
// Thuần Dart (không Flutter / Firebase) để unit test được – xem test/unit/seed_data_test.dart.
//
// Khác `DemoData.build` (dữ liệu quanh "bây giờ" cho bản xem thử): bộ này ghi MỘT LẦN rồi dùng
// nhiều ngày, nên lịch được rải đều từ 7 ngày trước tới 45 ngày sau ngày ghi – ngày nào mở app
// trong khoảng đó Staff cũng có lịch hôm nay / sắp tới, và khách hàng mẫu luôn có đủ 3 nhóm
// Sắp tới / Đã qua / Đã hủy ở tab Lịch hẹn.

import 'package:medibook/features/appointments/domain/entities/appointment.dart';
import 'package:medibook/features/appointments/domain/entities/appointment_status.dart';
import 'package:medibook/features/booking/domain/availability.dart';
import 'package:medibook/features/booking/domain/entities/busy_slot.dart';
import 'package:medibook/features/booking/domain/entities/doctor.dart';
import 'package:medibook/features/home/domain/demo_data.dart';
import 'package:medibook/features/notifications/domain/entities/app_notification.dart';
import 'package:medibook/features/schedule/domain/work_shift.dart';

class SeedData {
  const SeedData({
    required this.doctors,
    required this.appointments,
    required this.notifications,
    required this.busySlots,
  });

  final List<Doctor> doctors;
  final List<Appointment> appointments;
  final List<AppNotification> notifications;
  final List<BusySlot> busySlots;
}

/// Ngày đầu / cuối (tính từ ngày ghi) có lịch của các khách khác.
const seedFirstDay = -7;
const seedLastDay = 45;

/// Số lịch mỗi ngày của các khách khác.
const seedPerDay = 8;

/// 20 bác sĩ, mỗi chuyên khoa 3–5 người (yêu cầu của người dùng ngày 17/11/2026).
/// 5 người đầu giữ nguyên id `demo_d01`…`demo_d05` của bộ cũ (lịch hẹn cũ đang trỏ tới).
const seedDoctors = <Doctor>[
  ...DemoData.demoDoctors,
  // Nội tổng quát (5)
  Doctor(id: 'seed_d06', name: 'BS. Trương Thị Hồng', specialty: 'Nội tổng quát', room: 'Phòng 103',
      isDemo: true, experienceYears: 7, fee: 150000,
      bio: 'Khám nội khoa tổng quát, quản lý bệnh mạn tính và tư vấn chế độ sinh hoạt.'),
  Doctor(id: 'seed_d07', name: 'BS. Võ Thành Nam', specialty: 'Nội tổng quát', room: 'Phòng 104',
      isDemo: true, experienceYears: 18, fee: 200000,
      bio: 'Chuyên điều trị tăng huyết áp, rối loạn mỡ máu và bệnh lý tim mạch thường gặp.'),
  Doctor(id: 'seed_d08', name: 'BS. Đặng Minh Tuấn', specialty: 'Nội tổng quát', room: 'Phòng 105',
      isDemo: true, experienceYears: 5, fee: 130000,
      bio: 'Khám sức khoẻ tổng quát, sức khoẻ định kỳ cho người đi làm.'),
  Doctor(id: 'seed_d09', name: 'BS. Lâm Thị Thu', specialty: 'Nội tổng quát', room: 'Phòng 106',
      isDemo: true, experienceYears: 11, fee: 160000,
      bio: 'Điều trị bệnh tiêu hoá, dạ dày, đại tràng và bệnh lý gan mật.'),
  // Da liễu (4)
  Doctor(id: 'seed_d10', name: 'BS. Nguyễn Hoài Phương', specialty: 'Da liễu', room: 'Phòng 107',
      isDemo: true, experienceYears: 6, fee: 170000,
      bio: 'Điều trị mụn, sẹo mụn, nám và tư vấn chăm sóc da theo từng loại da.'),
  Doctor(id: 'seed_d11', name: 'BS. Cao Văn Thịnh', specialty: 'Da liễu', room: 'Phòng 108',
      isDemo: true, experienceYears: 14, fee: 200000,
      bio: 'Chẩn đoán và điều trị vảy nến, nấm da, viêm da tiếp xúc.'),
  Doctor(id: 'seed_d12', name: 'BS. Phùng Thị Ánh', specialty: 'Da liễu', room: 'Phòng 109',
      isDemo: true, experienceYears: 9, fee: 180000,
      bio: 'Khám các bệnh lý về tóc, móng và dị ứng da ở trẻ em và người lớn.'),
  // Tai mũi họng (3)
  Doctor(id: 'seed_d13', name: 'BS. Hồ Quang Hải', specialty: 'Tai mũi họng', room: 'Phòng 203',
      isDemo: true, experienceYears: 12, fee: 170000,
      bio: 'Nội soi tai mũi họng, điều trị viêm mũi dị ứng và viêm amidan.'),
  Doctor(id: 'seed_d14', name: 'BS. Lục Thị Mến', specialty: 'Tai mũi họng', room: 'Phòng 204',
      isDemo: true, experienceYears: 8, fee: 160000,
      bio: 'Khám và điều trị ù tai, nghe kém, viêm tai giữa.'),
  // Mắt (4)
  Doctor(id: 'seed_d15', name: 'BS. Tôn Nữ Khánh Linh', specialty: 'Mắt', room: 'Phòng 205',
      isDemo: true, experienceYears: 7, fee: 160000,
      bio: 'Đo thị lực, cắt kính, điều trị khô mắt do làm việc với máy tính.'),
  Doctor(id: 'seed_d16', name: 'BS. Huỳnh Đức Trí', specialty: 'Mắt', room: 'Phòng 206',
      isDemo: true, experienceYears: 16, fee: 200000,
      bio: 'Khám đáy mắt, tầm soát glôcôm và bệnh võng mạc đái tháo đường.'),
  Doctor(id: 'seed_d17', name: 'BS. Mạc Thị Lụa', specialty: 'Mắt', room: 'Phòng 207',
      isDemo: true, experienceYears: 4, fee: 140000,
      bio: 'Khám mắt trẻ em, tư vấn kiểm soát cận thị tiến triển.'),
  // Nhi (4)
  Doctor(id: 'seed_d18', name: 'BS. Kim Ngọc Bảo Trâm', specialty: 'Nhi', room: 'Phòng 302',
      isDemo: true, experienceYears: 10, fee: 160000,
      bio: 'Khám và tư vấn dinh dưỡng, theo dõi tăng trưởng cho trẻ dưới 6 tuổi.'),
  Doctor(id: 'seed_d19', name: 'BS. Doãn Văn Khải', specialty: 'Nhi', room: 'Phòng 303',
      isDemo: true, experienceYears: 13, fee: 180000,
      bio: 'Điều trị bệnh hô hấp ở trẻ: viêm phế quản, hen phế quản, viêm phổi.'),
  Doctor(id: 'seed_d20', name: 'BS. Tạ Thanh Vân', specialty: 'Nhi', room: 'Phòng 304',
      isDemo: true, experienceYears: 6, fee: 150000,
      bio: 'Khám tiêu hoá trẻ em, tư vấn tiêm chủng và chăm sóc trẻ sơ sinh.'),
];

const _otherNames = [
  'Lê Văn Hùng', 'Đỗ Thị Lan', 'Vũ Minh Quân', 'Nguyễn Thị Mai', 'Trần Văn Minh',
  'Phạm Thị Bích', 'Hoàng Đức Anh', 'Bùi Thu Hà', 'Đặng Quốc Bảo', 'Ngô Thị Hạnh',
  'Lý Gia Huy', 'Trịnh Mỹ Linh', 'Phan Văn Sơn', 'Dương Thị Yến', 'Mai Xuân Trường',
  'Tạ Quang Vinh', 'Lương Thị Ngọc', 'Châu Minh Khoa', 'Đinh Thị Thảo', 'Quách Gia Bảo',
  'Hà Thị Kim', 'Vương Đức Long', 'Thái Thị Nhung', 'Kiều Văn Phúc', 'La Thị Diệu',
];

/// Sinh bộ dữ liệu theo ngày ghi [now]. [customerId] / [customerName] = khách hàng mẫu
/// (tài khoản `0912345678`), có 10 lịch thuộc đủ 3 nhóm của tab Lịch hẹn.
SeedData buildSeedData({
  required DateTime now,
  required String customerId,
  required String customerName,
}) {
  const doctors = seedDoctors;
  final today = DateTime(now.year, now.month, now.day);
  DateTime at(int dayOffset, int hour, int minute) =>
      DateTime(today.year, today.month, today.day + dayOffset, hour, minute);

  Appointment make(
    String id,
    DateTime start,
    Doctor doctor,
    AppointmentStatus status, {
    required String cid,
    required String name,
  }) =>
      Appointment(
        id: id,
        customerId: cid,
        customerName: name,
        serviceName: doctor.serviceName,
        startAt: start,
        endAt: start.add(const Duration(minutes: WorkShift.slotMinutes)),
        status: status,
        isDemo: true,
        doctorId: doctor.id,
        doctorName: doctor.name,
      );

  // ----- Lịch của khách hàng mẫu: (ngày lệch, giờ, phút, bác sĩ, trạng thái) -----
  // Sắp tới: ≥ 6 ngày sau ngày ghi để vẫn "sắp tới" trong buổi demo; có 1 lịch sang năm sau.
  // Đã qua: Đã xác nhận (đã khám) + 1 lịch Chờ xác nhận quá giờ.
  // Đã hủy: khách tự hủy + bị phòng khám từ chối.
  final mineRows = <(int, int, int, int, AppointmentStatus)>[
    (6, 9, 0, 0, AppointmentStatus.confirmed),
    (9, 14, 30, 2, AppointmentStatus.pending),
    (16, 8, 30, 1, AppointmentStatus.pending),
    (49, 9, 30, 3, AppointmentStatus.confirmed),
    (-2, 8, 0, 3, AppointmentStatus.confirmed),
    (-7, 15, 0, 0, AppointmentStatus.confirmed),
    (-4, 10, 0, 4, AppointmentStatus.pending),
    (-5, 9, 0, 1, AppointmentStatus.cancelled),
    (-1, 14, 0, 2, AppointmentStatus.rejected),
    (12, 10, 30, 0, AppointmentStatus.cancelled),
  ];
  final mine = <Appointment>[
    for (var i = 0; i < mineRows.length; i++)
      make(
        'seed_c${(i + 1).toString().padLeft(2, '0')}',
        at(mineRows[i].$1, mineRows[i].$2, mineRows[i].$3),
        doctors[mineRows[i].$4],
        mineRows[i].$5,
        cid: customerId,
        name: customerName,
      ),
  ];

  // ----- Lịch của các khách khác: [seedPerDay] lịch / ngày, không trùng bác sĩ + khung -----
  final taken = <String>{
    for (final a in mine)
      if (a.isActive) BusySlot.idOf(a.doctorId!, a.startAt),
  };
  final slotMinutes = allSlotMinutes(); // 16 khung / ngày
  final others = <Appointment>[];
  var n = 0;
  for (var d = seedFirstDay; d <= seedLastDay; d++) {
    final dayIndex = d - seedFirstDay;
    final base = (dayIndex * 5) % slotMinutes.length;
    for (var k = 0; k < seedPerDay; k++) {
      // k * 2 -> 8 khung khác nhau trong ngày (16 khung).
      final minutes = slotMinutes[(base + k * 2) % slotMinutes.length];
      final start = at(d, minutes ~/ 60, minutes % 60);
      final status = _otherStatus(d, k, dayIndex, start, now);
      // Bác sĩ: xoay vòng theo ngày; trùng khung với lịch còn hiệu lực -> thử bác sĩ kế tiếp.
      final first = (dayIndex * 7 + k * 3) % doctors.length;
      var doctor = doctors[first];
      final active = status == AppointmentStatus.pending || status == AppointmentStatus.confirmed;
      if (active) {
        for (var t = 0; t < doctors.length; t++) {
          final candidate = doctors[(first + t) % doctors.length];
          if (!taken.contains(BusySlot.idOf(candidate.id, start))) {
            doctor = candidate;
            break;
          }
        }
        taken.add(BusySlot.idOf(doctor.id, start));
      }
      n++;
      others.add(make(
        'seed_a${n.toString().padLeft(3, '0')}',
        start,
        doctor,
        status,
        cid: DemoData.demoCustomerId,
        name: _otherNames[(dayIndex * seedPerDay + k) % _otherNames.length],
      ));
    }
  }

  final appointments = [...mine, ...others];

  // ----- Thông báo cho Staff -----
  // "Lịch đặt mới" (chưa đọc) cho lịch chờ trong 10 ngày tới; "Lịch hẹn đã hủy" (đã đọc) cho
  // lịch khách tự hủy trong khoảng 3 ngày trước – 10 ngày sau.
  final notifications = <AppNotification>[];
  var minutesAgo = 15;
  for (final a in appointments..sort((x, y) => x.startAt.compareTo(y.startAt))) {
    final offset = a.startAt.difference(today).inDays;
    if (a.status == AppointmentStatus.pending && a.startAt.isAfter(now) && offset <= 10) {
      notifications.add(AppNotification(
        id: 'seed_n_${a.id}',
        title: 'Lịch đặt mới',
        body: DemoData.newBookingBody(a.customerName, a.serviceName, a.startAt),
        createdAt: now.subtract(Duration(minutes: minutesAgo)),
        appointmentId: a.id,
        isDemo: true,
      ));
      minutesAgo += 47;
    } else if (a.status == AppointmentStatus.cancelled && offset >= -3 && offset <= 10) {
      notifications.add(AppNotification(
        id: 'seed_n_${a.id}',
        title: 'Lịch hẹn đã hủy',
        body: DemoData.cancelledBody(a.customerName, a.serviceName, a.startAt),
        createdAt: now.subtract(Duration(minutes: minutesAgo)),
        isRead: true,
        appointmentId: a.id,
        isDemo: true,
      ));
      minutesAgo += 47;
    }
  }

  // Khung giữ chỗ: chỉ lịch còn hiệu lực, từ hôm nay trở đi (khách chỉ cần khung tương lai).
  final busySlots =
      busySlotsOf(appointments).where((s) => !s.startAt.isBefore(today)).toList();

  return SeedData(
    doctors: doctors,
    appointments: appointments,
    notifications: notifications,
    busySlots: busySlots,
  );
}

/// Trạng thái lịch của khách khác theo ngày [d] (lệch so với ngày ghi) và thứ tự [k] trong ngày.
AppointmentStatus _otherStatus(int d, int k, int dayIndex, DateTime start, DateTime now) {
  if (start.isBefore(now)) {
    // Đã qua: phần lớn đã khám; mỗi ngày 1 lịch hủy + 1 lịch bị từ chối.
    if (k == 2) return AppointmentStatus.cancelled;
    if (k == 6) return AppointmentStatus.rejected;
    return AppointmentStatus.confirmed;
  }
  // Tương lai: lịch gần (≤ 10 ngày) có lịch chờ để Staff xử lý; lịch xa phần lớn đã xác nhận.
  if (k == 3 && dayIndex % 3 == 0) return AppointmentStatus.cancelled;
  if (k == 7 && dayIndex % 4 == 0) return AppointmentStatus.rejected;
  if (d <= 10) return k == 1 || k == 5 ? AppointmentStatus.pending : AppointmentStatus.confirmed;
  return k == 1 && dayIndex.isEven ? AppointmentStatus.pending : AppointmentStatus.confirmed;
}
