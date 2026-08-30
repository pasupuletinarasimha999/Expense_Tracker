import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/utils/date_time_utils.dart';
import '../../data/local/database.dart';
import '../../data/models.dart';

final monthlySummaryProvider = StreamProvider<MonthlySummary>((ref) {
  final month = ref.watch(selectedMonthProvider);
  final start = DateTimeUtils.getStartOfMonthTimestamp(month);
  final end = DateTimeUtils.getEndOfMonthTimestamp(month);
  return ref.watch(transactionRepositoryProvider).watchMonthlySummary(start, end);
});

final monthTransactionsProvider = StreamProvider<List<Transaction>>((ref) {
  final month = ref.watch(selectedMonthProvider);
  final start = DateTimeUtils.getStartOfMonthTimestamp(month);
  final end = DateTimeUtils.getEndOfMonthTimestamp(month);
  return ref.watch(transactionRepositoryProvider).watchTransactionsBetween(start, end);
});
