import '../../../core/constants/app_strings.dart';
import '../../../core/utils/app_date_utils.dart';
import '../../appointments/domain/entities/appointment.dart';
import '../../appointments/domain/entities/appointment_status.dart';

// Logic thuần Dart của thông báo / nhắc lịch cho KHÁCH HÀNG.

/// Loại thông báo.
enum AlertKind { status, dayBefore, hourBefore }

/// Nhắc trước giờ khám bao lâu.
const reminderOffsets = {
  AlertKind.dayBefore: Duration(days: 1),
  AlertKind.hourBefore: Duration(hours: 1),
};

/// Một thông báo cần hiện / hẹn giờ.
class AppointmentAlert {
  const AppointmentAlert({
    required this.id,
    required this.appointmentId,
    required this.kind,
    required this.title,
    required this.body,
    this.fireAt,
  });

  /// Id thông báo của hệ điều hành (ổn định theo lịch hẹn + loại).
  final int id;
  final String appointmentId;
  final AlertKind kind;
  final String title;
  final String body;

  /// Thời điểm hiện (chỉ có với lời nhắc hẹn giờ).
  final DateTime? fireAt;

  /// Dữ liệu gắn kèm.
  String get payload => payloadFor(appointmentId);
}

const _payloadPrefix = 'appointment:';

String payloadFor(String appointmentId) => '$_payloadPrefix$appointmentId';

/// Lấy id lịch hẹn từ payload.
String? appointmentIdFromPayload(String? payload) {
  if (payload == null || !payload.startsWith(_payloadPrefix)) return null;
  final id = payload.substring(_payloadPrefix.length);
  return id.isEmpty ? null : id;
}

/// Id thông báo ổn định (FNV-1a 31 bit) từ id lịch hẹn + loại.
int notificationIdFor(String appointmentId, AlertKind kind) {
  var hash = 0x811c9dc5;
  for (final unit in '$appointmentId#${kind.name}'.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash & 0x7FFFFFFF;
}

String _who(Appointment a) => a.doctorName ?? a.serviceName;

String _when(Appointment a) =>
    '${AppDateUtils.time(a.startAt)} ${AppDateUtils.weekdayDate(a.startAt)}';

/// Lịch vừa được nhân viên xử lý so với lần trước app nhìn thấy.
List<AppointmentAlert> detectStatusChanges(
  Map<String, String> previous,
  List<Appointment> current,
) {
  final alerts = <AppointmentAlert>[];
  for (final a in current) {
    if (previous[a.id] != AppointmentStatus.pending.name) continue;
    final id = notificationIdFor(a.id, AlertKind.status);
    switch (a.status) {
      case AppointmentStatus.confirmed:
        alerts.add(AppointmentAlert(
          id: id,
          appointmentId: a.id,
          kind: AlertKind.status,
          title: AppStrings.alertConfirmedTitle,
          body: AppStrings.alertConfirmedBody(_who(a), _when(a)),
        ));
      case AppointmentStatus.rejected:
        alerts.add(AppointmentAlert(
          id: id,
          appointmentId: a.id,
          kind: AlertKind.status,
          title: AppStrings.alertRejectedTitle,
          body: AppStrings.alertRejectedBody(a.serviceName, _when(a)),
        ));
      case AppointmentStatus.pending:
      case AppointmentStatus.cancelled:
        break;
    }
  }
  return alerts;
}

/// Trạng thái hiện tại của từng lịch (để lưu lại và so sánh lần sau).
Map<String, String> statusSnapshot(List<Appointment> current) =>
    {for (final a in current) a.id: a.status.name};

/// Các lời nhắc NÊN đang được hẹn.
List<AppointmentAlert> planReminders(List<Appointment> current, DateTime now) {
  final plans = <AppointmentAlert>[];
  for (final a in current) {
    if (a.status != AppointmentStatus.confirmed || !a.startAt.isAfter(now)) continue;
    for (final entry in reminderOffsets.entries) {
      final fireAt = a.startAt.subtract(entry.value);
      if (!fireAt.isAfter(now)) continue;
      plans.add(AppointmentAlert(
        id: notificationIdFor(a.id, entry.key),
        appointmentId: a.id,
        kind: entry.key,
        fireAt: fireAt,
        title: entry.key == AlertKind.dayBefore
            ? AppStrings.reminderDayTitle
            : AppStrings.reminderHourTitle,
        body: AppStrings.reminderBody(a.serviceName, _who(a), AppDateUtils.time(a.startAt)),
      ));
    }
  }
  plans.sort((x, y) => x.fireAt!.compareTo(y.fireAt!));
  return plans;
}
