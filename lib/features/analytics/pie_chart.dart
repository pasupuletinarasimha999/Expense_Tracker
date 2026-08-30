import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models.dart';

/// Animated donut chart. Ported 1:1 from `PieChartView.kt`.
class AnimatedPieChart extends StatefulWidget {
  final List<CategorySummary> data;
  final String centerAmountFormatted;
  final String centerTitle;

  const AnimatedPieChart({
    super.key,
    required this.data,
    required this.centerAmountFormatted,
    this.centerTitle = 'Total Expenses',
  });

  @override
  State<AnimatedPieChart> createState() => _AnimatedPieChartState();
}

class _AnimatedPieChartState extends State<AnimatedPieChart> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _animation = CurvedAnimation(parent: _controller, curve: Curves.decelerate);
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedPieChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data ||
        oldWidget.centerAmountFormatted != widget.centerAmountFormatted ||
        oldWidget.centerTitle != widget.centerTitle) {
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          painter: _PieChartPainter(
            data: widget.data,
            centerTitle: widget.centerTitle,
            centerAmountFormatted: widget.centerAmountFormatted,
            animationProgress: _animation.value,
          ),
          size: const Size.square(200),
        );
      },
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final List<CategorySummary> data;
  final String centerTitle;
  final String centerAmountFormatted;
  final double animationProgress;

  static const _strokeWidthRatio = 0.24;

  _PieChartPainter({
    required this.data,
    required this.centerTitle,
    required this.centerAmountFormatted,
    required this.animationProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final strokeWidth = side * _strokeWidthRatio;
    final padding = strokeWidth / 2 + 6;
    final rect = Rect.fromLTWH(
      (size.width - side) / 2 + padding,
      (size.height - side) / 2 + padding,
      side - padding * 2,
      side - padding * 2,
    );

    final slicePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    if (data.isEmpty) {
      slicePaint.color = const Color(0xFFE2E8F0);
      canvas.drawArc(rect, 0, 2 * 3.141592653589793, false, slicePaint);
      _drawCenterText(canvas, rect);
      return;
    }

    const degToRad = 3.141592653589793 / 180;
    var startAngleDeg = -90.0;
    final maxSweep = 360.0 * animationProgress;

    for (final item in data) {
      final sweep = (item.percentage / 100) * 360.0;
      final animatedSweep = sweep < (maxSweep - (startAngleDeg - -90.0))
          ? sweep
          : (maxSweep - (startAngleDeg - -90.0));

      if (animatedSweep > 0) {
        slicePaint.color = AppColors.fromHex(item.colorHex);
        final gap = data.length > 1 ? 2.5 : 0.0;
        final drawSweep = (animatedSweep - gap).clamp(0.1, 360.0);
        canvas.drawArc(
          rect,
          (startAngleDeg + gap / 2) * degToRad,
          drawSweep * degToRad,
          false,
          slicePaint,
        );
      }

      startAngleDeg += sweep;
      if (startAngleDeg - -90.0 >= maxSweep) break;
    }

    _drawCenterText(canvas, rect);
  }

  void _drawCenterText(Canvas canvas, Rect rect) {
    final center = rect.center;

    final titlePainter = TextPainter(
      text: TextSpan(
        text: centerTitle,
        style: const TextStyle(color: Color(0xFF64748B), fontSize: 15),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: rect.width);
    titlePainter.paint(canvas, Offset(center.dx - titlePainter.width / 2, center.dy - 24));

    final amountPainter = TextPainter(
      text: TextSpan(
        text: centerAmountFormatted,
        style: const TextStyle(color: Color(0xFF0F172A), fontSize: 19, fontWeight: FontWeight.bold),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: rect.width);
    amountPainter.paint(canvas, Offset(center.dx - amountPainter.width / 2, center.dy + 6));
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
        oldDelegate.data != data ||
        oldDelegate.centerAmountFormatted != centerAmountFormatted;
  }
}
