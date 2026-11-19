import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../app/shells/staff_nav_controller.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../appointments/domain/booking_filter.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../../appointments/domain/entities/appointment_status.dart';
import '../../../appointments/presentation/controllers/appointments_controller.dart';
import '../../../appointments/presentation/widgets/appointment_actions.dart';
import '../../../appointments/presentation/widgets/appointment_tile.dart';
import '../../../appointments/presentation/widgets/status_chip.dart';
import '../widgets/status_filter_sheet.dart';

/// Màn Lịch đặt của Staff.
class StaffBookingsScreen extends StatefulWidget {
  const StaffBookingsScreen({super.key});

  @override
  State<StaffBookingsScreen> createState() => _StaffBookingsScreenState();
}

class _StaffBookingsScreenState extends State<StaffBookingsScreen> {
  static const _filterLabels = {
    BookingFilter.all: AppStrings.filterAll,
    BookingFilter.today: AppStrings.filterToday,
    BookingFilter.pending: AppStrings.statusPending,
  };

  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  late final StaffNavController _nav;
  bool _searchOpen = false;

  /// Cuộn của danh sách.
  final _listScroll = ScrollController();
  final _allScroll = ScrollController();

  /// Đã cuộn xa khỏi mốc hôm nay ở "Tất cả".
  bool _farFromToday = false;
  late int _lastOpenRequest;

  @override
  void initState() {
    super.initState();
    _nav = context.read<StaffNavController>()..addListener(_onNavChanged);
    _lastOpenRequest = _nav.openRequest;
  }

