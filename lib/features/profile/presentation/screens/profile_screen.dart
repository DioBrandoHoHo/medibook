import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/shells/customer_nav_controller.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../appointments/presentation/controllers/appointments_controller.dart';
import '../../../booking/presentation/widgets/doctor_card.dart';
import '../../../home/domain/customer_home_summary.dart';
import 'staff_account_screen.dart';

/// Tab "Cá nhân" của Customer (thong_tin.txt phần 2).
///
/// Dùng lại đúng bố cục [AccountView] của Staff: thông tin đọc từ `AuthController.currentUser`
/// (document `users/{uid}` tạo lúc đăng ký), nên họ tên / số điện thoại ở đây, ở lời chào
/// Trang chủ và ở bảng xác nhận đặt lịch luôn là một. Khác Staff: nhãn "Khách hàng" và
/// thêm thẻ "Lịch hẹn của tôi".
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) => const AccountView(
        title: AppStrings.personalTitle,
        roleLabel: AppStrings.roleCustomer,
        extra: _MyAppointmentsCard(),
      );
}

/// Số lịch hẹn sắp tới của khách – tính bằng [CustomerHomeSummary], cùng hàm với Trang chủ,
/// nên hai nơi luôn hiện cùng con số. Bấm vào để sang tab Lịch hẹn.
class _MyAppointmentsCard extends StatelessWidget {
  const _MyAppointmentsCard();

  @override
  Widget build(BuildContext context) {
    final appointments = context.watch<AppointmentsController>();
    final summary = CustomerHomeSummary.from(appointments.items, appointments.now);
    return SectionCard(
      key: const ValueKey('my_appointments_card'),
      onTap: context.read<CustomerNavController>().openAppointments,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.event_note_rounded, color: AppColors.primary, size: 22),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppStrings.myAppointments,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _Number(
                  name: 'upcoming',
                  value: summary.upcomingTotal,
                  label: AppStrings.cStatUpcoming,
                  color: AppColors.primary,
                ),
                _Number(
                  name: 'pending',
                  value: summary.upcomingPending,
                  label: AppStrings.cStatPending,
                  color: AppColors.warningDark,
                ),
                _Number(
                  name: 'confirmed',
                  value: summary.upcomingConfirmed,
                  label: AppStrings.cStatConfirmed,
                  color: AppColors.success,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Number extends StatelessWidget {
  const _Number({
    required this.name,
    required this.value,
    required this.label,
    required this.color,
  });

  final String name;
  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            key: ValueKey('pstat_$name'),
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color, height: 1.1),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
