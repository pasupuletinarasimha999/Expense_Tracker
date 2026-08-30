import 'package:flutter/material.dart';

import '../../data/models.dart';

/// Animated grouped income/expense bar chart. Ported 1:1 from `BarChartView.kt`.
class AnimatedBarChart extends StatefulWidget {
  final List<MonthlyTrend> trends;

  const AnimatedBarChart({super.key, required this.trends});

  @override
  State<AnimatedBarChart> createState() => _AnimatedBarChartState();
}

class _AnimatedBarChartState extends State<AnimatedBarChart> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 750));
    _animation = CurvedAnimation(parent: _controller, curve: Curves.decelerate);
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trends != widget.trends) {
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
          painter: _BarChartPainter(trends: widget.trends, animationProgress: _animation.value),
          size: const Size(double.infinity, 200),
        );
      },
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<MonthlyTrend> trends;
  final double animationProgress;

  _BarChartPainter({required this.trends, required this.animationProgress});

  @override
  void paint(Canvas canvas, Size size) {
    if (trends.isEmpty) return;

    final maxVal = trends.fold<double>(
      0,
      (max, t) => [max, t.totalIncome, t.totalExpense].reduce((a, b) => a > b ? a : b),
    );
    final maxScaleValue = maxVal > 0 ? maxVal * 1.15 : 1000.0;

    final incomePaint = Paint()..color = const Color(0xFF10B981);
    final expensePaint = Paint()..color = const Color(0xFFF43F5E);
    final gridLinePaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1.5;
    final labelStyle = const TextStyle(color: Color(0xFF64748B), fontSize: 11);

    const bottomMargin = 30.0;
    const topMargin = 12.0;
    final chartHeight = size.height - bottomMargin - topMargin;

    canvas.drawLine(Offset(0, size.height - bottomMargin), Offset(size.width, size.height - bottomMargin), gridLinePaint);
    final midY = size.height - bottomMargin - (chartHeight / 2);
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), gridLinePaint);

    final groupCount = trends.length;
    final groupWidth = size.width / groupCount;
    final barWidth = (groupWidth * 0.32).clamp(0.0, 28.0);
    const barSpacing = 4.0;
    const cornerRadius = Radius.circular(6);

    for (var i = 0; i < trends.length; i++) {
      final item = trends[i];
      final groupCenterX = (i * groupWidth) + (groupWidth / 2);
      final baseBottom = size.height - bottomMargin;

      final labelPainter = TextPainter(
        text: TextSpan(text: item.monthLabel, style: labelStyle),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainter.paint(canvas, Offset(groupCenterX - labelPainter.width / 2, size.height - 16));

      final incomeRatio = (item.totalIncome / maxScaleValue).clamp(0.0, 1.0);
      final incomeHeight = chartHeight * incomeRatio * animationProgress;
      if (incomeHeight > 0) {
        final incomeRect = Rect.fromLTRB(
          groupCenterX - barWidth - barSpacing / 2,
          baseBottom - incomeHeight,
          groupCenterX - barSpacing / 2,
          baseBottom,
        );
        canvas.drawRRect(RRect.fromRectAndCorners(incomeRect, topLeft: cornerRadius, topRight: cornerRadius), incomePaint);
      }

      final expenseRatio = (item.totalExpense / maxScaleValue).clamp(0.0, 1.0);
      final expenseHeight = chartHeight * expenseRatio * animationProgress;
      if (expenseHeight > 0) {
        final expenseRect = Rect.fromLTRB(
          groupCenterX + barSpacing / 2,
          baseBottom - expenseHeight,
          groupCenterX + barWidth + barSpacing / 2,
          baseBottom,
        );
        canvas.drawRRect(RRect.fromRectAndCorners(expenseRect, topLeft: cornerRadius, topRight: cornerRadius), expensePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress || oldDelegate.trends != trends;
  }
}
