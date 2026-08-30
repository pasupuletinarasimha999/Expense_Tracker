import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_utils.dart';
import '../../data/models.dart';
import '../../widgets/month_selector.dart';
import 'analytics_providers.dart';
import 'bar_chart.dart';
import 'pie_chart.dart';

/// Ported 1:1 from `AnalyticsFragment.kt` + `AnalyticsViewModel.kt`.
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Monthly Breakdown'), Tab(text: 'Fiscal Year Overview')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_MonthlyBreakdownTab(), _FiscalYearTab()],
      ),
    );
  }
}

class _MonthlyBreakdownTab extends ConsumerWidget {
  const _MonthlyBreakdownTab();

  void _shiftMonth(WidgetRef ref, int delta) {
    final current = ref.read(selectedMonthProvider);
    ref.read(selectedMonthProvider.notifier).state = DateTime(current.year, current.month + delta);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(selectedMonthProvider);
    final currencySymbol = ref.watch(currencySymbolProvider);
    final categoryBreakdown = ref.watch(categoryBreakdownProvider).valueOrNull ?? const [];
    final paymentBreakdown = ref.watch(paymentMethodBreakdownProvider).valueOrNull ?? const [];
    final trendsAsync = ref.watch(monthlyTrendsProvider);

    final totalExpense = categoryBreakdown.fold<double>(0, (sum, c) => sum + c.totalAmount);

    return Column(
      children: [
        MonthSelector(
          selectedMonth: selectedMonth,
          onMonthSelected: (month) => ref.read(selectedMonthProvider.notifier).state = month,
        ),
        Expanded(
          child: GestureDetector(
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity > 100) {
                _shiftMonth(ref, -1);
              } else if (velocity < -100) {
                _shiftMonth(ref, 1);
              }
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Card(
                  title: 'Category Breakdown',
                  child: categoryBreakdown.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: Text('No expenses this month', style: TextStyle(color: Colors.grey))),
                        )
                      : Column(
                          children: [
                            AnimatedPieChart(
                              data: categoryBreakdown,
                              centerAmountFormatted: CurrencyUtils.formatAmount(totalExpense, currencySymbol),
                            ),
                            const SizedBox(height: 12),
                            ...categoryBreakdown.map((c) => _SummaryRow(item: c, currencySymbol: currencySymbol)),
                          ],
                        ),
                ),
                const SizedBox(height: 16),
                _Card(
                  title: 'Monthly Trends',
                  child: trendsAsync.when(
                    loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
                    error: (e, st) => Text('Error: $e'),
                    data: (trends) => Column(
                      children: [
                        AnimatedBarChart(trends: trends),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _legendDot(AppColors.incomeGreenDark, 'Income'),
                            const SizedBox(width: 16),
                            _legendDot(AppColors.expenseRedDark, 'Expense'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _Card(
                  title: 'Payment Method Breakdown',
                  child: paymentBreakdown.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: Text('No expenses this month', style: TextStyle(color: Colors.grey))),
                        )
                      : Column(
                          children: [
                            AnimatedPieChart(
                              data: paymentBreakdown,
                              centerAmountFormatted: CurrencyUtils.formatAmount(totalExpense, currencySymbol),
                              centerTitle: 'By Payment',
                            ),
                            const SizedBox(height: 12),
                            ...paymentBreakdown.map(
                              (c) => _SummaryRow(
                                item: c,
                                currencySymbol: currencySymbol,
                                onTap: () => _showDrilldown(context, ref, c, selectedMonth),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Future<void> _showDrilldown(
    BuildContext context,
    WidgetRef ref,
    CategorySummary paymentMethod,
    DateTime month,
  ) async {
    final start = _startOfMonth(month);
    final end = _endOfMonth(month);
    final breakdown = await ref
        .read(transactionRepositoryProvider)
        .getCategoryBreakdownForPaymentMethod(start, end, paymentMethod.categoryName);
    final currencySymbol = ref.read(currencySymbolProvider);

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${paymentMethod.categoryName} Breakdown'),
        content: SizedBox(
          width: double.maxFinite,
          child: breakdown.isEmpty
              ? const Text('No expenses for this payment method')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: breakdown.map((c) => _SummaryRow(item: c, currencySymbol: currencySymbol)).toList(),
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  int _startOfMonth(DateTime d) => DateTime(d.year, d.month, 1).millisecondsSinceEpoch;
  int _endOfMonth(DateTime d) =>
      DateTime(d.year, d.month + 1, 1).subtract(const Duration(milliseconds: 1)).millisecondsSinceEpoch;
}

class _FiscalYearTab extends ConsumerWidget {
  const _FiscalYearTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startYear = ref.watch(fiscalYearStartYearProvider);
    final currencySymbol = ref.watch(currencySymbolProvider);
    final summaryAsync = ref.watch(fiscalYearSummaryProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => ref.read(fiscalYearStartYearProvider.notifier).state = startYear - 1,
            ),
            Text('FY $startYear–${startYear + 1}', style: Theme.of(context).textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => ref.read(fiscalYearStartYearProvider.notifier).state = startYear + 1,
            ),
          ],
        ),
        const SizedBox(height: 12),
        summaryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Error: $e')),
          data: (summary) {
            final total = summary.totalIncome + summary.totalExpense;
            final data = total <= 0
                ? <CategorySummary>[]
                : [
                    CategorySummary(
                      categoryName: 'Income',
                      totalAmount: summary.totalIncome,
                      percentage: (summary.totalIncome / total) * 100,
                      colorHex: '#10B981',
                      transactionCount: 1,
                    ),
                    CategorySummary(
                      categoryName: 'Expenses',
                      totalAmount: summary.totalExpense,
                      percentage: (summary.totalExpense / total) * 100,
                      colorHex: '#F43F5E',
                      transactionCount: 1,
                    ),
                  ];

            return Center(
              child: Column(
                children: [
                  AnimatedPieChart(
                    data: data,
                    centerAmountFormatted:
                        total <= 0 ? '$currencySymbol 0.00' : CurrencyUtils.formatBalance(summary.netSavings, currencySymbol),
                    centerTitle:
                        total <= 0 ? 'No Data' : 'Savings (${summary.savingsRatePercentage.toStringAsFixed(0)}%)',
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _pillBox(context, 'Total Income', CurrencyUtils.formatAmount(summary.totalIncome, currencySymbol),
                            AppColors.incomeGreenDark),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _pillBox(context, 'Total Expenses',
                            CurrencyUtils.formatAmount(summary.totalExpense, currencySymbol), AppColors.expenseRedDark),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _pillBox(BuildContext context, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;

  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final CategorySummary item;
  final String currencySymbol;
  final VoidCallback? onTap;

  const _SummaryRow({required this.item, required this.currencySymbol, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: AppColors.fromHex(item.colorHex), shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(item.categoryName)),
            Text('${item.percentage.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(width: 10),
            Text(CurrencyUtils.formatAmount(item.totalAmount, currencySymbol), style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
