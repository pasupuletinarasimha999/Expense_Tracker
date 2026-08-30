import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_providers.dart';
import '../../core/constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_utils.dart';
import '../../data/local/database.dart';
import '../../widgets/month_selector.dart';
import '../../widgets/transaction_list_tile.dart';
import '../transactions/add_edit_transaction_sheet.dart';
import '../transactions/recurring_scope_dialog.dart';
import 'dashboard_providers.dart';

/// Ported 1:1 from `DashboardFragment.kt` + `DashboardViewModel.kt`.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<void> _onLongPress(BuildContext context, WidgetRef ref, Transaction transaction) async {
    final scope = await showDeleteScopeDialog(context, isRecurring: transaction.isRecurring);
    if (scope == null) return;
    await ref.read(transactionRepositoryProvider).deleteTransaction(transaction, scope: scope);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaction deleted')));
    }
  }

  Future<void> _emailReport(BuildContext context, WidgetRef ref) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preparing monthly report for Gmail...')));
    final success = await ref.read(reportExportServiceProvider).exportToGmail();
    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to export report')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(selectedMonthProvider);
    final currencySymbol = ref.watch(currencySymbolProvider);
    final summaryAsync = ref.watch(monthlySummaryProvider);
    final transactionsAsync = ref.watch(monthTransactionsProvider);

    final summary = summaryAsync.valueOrNull;
    final balance = summary?.balance ?? 0;
    final income = summary?.totalIncome ?? 0;
    final expense = summary?.totalExpense ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Expense Tracker')),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: MonthSelector(
              selectedMonth: selectedMonth,
              onMonthSelected: (month) => ref.read(selectedMonthProvider.notifier).state = month,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Balance', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyUtils.formatBalance(balance, currencySymbol),
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _pill(context, 'Income', CurrencyUtils.formatSignedAmount(income, TransactionType.income, currencySymbol)),
                        const SizedBox(width: 12),
                        _pill(context, 'Expense', CurrencyUtils.formatSignedAmount(expense, TransactionType.expense, currencySymbol)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.add_circle_outline,
                      label: 'Add Income',
                      color: AppColors.pastelMint,
                      textColor: AppColors.pastelMintText,
                      onTap: () => showAddEditTransactionSheet(context, initialType: TransactionType.income),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.remove_circle_outline,
                      label: 'Add Expense',
                      color: AppColors.pastelPeach,
                      textColor: AppColors.pastelPeachText,
                      onTap: () => showAddEditTransactionSheet(context, initialType: TransactionType.expense),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.email_outlined,
                      label: 'Email Report',
                      color: AppColors.pastelSky,
                      textColor: AppColors.pastelSkyText,
                      onTap: () => _emailReport(context, ref),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("This Month's Transactions", style: Theme.of(context).textTheme.titleMedium),
                  TextButton(
                    onPressed: () => context.go('/transactions'),
                    child: const Text('See All'),
                  ),
                ],
              ),
            ),
          ),
          transactionsAsync.when(
            loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
            error: (e, st) => SliverToBoxAdapter(child: Center(child: Text('Error: $e'))),
            data: (list) {
              if (list.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No transactions this month', style: TextStyle(color: Colors.grey))),
                  ),
                );
              }
              return SliverList.builder(
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final txn = list[index];
                  return Dismissible(
                    key: ValueKey('txn_${txn.id}'),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (direction) async {
                      await ref.read(transactionRepositoryProvider).setPaidStatus(txn.id, !txn.isPaid);
                      return false;
                    },
                    background: Container(
                      color: txn.isPaid ? AppColors.surfaceVariantLight : AppColors.incomeGreen,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Icon(
                        Icons.check,
                        color: txn.isPaid ? AppColors.pastelMintText : AppColors.white,
                      ),
                    ),
                    child: Container(
                      color: txn.isPaid ? AppColors.pastelMint.withValues(alpha: 0.65) : null,
                      child: TransactionListTile(
                        transaction: txn,
                        currencySymbol: currencySymbol,
                        useRelativeDate: true,
                        onTap: () => showAddEditTransactionSheet(context, editing: txn),
                        onLongPress: () => _onLongPress(context, ref, txn),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Icon(icon, color: textColor),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
