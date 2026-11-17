import '../../../core/utils/app_date_utils.dart';
import '../../appointments/domain/entities/appointment.dart';
import '../../appointments/domain/entities/appointment_status.dart';
import '../../booking/domain/entities/doctor.dart';
import '../../notifications/domain/entities/app_notification.dart';

/// Bộ dữ liệu mẫu tính theo thời điểm [DemoData.build] được gọi – dùng cho bản xem thử không
/// Firebase (`test/demo/main_demo.dart`) và test. Dữ liệu trên Firebase thật được ghi một lần
/// bằng `tool/seed_firestore.dart` (nút "Tạo lại dữ liệu mẫu" trong app đã bỏ ngày 17/11/2026).
/// - Mọi bản ghi có `isDemo = true` và id cố định dạng `demo_xx`.
class DemoData {
  const DemoData({
    required this.appointments,
    required this.notifications,
    required this.doctors,
  });

  final List<Appointment> appointments;
  final List<AppNotification> notifications;
  final List<Doctor> doctors;

  static const demoCustomerId = 'demo';

  /// 5 bác sĩ mẫu – dùng chung cho tab Lịch làm việc (Staff) và phần Đặt lịch (Customer).
  static const demoDoctors = <Doctor>[
    Doctor(
      id: 'demo_d01',
      name: 'BS. Nguyễn Văn An',
      specialty: 'Nội tổng quát',
      room: 'Phòng 101',
      isDemo: true,
      experienceYears: 12,
      fee: 150000,
      bio: 'Khám và điều trị các bệnh nội khoa thường gặp: tăng huyết áp, tiểu đường, '
          'rối loạn tiêu hoá. Tư vấn kiểm tra sức khoẻ định kỳ.',
    ),
    Doctor(
      id: 'demo_d02',
      name: 'BS. Trần Thị Bình',
      specialty: 'Da liễu',
      room: 'Phòng 102',
      isDemo: true,
      experienceYears: 8,
      fee: 180000,
      bio: 'Điều trị mụn trứng cá, viêm da cơ địa, dị ứng da và các bệnh về tóc, móng.',
    ),
    Doctor(
      id: 'demo_d03',
      name: 'BS. Lê Minh Châu',
      specialty: 'Tai mũi họng',
      room: 'Phòng 201',
      isDemo: true,
      experienceYears: 15,
      fee: 170000,
      bio: 'Khám nội soi tai mũi họng, điều trị viêm xoang, viêm họng mạn tính, ù tai.',
    ),
    Doctor(
      id: 'demo_d04',
      name: 'BS. Phạm Quốc Dũng',
      specialty: 'Mắt',
      room: 'Phòng 202',
      isDemo: true,
      experienceYears: 10,
      fee: 160000,
      bio: 'Đo khúc xạ, khám tật cận – loạn thị, khô mắt và các bệnh lý đáy mắt.',
    ),
    Doctor(
      id: 'demo_d05',
      name: 'BS. Hoàng Thu Giang',
      specialty: 'Nhi',
      room: 'Phòng 301',
      isDemo: true,
      experienceYears: 9,
      fee: 150000,
      bio: 'Khám sức khoẻ, dinh dưỡng và các bệnh hô hấp, tiêu hoá thường gặp ở trẻ em.',
    ),
  ];

