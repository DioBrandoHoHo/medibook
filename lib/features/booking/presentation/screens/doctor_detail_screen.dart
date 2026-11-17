import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/shells/customer_nav_controller.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../core/utils/name_utils.dart';
import '../../../../core/utils/text_utils.dart';
import '../../../../core/widgets/day_picker.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../appointments/presentation/controllers/appointments_controller.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../schedule/domain/work_shift.dart';
import '../../domain/availability.dart';
import '../../domain/booking_window.dart';
import '../../domain/entities/doctor.dart';
import '../controllers/busy_slots_controller.dart';
import '../controllers/doctors_controller.dart';
import '../widgets/doctor_card.dart';

/// Màn "Thông tin bác sĩ" (dat_lich.txt mục 5–6): thông tin bác sĩ, lịch còn trống theo
/// ngày + buổi, chọn một khung và đặt lịch.
///
/// Màn này KHÔNG giữ bản sao dữ liệu: bác sĩ đọc theo id từ `DoctorsController`, trạng thái
/// khung tính bằng [buildBookSlots] từ `BusySlotsController` + lịch hẹn của chính khách.
/// Có người khác đặt mất khung đang chọn thì khung đổi màu và lựa chọn tự bỏ.
class DoctorDetailScreen extends StatefulWidget {
  const DoctorDetailScreen({
    super.key,
    required this.doctorId,
    this.day,
    this.slotMinutes,
    this.onViewAppointments,
  });

  final String doctorId;

  /// Mở tab Lịch hẹn (nút "Xem lịch hẹn" trên thông báo đặt thành công). `null` = không hiện nút.
  final VoidCallback? onViewAppointments;

  /// Ngày mở sẵn (mặc định hôm nay).
  final DateTime? day;

  /// Khung giờ chọn sẵn (từ bộ lọc "Thời gian mong muốn").
  final int? slotMinutes;

  static Future<void> open(
    BuildContext context, {
    required String doctorId,
    DateTime? day,
    int? slotMinutes,
  }) {
    // Mở từ trong khu vực Customer (Trang chủ / Đặt lịch) thì có điều hướng tab; mở từ màn
    // được đẩy lên trên (VD Chi tiết lịch hẹn) thì không có -> không hiện nút "Xem lịch hẹn".
    final nav = context.read<CustomerNavController?>();
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DoctorDetailScreen(
          doctorId: doctorId,
          day: day,
          slotMinutes: slotMinutes,
          onViewAppointments: nav?.openAppointments,
        ),
      ),
    );
  }

  @override
  State<DoctorDetailScreen> createState() => _DoctorDetailScreenState();
}

class _DoctorDetailScreenState extends State<DoctorDetailScreen> {
  DateTime? _day;
  WorkShift? _shift;