  void _onNavChanged() {
    if (_nav.query.isEmpty && _search.text.isNotEmpty) {
      _search.clear();
      setState(() => _searchOpen = false);
    }
    if (_nav.openRequest != _lastOpenRequest) {
      _lastOpenRequest = _nav.openRequest;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToStart(animate: false));
    }
  }

  void _scrollToStart({bool animate = true}) {
    for (final c in [_listScroll, _allScroll]) {
      if (!c.hasClients) continue;
      animate
          ? c.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOut)
          : c.jumpTo(0);
    }
    if (_farFromToday) setState(() => _farFromToday = false);
  }

  bool _onAllScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    final far = n.metrics.pixels.abs() > 600;
    if (far != _farFromToday) setState(() => _farFromToday = far);
    return false;
  }

  /// Kéo xuống để làm mới.
  Future<void> _refresh() async {
    context.read<AppointmentsController>().refreshClock();
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  @override
  void dispose() {
    _nav.removeListener(_onNavChanged);
    _listScroll.dispose();
    _allScroll.dispose();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() => _searchOpen = !_searchOpen);
    if (_searchOpen) {
      _searchFocus.requestFocus();
    } else {
      _search.clear();
      _nav.setQuery('');
      _searchFocus.unfocus();
    }
  }

  Future<void> _openStatusFilter() async {
    final appointments = context.read<AppointmentsController>();
    final base = _nav.filter == BookingFilter.pending ? BookingFilter.all : _nav.filter;
    final counts = countByStatus(
      applyBookingFilter(appointments.items, base, appointments.now, query: _nav.query),
    );
    final picked = await StatusFilterSheet.show(context, _nav.statuses, counts: counts);
    if (picked != null) _nav.setStatuses(picked);
  }

  void _clearExtraFilters() {
    _nav.setStatuses(const {});
    _nav.setQuery('');
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<StaffNavController>();
    final appointments = context.watch<AppointmentsController>();
    final ready = appointments.status == LoadStatus.ready;

    final showTodayButton = _farFromToday && _isAnchoredAll(appointments, nav);
    return Scaffold(
      backgroundColor: AppColors.surface,
      floatingActionButton: showTodayButton
          ? FloatingActionButton.extended(
              key: const ValueKey('back_to_today'),
              onPressed: _scrollToStart,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.today_rounded),
              label: const Text(AppStrings.backToToday),
            )
          : null,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(nav),
              if (_searchOpen) _buildSearchField(),
              _buildFilterBar(nav, appointments, ready),
              if (nav.statuses.isNotEmpty) _buildActiveStatuses(nav),
              Expanded(child: _buildList(appointments, nav)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(StaffNavController nav) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 8, 2),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              AppStrings.tabStaffBookings,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('search_button'),
            tooltip: _searchOpen ? AppStrings.closeSearch : AppStrings.search,
            onPressed: _toggleSearch,
            icon: Icon(
              _searchOpen ? Icons.search_off_rounded : Icons.search_rounded,
              color: _searchOpen ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
          IconButton(
            key: const ValueKey('status_filter_button'),
            tooltip: AppStrings.statusFilter,
            onPressed: _openStatusFilter,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.filter_alt_outlined,
                  color: nav.statuses.isEmpty ? AppColors.textPrimary : AppColors.primary,
                ),
                if (nav.statuses.isNotEmpty)
                  Positioned(
                    right: -1,
                    top: -1,
                    child: Container(
                      key: const ValueKey('status_filter_dot'),
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surface, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: TextField(
        key: const ValueKey('search_field'),
        controller: _search,
        focusNode: _searchFocus,
        textInputAction: TextInputAction.search,
        onChanged: (value) {
          _nav.setQuery(value);
          setState(() {});
        },
        decoration: InputDecoration(
          hintText: AppStrings.searchHint,
          hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          isDense: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(
                  tooltip: AppStrings.clearText,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    _search.clear();
                    _nav.setQuery('');
                    setState(() {});
                  },
                ),
          enabledBorder: border(AppColors.border),
          focusedBorder: border(AppColors.primary),
        ),
      ),
    );
  }

  /// Ba bộ lọc chính, kèm số lịch của từng bộ lọc.
  Widget _buildFilterBar(StaffNavController nav, AppointmentsController appointments, bool ready) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 10),
      child: Row(
        children: [
          for (final entry in _filterLabels.entries)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _FilterPill(
                filter: entry.key,
                label: entry.value,
                selected: nav.filter == entry.key,
                count: ready
                    ? applyBookingFilter(appointments.items, entry.key, appointments.now).length
                    : null,
                onSelected: () => nav.setFilter(entry.key),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveStatuses(StaffNavController nav) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final status in AppointmentStatus.values)
            if (nav.statuses.contains(status))
              InputChip(
                key: ValueKey('active_status_${status.name}'),
                label: Text(StatusStyle.labelOf(status)),
                labelStyle: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: StatusStyle.colorsOf(status).$2,
                ),
                backgroundColor: StatusStyle.colorsOf(status).$1,
                deleteIcon: const Icon(Icons.close_rounded, size: 16),
                deleteIconColor: StatusStyle.colorsOf(status).$2,
                side: BorderSide.none,
                shape: const StadiumBorder(),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onDeleted: () => nav.setStatuses({...nav.statuses}..remove(status)),
              ),
        ],
      ),
    );
  }

  Widget _buildList(AppointmentsController appointments, StaffNavController nav) {
    switch (appointments.status) {
      case LoadStatus.loading:
        return const LoadingView();
      case LoadStatus.error:
        return SingleChildScrollView(
          child: ErrorRetryView(
            message: appointments.errorMessage ?? AppStrings.errUnknown,
            onRetry: appointments.retry,
          ),
        );
      case LoadStatus.ready:
        final now = appointments.now;
        final items = applyBookingFilter(
          appointments.items,
          nav.filter,
          now,
          statuses: nav.statuses,
          query: nav.query,
        );
        if (items.isEmpty) return _buildEmpty(nav);

        final groups = groupBookingsByDay(items);
        final split = _todaySplit(groups, nav, now);
        final dayCounts = {for (final g in groups) g.day: g.items.length};

        List<Object> rowsOf(Iterable<BookingDayGroup> gs) => [
          for (final g in gs) ...[g.day, ...g.items],
        ];
        Widget buildRow(Object row) {
          if (row is DateTime) return _DayHeader(day: row, now: now, count: dayCounts[row]!);
          final appointment = row as Appointment;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _BookingCard(
              key: ValueKey('card_${appointment.id}'),
              appointment: appointment,
              now: now,
            ),
          );
        }

        final countRow = Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 2),
          child: Text(
            AppStrings.bookingCount(items.length),
            key: const ValueKey('booking_count'),
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        );

        if (split <= 0) {
          final rows = rowsOf(groups);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              countRow,
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _refresh,
                  child: ListView.builder(
                    key: const ValueKey('bookings_list'),
                    controller: _listScroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                    itemCount: rows.length,
                    itemBuilder: (context, i) => buildRow(rows[i]),
                  ),
                ),
              ),
            ],
          );
        }

        final pastRows = rowsOf(groups.take(split)).reversed.toList();
        final pastCount = groups.take(split).fold<int>(0, (n, g) => n + g.items.length);
        final futureRows = rowsOf(groups.skip(split));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            countRow,
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: _onAllScroll,
                child: CustomScrollView(
                  key: const ValueKey('bookings_list'),
                  controller: _allScroll,
                  center: const ValueKey('bookings_from_today'),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList.builder(
                        itemCount: pastRows.length,
                        itemBuilder: (context, i) => buildRow(pastRows[i]),
                      ),
                    ),
                    SliverPadding(
                      key: const ValueKey('bookings_from_today'),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                      sliver: SliverList.builder(
                        itemCount: futureRows.length + 1,
                        itemBuilder: (context, i) =>
                            i == 0 ? _EarlierHint(count: pastCount) : buildRow(futureRows[i - 1]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
    }
  }

  /// Danh sách "Tất cả".
  static int _todaySplit(List<BookingDayGroup> groups, StaffNavController nav, DateTime now) {
    if (nav.filter != BookingFilter.all || nav.query.trim().isNotEmpty) return -1;
    return groups.indexWhere((g) => !g.day.isBefore(AppDateUtils.dayOnly(now)));
  }

  bool _isAnchoredAll(AppointmentsController appointments, StaffNavController nav) {
    if (appointments.status != LoadStatus.ready) return false;
    final items = applyBookingFilter(
      appointments.items,
      nav.filter,
      appointments.now,
      statuses: nav.statuses,
      query: nav.query,
    );
    return _todaySplit(groupBookingsByDay(items), nav, appointments.now) > 0;
  }

  Widget _buildEmpty(StaffNavController nav) {
    final hasExtra = nav.statuses.isNotEmpty || nav.query.trim().isNotEmpty;
    final message = hasExtra
        ? AppStrings.bookingsEmptyFiltered
        : switch (nav.filter) {
            BookingFilter.all => AppStrings.bookingsEmptyAll,
            BookingFilter.today => AppStrings.bookingsEmptyToday,
            BookingFilter.pending => AppStrings.bookingsEmptyPending,
          };
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EmptyView(
              message: message,
              icon: hasExtra ? Icons.search_off_rounded : Icons.event_busy_rounded,
            ),
            if (hasExtra)
              TextButton(
                key: const ValueKey('clear_filters'),
                onPressed: _clearExtraFilters,
                child: const Text(AppStrings.clearFilters),
              ),
          ],
        ),
      ),
    );
  }
}

