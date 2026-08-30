import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../data/local/database.dart';
import '../../data/models.dart';
import 'currency_utils.dart';
import 'date_time_utils.dart';

/// Ported 1:1 from `CsvExporter.kt`, including its CSV-injection hardening.
class CsvExporter {
  CsvExporter._();

  static final _formulaTriggerChars = ['=', '+', '-', '@', '\t', '\r'];

  static Future<File> exportTransactionsToCsv({
    required List<Transaction> transactions,
    required String monthName,
    required MonthlySummary summary,
    required String currencySymbol,
  }) async {
    final cacheDir = await getTemporaryDirectory();
    final reportsDir = Directory('${cacheDir.path}/reports');
    if (!await reportsDir.exists()) await reportsDir.create(recursive: true);

    final sanitizedMonth = monthName.replaceAll(' ', '_').toLowerCase();
    final file = File('${reportsDir.path}/Expense_Report_${sanitizedMonth}_${DateTimeUtils.formatFileTimestamp()}.csv');

    final buffer = StringBuffer();
    buffer.write('Expense Tracker Report - $monthName\n');
    buffer.write('Total Income,${CurrencyUtils.formatAmount(summary.totalIncome, currencySymbol)}\n');
    buffer.write('Total Expenses,${CurrencyUtils.formatAmount(summary.totalExpense, currencySymbol)}\n');
    buffer.write('Net Balance,${CurrencyUtils.formatBalance(summary.balance, currencySymbol)}\n\n');

    buffer.write('ID,Date,Title,Type,Category,Payment Method,Amount ($currencySymbol),Recurring,Notes\n');

    for (final txn in transactions) {
      final dateStr = DateTimeUtils.formatIsoDate(txn.timestamp);
      final recurringStr = txn.isRecurring ? 'Yes' : 'No';
      buffer.write(
        '${txn.id},$dateStr,${_escapeCsv(txn.title)},${txn.type},${_escapeCsv(txn.category)},'
        '${_escapeCsv(txn.paymentMethod)},${txn.amount},$recurringStr,${_escapeCsv(txn.notes)}\n',
      );
    }

    await file.writeAsString(buffer.toString());
    return file;
  }

  static String _escapeCsv(String value) {
    var str = value;
    if (str.isNotEmpty && _formulaTriggerChars.contains(str[0])) {
      str = "'$str";
    }
    str = str.replaceAll('"', '""');
    if (str.contains(',') || str.contains('\n') || str.contains('"')) {
      str = '"$str"';
    }
    return str;
  }
}
