import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../app/shells/customer_nav_controller.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../core/widgets/day_picker.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../appointments/presentation/controllers/appointments_controller.dart';
import '../../../schedule/domain/work_shift.dart';
import '../../domain/availability.dart';
import '../../domain/booking_window.dart';
import '../controllers/busy_slots_controller.dart';
import '../controllers/doctors_controller.dart';
import '../widgets/doctor_card.dart';
import 'doctor_detail_screen.dart';

/// Tab "Đặt lịch" của Customer (dat_lich.txt): chọn thời gian mong muốn + lọc ->
/// danh sách bác sĩ phù hợp -> bấm vào bác sĩ để xem thông tin, lịch trống và đặt.
///
/// Điều kiện lọc nằm ở [CustomerNavController] (trạng thái giao diện). Danh sách hiển thị
/// do hàm thuần Dart [applyDoctorFilter] tính từ `DoctorsController` + `BusySlotsController`
/// – cùng nguồn với Trang chủ và màn Thông tin bác sĩ.
class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _search = TextEditingController();
  CustomerNavController? _nav;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nav = context.read<CustomerNavController>();
    if (!identical(nav, _nav)) {
      _nav?.removeListener(_syncSearch);
      _nav = nav..addListener(_syncSearch);
      _syncSearch();
    }
  }

  /// Từ khoá bị đổi từ nơi khác (VD Trang chủ mở sẵn một chuyên khoa, bấm "Xoá bộ lọc")
  /// -> ô tìm kiếm hiển thị theo.
  void _syncSearch() {
    final query = _nav?.query ?? '';
    if (_search.text != query) _search.text = query;
  }

  @override
  void dispose() {
    _nav?.removeListener(_syncSearch);
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<CustomerNavController>();
    final appointments = context.watch<AppointmentsController>();
    final doctors = context.watch<DoctorsController>();
    final busy = context.watch<BusySlotsController>();
    final now = appointments.now;
    final today = AppDateUtils.dayOnly(now);
    // Ngày đã chọn bị trôi về quá khứ (app mở qua đêm) -> hôm nay; quá xa -> ngày cuối được đặt.
    final day = BookingWindow.clamp(nav.day, now);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: SafeArea(
          bottom: false,
          child: ListView(
            key: const ValueKey('booking_list'),
            padding: const EdgeInsets.only(bottom: 28),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 10, 20, 2),
                child: Text(
                  AppStrings.bookingTitle,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  AppStrings.bookingSubtitle,
                  style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  key: const ValueKey('doctor_search'),
                  controller: _search,
                  onChanged: nav.setQuery,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: AppStrings.doctorSearchHint,
                    prefixIcon: const Icon(Icons.search_rounded),
                    fillColor: Colors.white,
                    suffixIcon: nav.query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: AppStrings.clearText,
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => nav.setQuery(''),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        AppStrings.wantedTime,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      AppDateUtils.dayLabel(day, now),
                      key: const ValueKey('booking_day_label'),
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              DayPicker(
                today: today,
                selected: day,
                lastDay: BookingWindow.lastDay(now),
                isEnabled: (d) => dayHasFutureSlot(d, now),
                disabledLabel: AppStrings.fullDay,
                note: _rangeNote(now),
                onSelect: (d) => _selectDay(context, nav, d, now),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _TimeFilterButton(
                  slotMinutes: nav.slotMinutes,
                  onTap: () => _pickTime(context, nav, day, now),
                  onClear: () => nav.setSlotMinutes(null),
                ),
              ),
              const SizedBox(height: 14),
              if (doctors.status == LoadStatus.ready) _specialtyChips(nav, doctors),
              ..._results(context, nav, appointments, doctors, busy, day, now),
            ],
          ),
        ),
      ),
    );
  }

  Widget _specialtyChips(CustomerNavController nav, DoctorsController doctors) {
    final names = specialtiesOf(doctors.items);
    if (names.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ListView(
        key: const ValueKey('specialty_chips'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _Choice(
            name: 'spec_all',
            label: AppStrings.allSpecialties,
            selected: nav.specialty == null,
            onTap: () => nav.setSpecialty(null),
          ),
          for (final name in names)
            _Choice(
              name: 'spec_$name',
              label: name,
              selected: nav.specialty == name,
              onTap: () => nav.setSpecialty(nav.specialty == name ? null : name),
            ),
        ],
      ),
    );
  }

  List<Widget> _results(
    BuildContext context,
    CustomerNavController nav,
    AppointmentsController appointments,
    DoctorsController doctors,
    BusySlotsController busy,
    DateTime day,
    DateTime now,
  ) {
    if (doctors.status == LoadStatus.error || busy.status == LoadStatus.error) {
      return [
        ErrorRetryView(
          message: doctors.errorMessage ?? busy.errorMessage ?? AppStrings.errUnknown,
          onRetry: () {
            if (doctors.status == LoadStatus.error) doctors.retry();
            if (busy.status == LoadStatus.error) busy.retry();
          },
        ),
      ];
    }
    if (doctors.status == LoadStatus.loading || busy.status == LoadStatus.loading) {
      return const [LoadingView()];
    }
    if (doctors.items.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 24),
          child: EmptyView(
            message: AppStrings.doctorsEmptyCustomer,
            icon: Icons.person_off_outlined,
          ),
        ),
      ];
    }

    final items = applyDoctorFilter(
      doctors: doctors.items,
      filter: DoctorFilter(
        day: day,
        slotMinutes: nav.slotMinutes,
        query: nav.query,
        specialty: nav.specialty,
        onlyFree: nav.onlyFree,
      ),
      busyIds: busy.ids,
      mine: appointments.items,
      now: now,
    );
    final wanted = nav.slotMinutes == null ? null : slotStartOn(day, nav.slotMinutes!);

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                AppStrings.doctorMatch(items.length),
                key: const ValueKey('doctor_match_count'),
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
            // Đã chọn giờ thì danh sách vốn chỉ còn bác sĩ trống đúng giờ đó.
            if (nav.slotMinutes == null)
              FilterChip(
                key: const ValueKey('only_free_doctors'),
                label: const Text(AppStrings.onlyFreeShort),
                selected: nav.onlyFree,
                showCheckmark: true,
                checkmarkColor: AppColors.primary,
                selectedColor: AppColors.primaryLight,
                backgroundColor: Colors.white,
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: nav.onlyFree ? AppColors.primary : AppColors.textPrimary,
                ),
                side: BorderSide(color: nav.onlyFree ? AppColors.primary : AppColors.border),
                shape: const StadiumBorder(),
                visualDensity: VisualDensity.compact,
                onSelected: nav.setOnlyFree,
              ),
          ],
        ),
      ),
      if (items.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              EmptyView(
                message: wanted != null ? AppStrings.noDoctorAtTime : AppStrings.noDoctorMatch,
                icon: Icons.search_off_rounded,
              ),
              if (wanted != null)
                const Text(
                  AppStrings.noDoctorAtTimeHint,
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              if (nav.hasFilters)
                TextButton(
                  key: const ValueKey('clear_doctor_filters'),
                  onPressed: nav.clearFilters,
                  child: const Text(AppStrings.clearDoctorFilters),
                ),
            ],
          ),
        ),
      for (final item in items)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: DoctorCard(
            item: item,
            wantedStart: wanted,
            onTap: () => DoctorDetailScreen.open(
              context,
              doctorId: item.doctor.id,
              day: day,
              slotMinutes: nav.slotMinutes,
            ),
          ),
        ),
    ];
  }

  /// Đổi ngày khám mong muốn. Khung giờ mong muốn đang chọn mà đã qua ở ngày mới
  /// (VD chọn 08:00 ngày mai rồi quay về hôm nay lúc 10:00) -> bỏ chọn giờ và báo cho khách,
  /// để danh sách không lọc theo một khung không thể đặt.
  void _selectDay(BuildContext context, CustomerNavController nav, DateTime day, DateTime now) {
    final target = BookingWindow.clamp(day, now);
    final slot = nav.slotMinutes;
    nav.setDay(target);
    if (!wantedSlotStillValid(target, slot, now)) {
      nav.setSlotMinutes(null);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(AppStrings.timeCleared(_minutesLabel(slot!)))),
        );
    }
  }

  static String _rangeNote(DateTime now) => AppStrings.bookingRange(
        AppDateUtils.date(BookingWindow.firstDay(now)),
        AppDateUtils.date(BookingWindow.lastDay(now)),
      );

  Future<void> _pickTime(
    BuildContext context,
    CustomerNavController nav,
    DateTime day,
    DateTime now,
  ) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _TimeSheet(day: day, now: now, selected: nav.slotMinutes),
    );
    // -1 = "Giờ bất kỳ"; null = đóng bảng mà không chọn.
    if (picked == null) return;
    nav.setSlotMinutes(picked < 0 ? null : picked);
  }
}

