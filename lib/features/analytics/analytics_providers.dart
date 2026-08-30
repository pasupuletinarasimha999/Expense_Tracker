import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/utils/date_time_utils.dart';
import '../../data/models.dart';

final monthlyTrendsProvider = FutureProvider<List<MonthlyTrend>>((ref) {
  final month = ref.watch(selectedMonthProvider);
  return ref.watch(transactionRepositoryProvider).getMonthlyTrends(monthsBack: 6, end: month);
});

final categoryBreakdownProvider = StreamProvider<List<CategorySummary>>((ref) {
  final month = ref.watch(selectedMonthProvider);
  final start = DateTimeUtils.getStartOfMonthTimestamp(month);
  final end = DateTimeUtils.getEndOfMonthTimestamp(month);
  return ref.watch(transactionRepositoryProvider).watchCategoryBreakdown(start, end);
});

final paymentMethodBreakdownProvider = StreamProvider<List<CategorySummary>>((ref) {
  final month = ref.watch(selectedMonthProvider);
  final start = DateTimeUtils.getStartOfMonthTimestamp(month);
  final end = DateTimeUtils.getEndOfMonthTimestamp(month);
  return ref.watch(transactionRepositoryProvider).watchPaymentMethodBreakdown(start, end);
});

int currentFiscalStartYear() {
  final now = DateTime.now();
  return now.month < 4 ? now.year - 1 : now.year;
}

final fiscalYearStartYearProvider = StateProvider<int>((ref) => currentFiscalStartYear());

final fiscalYearSummaryProvider = FutureProvider<FiscalYearSummary>((ref) {
  final startYear = ref.watch(fiscalYearStartYearProvider);
  return ref.watch(transactionRepositoryProvider).getFiscalYearSummary(startYear);
});
