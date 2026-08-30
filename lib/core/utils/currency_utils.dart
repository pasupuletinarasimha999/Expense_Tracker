import 'package:intl/intl.dart';
import '../constants.dart';

/// Currency formatting, ported 1:1 from `CurrencyUtils.kt`. Always formats
/// with `en_US` grouping (2 decimals) regardless of the chosen currency/locale.
class CurrencyUtils {
  CurrencyUtils._();

  static final _numberFormatter = NumberFormat('#,##0.00', 'en_US');

  static String formatAmount(double amount, String currencySymbol) {
    return '$currencySymbol ${_numberFormatter.format(amount)}';
  }

  static String formatSignedAmount(double amount, TransactionType type, String currencySymbol) {
    final sign = type == TransactionType.income ? '+' : '-';
    return '$sign$currencySymbol ${_numberFormatter.format(amount)}';
  }

  static String formatBalance(double balance, String currencySymbol) {
    final prefix = balance < 0 ? '-$currencySymbol ' : '$currencySymbol ';
    return prefix + _numberFormatter.format(balance.abs());
  }
}