String _minutesLabel(int minutes) {
  final start = slotStartOn(DateTime(2000), minutes);
  return AppDateUtils.timeRange(start, start.add(const Duration(minutes: WorkShift.slotMinutes)));
}

/// Nút chọn giờ khám mong muốn.
class _TimeFilterButton extends StatelessWidget {
  const _TimeFilterButton({required this.slotMinutes, required this.onTap, required this.onClear});

  final int? slotMinutes;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final chosen = slotMinutes != null;
    return Material(
      color: chosen ? AppColors.primaryLight : Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('time_filter'),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: chosen ? AppColors.primary : AppColors.border),
          ),
          child: Row(
            children: [
              Icon(Icons.access_time_rounded,
                  size: 20, color: chosen ? AppColors.primary : AppColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  chosen ? _minutesLabel(slotMinutes!) : AppStrings.anyTime,
                  key: const ValueKey('time_filter_label'),
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: chosen ? AppColors.primaryDark : AppColors.textPrimary,
                  ),
                ),
              ),
              if (chosen)
                IconButton(
                  key: const ValueKey('time_filter_clear'),
                  tooltip: AppStrings.clearText,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.primaryDark),
                  onPressed: onClear,
                )
              else
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.expand_more_rounded, color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bảng chọn giờ: mọi khung 30 phút của hai buổi. Khung đã qua (khi xem hôm nay) bị khoá.
class _TimeSheet extends StatelessWidget {
  const _TimeSheet({required this.day, required this.now, required this.selected});

