import 'package:flutter/material.dart';

/// Các đường cong mảnh trên nền tối của màn Welcome.
class WelcomeBackgroundPainter extends CustomPainter {
  const WelcomeBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.05);
    final center = Offset(size.width * 1.1, size.height * 0.62);
    for (var r = 80.0; r < size.width * 1.6; r += 26) {
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
