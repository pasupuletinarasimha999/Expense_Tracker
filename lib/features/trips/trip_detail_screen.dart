import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_utils.dart';
import '../../data/local/database.dart';
import 'add_edit_trip_expense_sheet.dart';
import 'trip_detail_providers.dart';
import 'trip_expense_tile.dart';

/// Ported 1:1 from `TripDetailFragment.kt` + `TripDetailViewModel.kt`.
class TripDetailScreen extends ConsumerWidget {
  final int tripId;

  const TripDetailScreen({super.key, required this.tripId});

  static final _dateFormat = DateFormat('MMM d, yyyy');
  static final _dateFormatNoYear = DateFormat('MMM d');

  String _formatRange(DateTime start, DateTime end) {
    final sameYear = start.year == end.year;
    final startStr = sameYear ? _dateFormatNoYear.format(start) : _dateFormat.format(start);
    return '$startStr – ${_dateFormat.format(end)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(tripProvider(tripId));
    final expensesAsync = ref.watch(tripExpensesProvider(tripId));
    final savedAsync = ref.watch(savedTowardTripProvider(tripId));
    final currencySymbol = ref.watch(currencySymbolProvider);

    final trip = tripAsync.valueOrNull;
    final expenses = expensesAsync.valueOrNull ?? const [];
    final saved = savedAsync.valueOrNull ?? 0.0;

    return Scaffold(
      appBar: AppBar(title: Text(trip?.name ?? 'Trip')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddEditTripExpenseSheet(context, ref, tripId: tripId, tripName: trip?.name ?? ''),
        child: const Icon(Icons.add),
      ),
      body: trip == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeader(context, trip, saved, currencySymbol),
                const SizedBox(height: 16),
                _buildSpendingCard(context, expenses, currencySymbol),
                const SizedBox(height: 20),
                Text('Budget Items', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (expenses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('No budget items yet. Tap + to add one.', style: TextStyle(color: Colors.grey))),
                  )
                else
                  Card(
                    child: Column(
                      children: expenses
                          .map((e) => TripExpenseTile(
                                expense: e,
                                currencySymbol: currencySymbol,
                                onTap: () => showAddEditTripExpenseSheet(
                                  context,
                                  ref,
                                  tripId: tripId,
                                  tripName: trip.name,
                                  editing: e,
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                const SizedBox(height: 80),
              ],
            ),
    );
  }

  Widget _buildHeader(BuildContext context, Trip trip, double saved, String currencySymbol) {
    final start = DateTime.fromMillisecondsSinceEpoch(trip.startDate);
    final end = DateTime.fromMillisecondsSinceEpoch(trip.endDate);
    final now = DateTime.now();

    final String statusPart;
    if (now.isBefore(start)) {
      final days = start.difference(now).inDays + 1;
      statusPart = '$days day${days != 1 ? 's' : ''} to go';
    } else if (now.isAfter(end)) {
      statusPart = 'Completed';
    } else {
      statusPart = 'Ongoing';
    }

    final destinationPart = trip.destination.isNotEmpty ? '${trip.destination} • ' : '';
    final budget = trip.budget;
    final remaining = budget - saved;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(trip.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('$destinationPart${_formatRange(start, end)} • $statusPart', style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 20),
          const Text('SAVINGS PROGRESS', style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1)),
          const SizedBox(height: 6),
          Text(CurrencyUtils.formatAmount(saved, currencySymbol), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            budget > 0
                ? 'saved of ${CurrencyUtils.formatAmount(budget, currencySymbol)} goal • ${remaining > 0 ? '${CurrencyUtils.formatAmount(remaining, currencySymbol)} still to save' : 'Goal reached! 🎉'}'
                : 'no budget goal set',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          if (budget > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (saved / budget).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpendingCard(BuildContext context, List<TripExpense> expenses, String currencySymbol) {
    final paidTotal = expenses.where((e) => e.isPaid).fold<double>(0, (sum, e) => sum + e.amount);
    final toBePaidTotal = expenses.where((e) => !e.isPaid).fold<double>(0, (sum, e) => sum + e.amount);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trip Spending', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Paid', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text(CurrencyUtils.formatAmount(paidTotal, currencySymbol),
                          style: const TextStyle(color: AppColors.incomeGreenDark, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('To Be Paid', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text(CurrencyUtils.formatAmount(toBePaidTotal, currencySymbol),
                          style: const TextStyle(color: AppColors.expenseRedDark, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