/// Nút lọc dạng viên thuốc.
class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.filter,
    required this.label,
    required this.selected,
    required this.count,
    required this.onSelected,
  });

  final BookingFilter filter;
  final String label;
  final bool selected;
  final int? count;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppColors.textPrimary;
    return ChoiceChip(
      key: ValueKey('filter_${filter.name}'),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      selectedColor: AppColors.primary,
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: foreground),
          ),
          if (count != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected ? Colors.white.withValues(alpha: 0.22) : AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                key: ValueKey('filter_count_${filter.name}'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Dòng nhỏ ở đầu phần "từ hôm nay" của bộ lọc Tất cả.
class _EarlierHint extends StatelessWidget {
  const _EarlierHint({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('earlier_hint'),
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.keyboard_double_arrow_up_rounded,
            size: 16,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              AppStrings.earlierBookings(count),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.now, required this.count});

  final DateTime day;
  final DateTime now;

  /// Số lịch của ngày này trong danh sách đang hiện.
  final int count;

  @override
  Widget build(BuildContext context) {
    final isToday = AppDateUtils.isSameDay(day, now);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_rounded,
            size: 14,
            color: isToday ? AppColors.primary : AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              AppDateUtils.dayLabel(day, now),
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: isToday ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            AppStrings.dayCount(count),
            key: ValueKey('day_count_${AppDateUtils.isoDate(day)}'),
            style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Thẻ lịch hẹn ở màn Lịch đặt.
class _BookingCard extends StatefulWidget {
  const _BookingCard({super.key, required this.appointment, required this.now});

  final Appointment appointment;
  final DateTime now;

  @override
  State<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<_BookingCard> {
  bool _busy = false;

  Future<void> _handle({required bool confirm}) async {
    setState(() => _busy = true);
    await runAppointmentAction(context, widget.appointment, confirm: confirm);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.appointment;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.cardShadow,
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: AppointmentTile(
          appointment: a,
          showCode: true,
          now: widget.now,
          showDoctor: true,
          showDate: false,
          footer: !a.isPending
              ? null
              : Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _PillButton(
                      key: ValueKey('quick_confirm_${a.id}'),
                      label: AppStrings.confirmAppointment,
                      icon: Icons.check_rounded,
                      background: AppColors.primaryLight,
                      foreground: AppColors.primary,
                      onTap: _busy ? null : () => _handle(confirm: true),
                    ),
                    const SizedBox(width: 8),
                    _PillButton(
                      key: ValueKey('quick_reject_${a.id}'),
                      label: AppStrings.rejectAppointment,
                      icon: Icons.close_rounded,
                      background: AppColors.errorLight,
                      foreground: AppColors.error,
                      onTap: _busy ? null : () => _handle(confirm: false),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
    required this.icon,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: foreground),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: foreground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