  /// Giờ bắt đầu của khung đang chọn.
  DateTime? _selected;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final day = widget.day;
    final minutes = widget.slotMinutes;
    if (day != null) {
      _day = AppDateUtils.dayOnly(day);
      if (minutes != null) {
        _selected = slotStartOn(day, minutes);
        _shift = _shiftOf(_selected!);
      }
    }
  }

  static WorkShift _shiftOf(DateTime start) =>
      start.isBefore(WorkShift.morning.endOn(start))
      ? WorkShift.morning
      : WorkShift.afternoon;

  void _selectDay(DateTime day) => setState(() {
    _day = day;
    _shift = null; // sang ngày khác -> về buổi mặc định của ngày đó
    _selected = null;
  });

  @override
  Widget build(BuildContext context) {
    final doctors = context.watch<DoctorsController>();
    final appointments = context.watch<AppointmentsController>();
    final busy = context.watch<BusySlotsController>();
    final doctor = doctors.byId(widget.doctorId);

    if (doctor == null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          title: const Text(AppStrings.doctorInfo),
        ),
        body: doctors.status == LoadStatus.loading
            ? const LoadingView()
            : const Center(
                child: EmptyView(
                  message: AppStrings.doctorNotFound,
                  icon: Icons.person_off_outlined,
                ),
              ),
      );
    }

    final now = appointments.now;
    final today = AppDateUtils.dayOnly(now);
    final day = BookingWindow.clamp(_day, now);
    final shift = _shift ?? WorkShift.defaultFor(day, now);
    final mine = appointments.items;
    final slots = buildBookSlots(
      doctorId: doctor.id,
      day: day,
      shift: shift,
      busyIds: busy.ids,
      mine: mine,
      now: now,
    );
    final freeInDay = freeSlotStarts(
      doctorId: doctor.id,
      day: day,
      busyIds: busy.ids,
      mine: mine,
      now: now,
    );
    // Khung đang chọn không còn trống (người khác vừa đặt / đã tới giờ) -> coi như chưa chọn.
    final selected = _selected != null && freeInDay.contains(_selected)
        ? _selected
        : null;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text(AppStrings.doctorInfo),
      ),
      body: ListView(
        key: const ValueKey('doctor_detail_list'),
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _DoctorHeader(doctor: doctor),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SectionCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Heading(AppStrings.about),
                    const SizedBox(height: 6),
                    Text(
                      doctor.bio.isEmpty ? AppStrings.aboutEmpty : doctor.bio,
                      key: const ValueKey('doctor_bio'),
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: doctor.bio.isEmpty
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                        fontStyle: doctor.bio.isEmpty
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: _Heading(AppStrings.pickDay),
          ),
          const SizedBox(height: 10),
          DayPicker(
            today: today,
            selected: day,
            lastDay: BookingWindow.lastDay(now),
            // Ngày không còn khung trống nào của bác sĩ này (kín lịch / hết giờ) -> mờ.
            isEnabled: (d) => freeSlotStarts(
              doctorId: doctor.id,
              day: d,
              busyIds: busy.ids,
              mine: mine,
              now: now,
            ).isNotEmpty,
            disabledLabel: AppStrings.fullDay,
            note: AppStrings.bookingRange(
              AppDateUtils.date(BookingWindow.firstDay(now)),
              AppDateUtils.date(BookingWindow.lastDay(now)),
            ),
            onSelect: _selectDay,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SectionCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(child: _Heading(AppStrings.pickTime)),
                        Text(
                          freeInDay.isEmpty
                              ? AppStrings.fullDay
                              : AppStrings.freeSlots(freeInDay.length),
                          key: const ValueKey('detail_free_count'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: freeInDay.isEmpty
                                ? AppColors.textSecondary
                                : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _ShiftSwitch(
                      shift: shift,
                      onChanged: (value) => setState(() => _shift = value),
                    ),
                    const SizedBox(height: 12),
                    _SlotGrid(
                      slots: slots,
                      selected: selected,
                      onSelect: (start) => setState(() => _selected = start),
                    ),
                    const SizedBox(height: 14),
                    const _Legend(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BookBar(
        selected: selected,
        submitting: _submitting,
        onBook: selected == null ? null : () => _book(doctor, selected),
      ),
    );
  }

  Future<void> _book(Doctor doctor, DateTime start) async {
    final auth = context.read<AuthController>();
    final appointments = context.read<AppointmentsController>();
    final busy = context.read<BusySlotsController>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final user = auth.currentUser;
    if (user == null) return;
    if (user.fullName.trim().isEmpty) {
      _showError(messenger, AppStrings.errNameMissing);
      return;
    }
    final end = start.add(const Duration(minutes: WorkShift.slotMinutes));

    final agreed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ConfirmSheet(
        doctor: doctor,
        start: start,
        end: end,
        patientName: user.fullName,
        patientPhone: user.phone,
      ),
    );
    if (agreed != true || !mounted) return;

    // Kiểm tra lại theo dữ liệu MỚI NHẤT (trong lúc xem bảng xác nhận có thể đã có người đặt).
    final problem = checkBooking(
      doctorId: doctor.id,
      start: start,
      busyIds: busy.ids,
      mine: appointments.items,
      now: appointments.now,
    );
    if (problem != null) {
      setState(() => _selected = null);
      _showError(messenger, problem);
      return;
    }

    setState(() => _submitting = true);
    final error = await appointments.book(
      customerId: user.id,
      customerName: user.fullName.trim(),
      serviceName: doctor.serviceName,
      doctorId: doctor.id,
      doctorName: doctor.name,
      startAt: start,
      endAt: end,
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _selected = null;
    });
    if (error != null) {
      _showError(messenger, error);
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text(AppStrings.bookedDone),
          action: widget.onViewAppointments == null
              ? null
              : SnackBarAction(
                  key: const ValueKey('view_appointments'),
                  label: AppStrings.viewAppointments,
                  onPressed: widget.onViewAppointments!,
                ),
        ),
      );
    navigator.pop();
  }

  static void _showError(ScaffoldMessengerState messenger, String message) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error),
      );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    ),
  );
}

