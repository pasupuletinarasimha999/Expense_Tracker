import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Horizontal scrolling month strip spanning 5 years back to 5 years forward from now
/// (121 months), snapping the selected chip toward center. Ported from `MonthSelectorView.kt`.
class MonthSelector extends StatefulWidget {
  final DateTime selectedMonth;
  final ValueChanged<DateTime> onMonthSelected;

  const MonthSelector({super.key, required this.selectedMonth, required this.onMonthSelected});

  @override
  State<MonthSelector> createState() => _MonthSelectorState();
}

class _MonthSelectorState extends State<MonthSelector> {
  static const _itemWidth = 84.0;
  static const _monthsBack = 60;
  static const _monthsForward = 60;

  late final DateTime _baseMonth;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _baseMonth = DateTime(now.year, now.month);
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected(animate: false));
  }

  @override
  void didUpdateWidget(covariant MonthSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedMonth != widget.selectedMonth) {
      _scrollToSelected(animate: true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int _indexFor(DateTime month) {
    return (month.year - _baseMonth.year) * 12 + (month.month - _baseMonth.month) + _monthsBack;
  }

  void _scrollToSelected({required bool animate}) {
    if (!_scrollController.hasClients) return;
    final index = _indexFor(widget.selectedMonth);
    final viewportWidth = _scrollController.position.viewportDimension;
    final targetOffset = (index * _itemWidth) - (viewportWidth / 2) + (_itemWidth / 2);
    final clamped = targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent);
    if (animate) {
      _scrollController.animateTo(clamped, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else {
      _scrollController.jumpTo(clamped);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalMonths = _monthsBack + _monthsForward + 1;
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 56,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: totalMonths,
        itemBuilder: (context, index) {
          final month = DateTime(_baseMonth.year, _baseMonth.month - _monthsBack + index);
          final isSelected = month.year == widget.selectedMonth.year && month.month == widget.selectedMonth.month;

          return SizedBox(
            width: _itemWidth,
            child: Center(
              child: GestureDetector(
                onTap: () => widget.onMonthSelected(month),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? colorScheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    DateFormat('MMM yyyy').format(month),
                    style: TextStyle(
                      color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