  factory DemoData.build(DateTime now) {
    // Mốc: nửa giờ kế tiếp sau thời điểm hiện tại (VD 10:10 -> 10:30, 10:40 -> 11:00).
    final base = DateTime(now.year, now.month, now.day, now.hour, now.minute < 30 ? 30 : 60);
    final today = DateTime(now.year, now.month, now.day);
    DateTime day(int offset, int hour, int minute) =>
        DateTime(today.year, today.month, today.day + offset, hour, minute);
    DateTime fromBase(int minutes) => base.add(Duration(minutes: minutes));

    // (giờ bắt đầu, tên khách, dịch vụ, trạng thái)
    // 15 dòng đầu giữ nguyên thứ tự (id demo_01..demo_15 đã được dùng từ trước).
    final rows = <(DateTime, String, String, AppointmentStatus)>[
      // Quanh thời điểm hiện tại (phần lớn rơi vào hôm nay)
      (fromBase(-180), 'Lê Văn Hùng', 'Khám tai mũi họng', AppointmentStatus.confirmed),
      (fromBase(-120), 'Đỗ Thị Lan', 'Khám mắt', AppointmentStatus.cancelled),
      (fromBase(-60), 'Vũ Minh Quân', 'Khám nội tổng quát', AppointmentStatus.confirmed),
      (fromBase(0), 'Nguyễn Thị Mai', 'Khám nội tổng quát', AppointmentStatus.confirmed),
      (fromBase(30), 'Trần Văn Minh', 'Khám da liễu', AppointmentStatus.pending),
      (fromBase(90), 'Phạm Thị Bích', 'Khám sản phụ khoa', AppointmentStatus.pending),
      (fromBase(150), 'Hoàng Đức Anh', 'Khám răng hàm mặt', AppointmentStatus.rejected),
      (fromBase(210), 'Bùi Thu Hà', 'Khám tim mạch', AppointmentStatus.confirmed),
      // Ngày mai
      (day(1, 8, 30), 'Đặng Quốc Bảo', 'Khám nhi', AppointmentStatus.pending),
      (day(1, 9, 0), 'Ngô Thị Hạnh', 'Khám nội tiết', AppointmentStatus.confirmed),
      (day(1, 10, 0), 'Lý Gia Huy', 'Khám cơ xương khớp', AppointmentStatus.cancelled),
      // Ngày kia
      (day(2, 9, 30), 'Trịnh Mỹ Linh', 'Khám da liễu', AppointmentStatus.pending),
      (day(2, 14, 0), 'Phan Văn Sơn', 'Khám tiêu hóa', AppointmentStatus.confirmed),
      // Hôm qua
      (day(-1, 15, 0), 'Dương Thị Yến', 'Khám mắt', AppointmentStatus.confirmed),
      (day(-1, 16, 0), 'Mai Xuân Trường', 'Khám tai mũi họng', AppointmentStatus.rejected),
      // Lịch cố định TRONG giờ làm việc để tab Lịch làm việc luôn có dữ liệu,
      // bất kể bấm tạo vào lúc nào trong ngày.
      (day(0, 8, 0), 'Tạ Quang Vinh', 'Khám nội tổng quát', AppointmentStatus.confirmed),
      (day(0, 9, 0), 'Lương Thị Ngọc', 'Khám da liễu', AppointmentStatus.confirmed),
      (day(0, 14, 0), 'Châu Minh Khoa', 'Khám tai mũi họng', AppointmentStatus.confirmed),
      (day(0, 15, 0), 'Đinh Thị Thảo', 'Khám mắt', AppointmentStatus.confirmed),
      (day(0, 16, 30), 'Quách Gia Bảo', 'Khám nhi', AppointmentStatus.pending),
      (day(1, 7, 30), 'Hà Thị Kim', 'Khám nội tổng quát', AppointmentStatus.confirmed),
      (day(1, 14, 0), 'Vương Đức Long', 'Khám da liễu', AppointmentStatus.pending),
      (day(1, 15, 30), 'Thái Thị Nhung', 'Khám tai mũi họng', AppointmentStatus.confirmed),
      (day(2, 8, 0), 'Kiều Văn Phúc', 'Khám mắt', AppointmentStatus.confirmed),
      (day(2, 15, 0), 'La Thị Diệu', 'Khám nhi', AppointmentStatus.pending),
    ];

    // Gắn bác sĩ cho từng lịch. Hai lịch còn hiệu lực của cùng bác sĩ không được trùng giờ:
    // thử lần lượt các bác sĩ, bắt đầu từ bác sĩ "ưu tiên" theo thứ tự dòng.
    final busy = <String, List<(DateTime, DateTime)>>{for (final d in demoDoctors) d.id: []};
    Doctor doctorFor(int index, DateTime start, DateTime end, bool occupies) {
      for (var k = 0; k < demoDoctors.length; k++) {
        final doctor = demoDoctors[(index + k) % demoDoctors.length];
        final clash = busy[doctor.id]!.any((r) => r.$1.isBefore(end) && r.$2.isAfter(start));
        if (!occupies || !clash) {
          if (occupies) busy[doctor.id]!.add((start, end));
          return doctor;
        }
      }
      return demoDoctors[index % demoDoctors.length];
    }

    final appointments = <Appointment>[];
    for (var i = 0; i < rows.length; i++) {
      final (start, name, service, status) = rows[i];
      final end = start.add(const Duration(minutes: 30));
      final occupies =
          status == AppointmentStatus.pending || status == AppointmentStatus.confirmed;
      final doctor = doctorFor(i, start, end, occupies);
      appointments.add(
        Appointment(
          id: 'demo_${(i + 1).toString().padLeft(2, '0')}',
          customerId: demoCustomerId,
          customerName: name,
          serviceName: service,
          startAt: start,
          endAt: end,
          status: status,
          isDemo: true,
          doctorId: doctor.id,
          doctorName: doctor.name,
        ),
      );
    }

    // Thông báo mẫu: mỗi lịch đang chờ có 1 thông báo CHƯA đọc; thêm 1 thông báo đã đọc.
    final pending = appointments.where((a) => a.isPending).toList();
    final notifications = <AppNotification>[
      for (var i = 0; i < pending.length; i++)
        AppNotification(
          id: 'demo_n${(i + 1).toString().padLeft(2, '0')}',
          title: 'Lịch đặt mới',
          body: newBookingBody(pending[i].customerName, pending[i].serviceName, pending[i].startAt),
          createdAt: now.subtract(Duration(minutes: 10 + i * 25)),
          appointmentId: pending[i].id,
          isDemo: true,
        ),
      AppNotification(
        id: 'demo_n99',
        title: 'Lịch hẹn đã hủy',
        body: cancelledBody(
          appointments[1].customerName,
          appointments[1].serviceName,
          appointments[1].startAt,
        ),
        createdAt: now.subtract(const Duration(hours: 3)),
        isRead: true,
        appointmentId: appointments[1].id,
        isDemo: true,
      ),
    ];

    return DemoData(
      appointments: appointments,
      notifications: notifications,
      doctors: demoDoctors,
    );
  }

  /// Nội dung thông báo "khách đã hủy lịch" (dùng chung cho dữ liệu mẫu và lịch thật).
  static String cancelledBody(String customerName, String serviceName, DateTime startAt) =>
      '$customerName đã hủy lịch $serviceName lúc ${AppDateUtils.time(startAt)} '
      'ngày ${AppDateUtils.date(startAt)}.';

  /// Nội dung thông báo "có lịch đặt mới" (dùng chung cho dữ liệu mẫu và lịch thật).
  static String newBookingBody(String customerName, String serviceName, DateTime startAt) =>
      '$customerName đặt $serviceName lúc ${AppDateUtils.time(startAt)} '
      'ngày ${AppDateUtils.date(startAt)}.';
}