/// Thẻ nền xanh: chữ cái đại diện, họ tên, chuyên khoa, phòng, kinh nghiệm, phí khám.
class _DoctorHeader extends StatelessWidget {
  const _DoctorHeader({required this.doctor});

  final Doctor doctor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryBright,
              AppColors.primary,
              AppColors.primaryDark,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                    child: InitialAvatar(
                      initial: NameUtils.initial(doctor.name),
                      radius: 30,
                      background: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doctor.name,
                          key: const ValueKey('detail_doctor_name'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          doctor.specialty,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.92),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (doctor.room.isNotEmpty)
                    _Pill(icon: Icons.meeting_room_outlined, text: doctor.room),
                  if (doctor.experienceYears > 0)
                    _Pill(
                      icon: Icons.workspace_premium_outlined,
                      text: AppStrings.experience(doctor.experienceYears),
                    ),
                  if (doctor.fee > 0)
                    _Pill(
                      icon: Icons.payments_outlined,
                      text:
                          '${AppStrings.feeLabel} ${TextUtils.money(doctor.fee)}',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Nút chọn buổi Sáng / Chiều.
class _ShiftSwitch extends StatelessWidget {
  const _ShiftSwitch({required this.shift, required this.onChanged});

  final WorkShift shift;
  final ValueChanged<WorkShift> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final value in WorkShift.values)
            Expanded(
              child: Material(
                color: value == shift ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(11),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: ValueKey('detail_shift_${value.name}'),
                  onTap: () => onChanged(value),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Text(
                      '${value == WorkShift.morning ? AppStrings.shiftMorning : AppStrings.shiftAfternoon}'
                      '  ${AppDateUtils.time(value.startOn(DateTime(2000)))}'
                      ' – ${AppDateUtils.time(value.endOn(DateTime(2000)))}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: value == shift
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Lưới khung giờ của buổi đang xem (4 khung một hàng).
class _SlotGrid extends StatelessWidget {
  const _SlotGrid({
    required this.slots,
    required this.selected,
    required this.onSelect,
  });

  final List<BookSlot> slots;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.3,
      children: [
        for (final slot in slots)
          _SlotCell(
            slot: slot,
            selected: slot.start == selected,
            onTap: slot.isFree ? () => onSelect(slot.start) : null,
          ),
      ],
    );
  }
}

class _SlotCell extends StatelessWidget {
  const _SlotCell({
    required this.slot,
    required this.selected,
    required this.onTap,
  });

  final BookSlot slot;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (
      Color background,
      Color border,
      Color foreground,
      String? caption,
    ) = selected
        ? (AppColors.primary, AppColors.primary, Colors.white, null)
        : switch (slot.state) {
            BookSlotState.free => (
              Colors.white,
              AppColors.primary,
              AppColors.primary,
              null,
            ),
            BookSlotState.taken => (
              AppColors.surface,
              AppColors.border,
              AppColors.textSecondary,
              AppStrings.slotTaken,
            ),
            BookSlotState.mine => (
              AppColors.warningLight,
              AppColors.warning,
              AppColors.warningDark,
              AppStrings.slotMine,
            ),
            BookSlotState.past => (
              AppColors.surface,
              AppColors.border,
              AppColors.textSecondary,
              AppStrings.slotPast,
            ),
          };
    final minutes = slot.start.hour * 60 + slot.start.minute;
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('slot_$minutes'),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: selected ? 1.6 : 1),
          ),
          // Co chữ lại nếu ô hẹp (màn nhỏ / cỡ chữ hệ thống lớn) thay vì tràn.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppDateUtils.time(slot.start),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
                if (caption != null)
                  Text(
                    caption,
                    key: ValueKey('slot_state_$minutes'),
                    style: TextStyle(fontSize: 10.5, color: foreground),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    const items = <(Color, Color, String)>[
      (Colors.white, AppColors.primary, AppStrings.legendFree),
      (AppColors.primary, AppColors.primary, AppStrings.legendSelected),
      (AppColors.surface, AppColors.border, AppStrings.legendTaken),
      (AppColors.warningLight, AppColors.warning, AppStrings.legendMine),
    ];
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: [
        for (final (background, border, label) in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: border),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Thanh dưới cùng: khung đang chọn + nút Đặt lịch.
class _BookBar extends StatelessWidget {
  const _BookBar({
    required this.selected,
    required this.submitting,
    required this.onBook,
  });

  final DateTime? selected;
  final bool submitting;
  final VoidCallback? onBook;

  @override
  Widget build(BuildContext context) {
    final start = selected;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: start == null
                    ? const Text(
                        AppStrings.noSlotChosen,
                        key: ValueKey('book_summary'),
                        style: TextStyle(
                          fontSize: 13.5,
                          color: AppColors.textSecondary,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            AppDateUtils.timeRange(
                              start,
                              start.add(
                                const Duration(minutes: WorkShift.slotMinutes),
                              ),
                            ),
                            key: const ValueKey('book_summary'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            AppDateUtils.weekdayDate(start),
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                key: const ValueKey('book_button'),
                onPressed: submitting ? null : onBook,
                style: FilledButton.styleFrom(minimumSize: const Size(140, 50)),
                child: submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Text(AppStrings.bookAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bảng xác nhận trước khi đặt: bác sĩ, dịch vụ, ngày giờ, phòng, người khám.
/// Người khám lấy từ hồ sơ đang đăng nhập (cùng dữ liệu với tab Cá nhân).
class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.doctor,
    required this.start,
    required this.end,
    required this.patientName,
    required this.patientPhone,
  });

  final Doctor doctor;
  final DateTime start;
  final DateTime end;
  final String patientName;
  final String patientPhone;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              AppStrings.bookConfirmTitle,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _ConfirmRow(
              name: 'doctor',
              label: AppStrings.fieldDoctor,
              value: doctor.name,
            ),
            _ConfirmRow(
              name: 'service',
              label: AppStrings.fieldService,
              value: doctor.serviceName,
            ),
            _ConfirmRow(
              name: 'date',
              label: AppStrings.fieldDate,
              value: AppDateUtils.weekdayDate(start),
            ),
            _ConfirmRow(
              name: 'time',
              label: AppStrings.fieldTime,
              value: AppDateUtils.timeRange(start, end),
            ),
            if (doctor.room.isNotEmpty)
              _ConfirmRow(
                name: 'room',
                label: AppStrings.fieldRoom,
                value: doctor.room,
              ),
            if (doctor.fee > 0)
              _ConfirmRow(
                name: 'fee',
                label: AppStrings.feeLabel,
                value: TextUtils.money(doctor.fee),
              ),
            _ConfirmRow(
              name: 'patient',
              label: AppStrings.fieldPatient,
              value: '$patientName\n$patientPhone',
              isLast: true,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: AppColors.primaryDark,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppStrings.bookConfirmNote,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              key: const ValueKey('book_confirm'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(AppStrings.bookConfirmAction),
            ),
            const SizedBox(height: 6),
            TextButton(
              key: const ValueKey('book_cancel'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(AppStrings.cancel),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  const _ConfirmRow({
    required this.name,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String name;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              key: ValueKey('confirm_$name'),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
