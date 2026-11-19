import 'package:flutter/material.dart';

/// Bảng màu MediBook.
abstract final class AppColors {
  static const primary = Color(0xFF1E6FEB);
  static const primaryBright = Color(0xFF4F8DFF);
  static const primaryDark = Color(0xFF1452C4);
  static const primaryLight = Color(0xFFE8F0FE);
  static const background = Colors.white;
  static const surface = Color(0xFFF5F7FB);
  static const border = Color(0xFFE3E8F0);
  static const textPrimary = Color(0xFF1A1D26);
  static const textSecondary = Color(0xFF6B7280);
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFDC2626);
  static const errorLight = Color(0xFFFEECEC);
  static const successLight = Color(0xFFE5F6EC);
  static const warningLight = Color(0xFFFEF3DC);
  static const warningDark = Color(0xFFB45309);

  // Trạng thái lịch hẹn
  static const rejected = Color(0xFFC81E1E);
  static const rejectedLight = Color(0xFFFDDCDC);
  static const cancelled = Color(0xFFE5606A);
  static const cancelledLight = Color(0xFFFFF0F1);

  /// Bóng đổ nhẹ dùng chung cho các thẻ trắng của khu vực Staff.
  static const cardShadow = [
    BoxShadow(color: Color(0x0F1E3A8A), blurRadius: 14, offset: Offset(0, 4)),
  ];

  static const welcomeDark = Color(0xFF1C1F26);
  static const welcomeMuted = Color(0xFF8A8F9C);
}
