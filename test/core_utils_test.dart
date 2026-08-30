import 'package:flutter_test/flutter_test.dart';

import 'package:expense_tracker/core/constants.dart';
import 'package:expense_tracker/core/utils/currency_utils.dart';
import 'package:expense_tracker/core/utils/date_time_utils.dart';

void main() {
  group('DateTimeUtils', () {
    test('getStartOfMonthTimestamp / getEndOfMonthTimestamp bound the month', () {
      final mid = DateTime(2026, 2, 15, 10, 30);
      final start = DateTimeUtils.getStartOfMonthTimestamp(mid);
      final end = DateTimeUtils.getEndOfMonthTimestamp(mid);

      final startDate = DateTime.fromMillisecondsSinceEpoch(start);
      final endDate = DateTime.fromMillisecondsSinceEpoch(end);

      expect(startDate, DateTime(2026, 2, 1));
      // 2026 is not a leap year, so February has 28 days.
      expect(endDate.day, 28);
      expect(endDate.month, 2);
      expect(endDate.hour, 23);
      expect(endDate.minute, 59);
    });

    test('formatIsoDate formats as yyyy-MM-dd', () {
      final ts = DateTime(2026, 3, 5).millisecondsSinceEpoch;
      expect(DateTimeUtils.formatIsoDate(ts), '2026-03-05');
    });
  });

  group('CurrencyUtils', () {
    test('formatBalance puts the minus sign before the symbol', () {
      expect(CurrencyUtils.formatBalance(-42.5, r'$'), r'-$ 42.50');
      expect(CurrencyUtils.formatBalance(42.5, r'$'), r'$ 42.50');
    });

    test('formatSignedAmount prefixes +/- by transaction type', () {
      expect(CurrencyUtils.formatSignedAmount(10, TransactionType.income, r'$'), r'+$ 10.00');
      expect(CurrencyUtils.formatSignedAmount(10, TransactionType.expense, r'$'), r'-$ 10.00');
    });
  });

  group('PaymentMethod', () {
    test('colorFor falls back to the last color for unknown methods', () {
      expect(PaymentMethod.colorFor('Cash'), '#64748B');
      expect(PaymentMethod.colorFor('Unknown'), PaymentMethod.colorFor('Other'));
    });
  });
}
