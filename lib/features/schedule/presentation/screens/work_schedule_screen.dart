import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../core/widgets/day_strip.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../../appointments/presentation/controllers/appointments_controller.dart';
import '../../../booking/domain/availability.dart' show specialtiesOf;
import '../../../booking/domain/entities/doctor.dart';
import '../../../booking/presentation/controllers/doctors_controller.dart';
import '../../domain/schedule_builder.dart';
import '../../domain/work_shift.dart';
import '../widgets/doctor_schedule_card.dart';
import '../widgets/slot_style.dart';

/// Tab "Lịch làm việc" của Staff (lich_lam_viec.txt): mỗi bác sĩ một thẻ, chọn buổi
/// Sáng / Chiều để xem 8 khung 30 phút còn trống hay đã có khách.
///
/// Màn này KHÔNG giữ lịch hẹn riêng: trạng thái từng khung được tính bằng [buildSlots]
/// từ `AppointmentsController.items` – cùng danh sách với Tổng quan và Lịch đặt –
/// nên xác nhận / từ chối ở tab khác thì khung ở đây đổi theo.
class WorkScheduleScreen extends StatefulWidget {
  const WorkScheduleScreen({super.key});

  /// Số ngày hiển thị trên dải chọn ngày, tính từ hôm nay.
  static const dayCount = 14;

  @override
  State<WorkScheduleScreen> createState() => _WorkScheduleScreenState();
}

class _WorkScheduleScreenState extends State<WorkScheduleScreen> {
  /// Ngày đang xem (00:00). `null` = hôm nay.
  DateTime? _selectedDay;

  /// Buổi đang xem của từng bác sĩ; chưa chọn thì dùng buổi mặc định.
  final Map<String, WorkShift> _shiftByDoctor = {};

  bool _onlyFree = false;

  /// Tìm kiếm + lọc chuyên khoa (nhiều bác sĩ, khó xem hết một lượt).
  final _search = TextEditingController();
  String _query = '';
  String? _specialty;

  bool get _hasFilters => _query.isNotEmpty || _specialty != null || _onlyFree;

  void _clearFilters() => setState(() {
        _search.clear();
        _query = '';
        _specialty = null;
        _onlyFree = false;
      });

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _selectDay(DateTime day) {
    setState(() {
      _selectedDay = day;
      _shiftByDoctor.clear(); // sang ngày khác -> về buổi mặc định của ngày đó
    });
  }

