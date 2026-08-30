import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_utils.dart';
import '../../data/local/daos/trip_dao.dart';

/// Ported 1:1 from `item_trip_card.xml` + `TripAdapter.kt`.
class TripCard extends StatelessWidget {
  final TripWithSpent item;
  final String currencySymbol;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const TripCard({
    super.key,
    required this.item,
    required this.currencySymbol,
    required this.onTap,
    required this.onLongPress,
  });

  static final _dateFormat = DateFormat('MMM d');
  static final _dateWithYearFormat = DateFormat('MMM d, yyyy');

  String _formatRange(DateTime start, DateTime end) {
    final sameYear = start.year == end.year;
    final startStr = sameYear ? _dateFormat.format(start) : _dateWithYearFormat.format(start);
    final endStr = _dateWithYearFormat.format(end);
    return '$startStr – $endStr';
  }

  @override
  Widget build(BuildContext context) {
    final trip = item.trip;
    final start = DateTime.fromMillisecondsSinceEpoch(trip.startDate);
    final end = DateTime.fromMillisecondsSinceEpoch(trip.endDate);
    final now = DateTime.now();

    final String statusLabel;
    final Color statusBg;
    final Color statusText;
    if (now.isBefore(start)) {
      statusLabel = 'UPCOMING';
      statusBg = AppColors.pastelLilac;
      statusText = AppColors.pastelLilacText;
    } else if (now.isAfter(end)) {
      statusLabel = 'COMPLETED';
      statusBg = AppColors.surfaceVariantLight;
      statusText = AppColors.textSecondaryLight;
    } else {
      statusLabel = 'ONGOING';
      statusBg = AppColors.pastelMint;
      statusText = AppColors.pastelMintText;
    }

    final destinationPart = trip.destination.isNotEmpty ? '${trip.destination} • ' : '';
    final progress = trip.budget > 0 ? (item.totalSpent / trip.budget).clamp(0.0, 1.0) : 0.0;
    final progressColor = trip.budget > 0
        ? (item.totalSpent >= trip.budget
            ? AppColors.expenseRed
            : (progress >= 0.85 ? const Color(0xFFFF8A65) : AppColors.primary))
        : AppColors.primary;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(trip.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12)),
                    child: Text(statusLabel, style: TextStyle(color: statusText, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '$destinationPart${_formatRange(start, end)}',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('${CurrencyUtils.formatAmount(item.totalSpent, currencySymbol)} spent',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  Text(
                    trip.budget > 0 ? 'of ${CurrencyUtils.formatAmount(trip.budget, currencySymbol)} budget' : 'no budget set',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
              if (trip.budget > 0) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: AppColors.surfaceVariantLight,
                    valueColor: AlwaysStoppedAnimation(progressColor),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