  final DateTime day;
  final DateTime now;
  final int? selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              AppStrings.pickTime,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppDateUtils.dayLabel(day, now),
              key: const ValueKey('time_sheet_day'),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              AppStrings.pickTimeHint,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            _TimeOption(
              name: 'time_any',
              label: AppStrings.anyTime,
              selected: selected == null,
              onTap: () => Navigator.of(context).pop(-1),
            ),
            for (final shift in WorkShift.values) ...[
              const SizedBox(height: 14),
              Text(
                shift == WorkShift.morning ? AppStrings.shiftMorning : AppStrings.shiftAfternoon,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final start in shift.slotStartsOn(day))
                    _TimeOption(
                      name: 'time_opt_${start.hour * 60 + start.minute}',
                      label: AppDateUtils.time(start),
                      selected: selected == start.hour * 60 + start.minute,
                      onTap: start.isAfter(now)
                          ? () => Navigator.of(context).pop(start.hour * 60 + start.minute)
                          : null,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimeOption extends StatelessWidget {
  const _TimeOption({
    required this.name,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final Color foreground = disabled
        ? AppColors.textSecondary
        : selected
            ? Colors.white
            : AppColors.textPrimary;
    return Material(
      color: disabled
          ? AppColors.surface
          : selected
              ? AppColors.primary
              : Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey(name),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 70),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected && !disabled ? AppColors.primary : AppColors.border),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: foreground),
          ),
        ),
      ),
    );
  }
}

/// Nút lựa chọn dạng viên (chuyên khoa).
class _Choice extends StatelessWidget {
  const _Choice({
    required this.name,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey(name),
          onTap: onTap,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? AppColors.primary : AppColors.border),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