  @override
  Widget build(BuildContext context) {
    final appointments = context.watch<AppointmentsController>();
    final doctors = context.watch<DoctorsController>();
    final now = appointments.now;
    final today = AppDateUtils.dayOnly(now);
    // Ngày đã chọn bị trôi về quá khứ (app mở qua đêm) -> quay về hôm nay.
    final selected =
        _selectedDay == null || _selectedDay!.isBefore(today) ? today : _selectedDay!;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 10, 20, 8),
                child: Text(
                  AppStrings.tabSchedule,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              DayStrip(
                today: today,
                selected: selected,
                dayCount: WorkScheduleScreen.dayCount,
                onSelect: _selectDay,
              ),
              Expanded(child: _buildBody(appointments, doctors, selected, now)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    AppointmentsController appointments,
    DoctorsController doctors,
    DateTime day,
    DateTime now,
  ) {
    if (appointments.status == LoadStatus.error || doctors.status == LoadStatus.error) {
      return SingleChildScrollView(
        child: ErrorRetryView(
          message: doctors.errorMessage ?? appointments.errorMessage ?? AppStrings.errUnknown,
          onRetry: () {
            if (doctors.status == LoadStatus.error) doctors.retry();
            if (appointments.status == LoadStatus.error) appointments.retry();
          },
        ),
      );
    }
    if (appointments.status == LoadStatus.loading || doctors.status == LoadStatus.loading) {
      return const LoadingView();
    }
    if (doctors.items.isEmpty) {
      return const Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EmptyView(message: AppStrings.doctorsEmpty, icon: Icons.person_off_outlined),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  AppStrings.doctorsEmptyHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final items = appointments.items;
    final matched = filterScheduleDoctors(doctors.items, query: _query, specialty: _specialty);
    // Thẻ tổng hợp tính theo các bác sĩ đang lọc -> con số khớp với danh sách bên dưới.
    final summary = summarizeDay(doctors: matched, day: day, appointments: items, now: now);
    final visible = _onlyFree
        ? matched.where((d) => _freeInDay(d, day, items, now) > 0).toList()
        : matched;
    final specialties = specialtiesOf(doctors.items);

    return ListView(
      key: const ValueKey('schedule_list'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        TextField(
          key: const ValueKey('schedule_search'),
          controller: _search,
          onChanged: (value) => setState(() => _query = value),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: AppStrings.scheduleSearchHint,
            prefixIcon: const Icon(Icons.search_rounded),
            fillColor: Colors.white,
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    key: const ValueKey('schedule_search_clear'),
                    tooltip: AppStrings.clearText,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() {
                      _search.clear();
                      _query = '';
                    }),
                  ),
          ),
        ),
        if (specialties.length > 1) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: ListView(
              key: const ValueKey('schedule_specialties'),
              scrollDirection: Axis.horizontal,
              children: [
                _SpecialtyChip(
                  name: 'sched_spec_all',
                  label: AppStrings.allSpecialties,
                  count: doctors.items.length,
                  selected: _specialty == null,
                  onTap: () => setState(() => _specialty = null),
                ),
                for (final s in specialties)
                  _SpecialtyChip(
                    name: 'sched_spec_$s',
                    label: s,
                    count: doctors.items.where((d) => d.specialty == s).length,
                    selected: _specialty == s,
                    onTap: () => setState(() => _specialty = _specialty == s ? null : s),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        _DaySummaryCard(day: day, now: now, summary: summary),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                AppStrings.doctorCount(visible.length),
                key: const ValueKey('doctor_count'),
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
            FilterChip(
              key: const ValueKey('only_free'),
              label: const Text(AppStrings.onlyFreeDoctors),
              selected: _onlyFree,
              showCheckmark: true,
              checkmarkColor: AppColors.primary,
              selectedColor: AppColors.primaryLight,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _onlyFree ? AppColors.primary : AppColors.textPrimary,
              ),
              side: BorderSide(color: _onlyFree ? AppColors.primary : AppColors.border),
              shape: const StadiumBorder(),
              visualDensity: VisualDensity.compact,
              onSelected: (on) => setState(() => _onlyFree = on),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const _Legend(),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Column(
              children: [
                // Không còn ai sau khi tìm / chọn khoa -> "không có bác sĩ phù hợp";
                // chỉ do bật "còn trống" -> như trước.
                matched.isEmpty
                    ? const EmptyView(message: AppStrings.noDoctorMatch, icon: Icons.search_off_rounded)
                    : const EmptyView(message: AppStrings.noFreeDoctors, icon: Icons.event_busy_rounded),
                if (_hasFilters)
                  TextButton(
                    key: const ValueKey('schedule_clear_filters'),
                    onPressed: _clearFilters,
                    child: const Text(AppStrings.clearDoctorFilters),
                  ),
              ],
            ),
          ),
        for (final doctor in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildDoctorCard(doctor, day, items, now),
          ),
      ],
    );
  }

  Widget _buildDoctorCard(Doctor doctor, DateTime day, List<Appointment> items, DateTime now) {
    final shift = _shiftByDoctor[doctor.id] ?? WorkShift.defaultFor(day, now);
    return DoctorScheduleCard(
      key: ValueKey('doctor_${doctor.id}'),
      doctor: doctor,
      shift: shift,
      slots: buildSlots(
        doctorId: doctor.id,
        day: day,
        shift: shift,
        appointments: items,
        now: now,
      ),
      onShiftChanged: (value) => setState(() => _shiftByDoctor[doctor.id] = value),
    );
  }

  static int _freeInDay(Doctor doctor, DateTime day, List<Appointment> items, DateTime now) =>
      SlotSummary.of(
        buildDaySlots(doctorId: doctor.id, day: day, appointments: items, now: now),
      ).free;
}

/// Nút chọn chuyên khoa (kèm số bác sĩ của khoa).
class _SpecialtyChip extends StatelessWidget {
  const _SpecialtyChip({
    required this.name,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String label;
  final int count;
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
              '$label  $count',
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

/// Thẻ tổng hợp của ngày đang chọn: số khung Trống / Chờ xác nhận / Đã đặt của các bác sĩ
/// đang hiển thị (theo tìm kiếm / chuyên khoa).
class _DaySummaryCard extends StatelessWidget {
  const _DaySummaryCard({required this.day, required this.now, required this.summary});

  final DateTime day;
  final DateTime now;
  final SlotSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryBright, AppColors.primary, AppColors.primaryDark],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_note_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppDateUtils.dayLabel(day, now),
                  key: const ValueKey('schedule_day_label'),
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _SummaryNumber(name: 'free', value: summary.free, label: AppStrings.summaryFree),
              _SummaryNumber(
                name: 'pending',
                value: summary.pending,
                label: AppStrings.summaryPending,
              ),
              _SummaryNumber(name: 'booked', value: summary.booked, label: AppStrings.summaryBooked),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryNumber extends StatelessWidget {
  const _SummaryNumber({required this.name, required this.value, required this.label});

  final String name;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            key: ValueKey('sum_$name'),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.9)),
          ),
        ],
      ),
    );
  }
}

/// Chú thích màu của 4 trạng thái khung giờ.
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: [
        for (final state in SlotStyle.legendOrder)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: SlotStyle.of(state).background,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: SlotStyle.of(state).border),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                SlotStyle.legendLabel(state),
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
      ],
    );
  }
}
