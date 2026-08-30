import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../data/local/database.dart';
import '../../data/models.dart';
import '../constants.dart';
import 'currency_utils.dart';
import 'date_time_utils.dart';

/// Ported from `PdfReportExporter.kt`. The original hand-managed page breaks on an
/// Android `Canvas`; here `pw.MultiPage` handles pagination natively while keeping the
/// same visual structure (title, summary boxes, transaction table, continuation header).
class PdfReportExporter {
  PdfReportExporter._();

  static const _titleColor = PdfColor.fromInt(0xFF4F46E5);
  static const _subColor = PdfColor.fromInt(0xFF64748B);
  static const _headerColor = PdfColor.fromInt(0xFF0F172A);
  static const _incomeColor = PdfColor.fromInt(0xFF10B981);
  static const _expenseColor = PdfColor.fromInt(0xFFF43F5E);
  static const _lineColor = PdfColor.fromInt(0xFFE2E8F0);
  static const _cardBgColor = PdfColor.fromInt(0xFFF8FAFC);

  static Future<File> generateMonthlyPdf({
    required List<Transaction> transactions,
    required String monthName,
    required MonthlySummary summary,
    required String currencySymbol,
    required String userEmail,
  }) async {
    final cacheDir = await getTemporaryDirectory();
    final reportsDir = Directory('${cacheDir.path}/reports');
    if (!await reportsDir.exists()) await reportsDir.create(recursive: true);

    final sanitizedMonth = monthName.replaceAll(' ', '_').toLowerCase();
    final file = File('${reportsDir.path}/Monthly_Report_${sanitizedMonth}_${DateTimeUtils.formatFileTimestamp()}.pdf');

    final doc = pw.Document();
    final today = DateTimeUtils.formatDate(DateTime.now().millisecondsSinceEpoch);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) {
          if (context.pageNumber == 1) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('EXPENSE TRACKER',
                    style: pw.TextStyle(color: _titleColor, fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Text('Monthly Financial Statement • $monthName',
                    style: pw.TextStyle(color: _headerColor, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text('Generated for: $userEmail | Date: $today',
                    style: pw.TextStyle(color: _subColor, fontSize: 10)),
                pw.SizedBox(height: 12),
                pw.Container(
                  decoration: pw.BoxDecoration(color: _cardBgColor, borderRadius: pw.BorderRadius.circular(8)),
                  padding: const pw.EdgeInsets.all(12),
                  child: pw.Row(
                    children: [
                      _summaryBox('Total Income', CurrencyUtils.formatAmount(summary.totalIncome, currencySymbol), _incomeColor),
                      _summaryBox(
                          'Total Expenses', CurrencyUtils.formatAmount(summary.totalExpense, currencySymbol), _expenseColor),
                      _summaryBox('Net Balance', CurrencyUtils.formatBalance(summary.balance, currencySymbol), _headerColor),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Text('TRANSACTION DETAILS (${transactions.length})',
                    style: pw.TextStyle(color: _headerColor, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Divider(color: _lineColor, thickness: 1),
                _tableHeaderRow(),
                pw.Divider(color: _lineColor, thickness: 1),
              ],
            );
          }
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Monthly Financial Statement • $monthName (Page ${context.pageNumber})',
                  style: pw.TextStyle(color: _subColor, fontSize: 10)),
              pw.SizedBox(height: 10),
              pw.Divider(color: _lineColor, thickness: 1),
              _tableHeaderRow(),
              pw.Divider(color: _lineColor, thickness: 1),
            ],
          );
        },
        build: (context) => [
          ...transactions.map(_transactionRow),
          pw.SizedBox(height: 10),
          pw.Divider(color: _lineColor, thickness: 1),
          pw.SizedBox(height: 8),
          pw.Text('Report automatically compiled by Expense Tracker App.',
              style: pw.TextStyle(color: _subColor, fontSize: 10)),
        ],
      ),
    );

    await file.writeAsBytes(await doc.save());
    return file;
  }

  static pw.Widget _summaryBox(String label, String value, PdfColor valueColor) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(color: _subColor, fontSize: 10)),
          pw.SizedBox(height: 6),
          pw.Text(value, style: pw.TextStyle(color: valueColor, fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Widget _tableHeaderRow() {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 65, child: pw.Text('Date', style: pw.TextStyle(color: _subColor, fontSize: 9))),
          pw.Expanded(flex: 3, child: pw.Text('Title / Notes', style: pw.TextStyle(color: _subColor, fontSize: 9))),
          pw.Expanded(flex: 2, child: pw.Text('Category', style: pw.TextStyle(color: _subColor, fontSize: 9))),
          pw.SizedBox(width: 55, child: pw.Text('Type', style: pw.TextStyle(color: _subColor, fontSize: 9))),
          pw.SizedBox(
            width: 80,
            child: pw.Text('Amount', textAlign: pw.TextAlign.right, style: pw.TextStyle(color: _subColor, fontSize: 9)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _transactionRow(Transaction txn) {
    final dateStr = DateTimeUtils.formatDate(txn.timestamp);
    final titleSnippet = txn.title.length > 28 ? '${txn.title.substring(0, 25)}...' : txn.title;
    final categorySnippet = txn.category.length > 18 ? '${txn.category.substring(0, 15)}...' : txn.category;
    final type = TransactionTypeX.fromStorage(txn.type);
    final amountStr = CurrencyUtils.formatSignedAmount(txn.amount, type, '');
    final amountColor = type == TransactionType.income ? _incomeColor : _expenseColor;

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 65, child: pw.Text(dateStr, style: pw.TextStyle(color: _headerColor, fontSize: 9))),
          pw.Expanded(flex: 3, child: pw.Text(titleSnippet, style: pw.TextStyle(color: _headerColor, fontSize: 9))),
          pw.Expanded(flex: 2, child: pw.Text(categorySnippet, style: pw.TextStyle(color: _subColor, fontSize: 9))),
          pw.SizedBox(width: 55, child: pw.Text(txn.type, style: pw.TextStyle(color: _subColor, fontSize: 9))),
          pw.SizedBox(
            width: 80,
            child: pw.Text(amountStr,
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(color: amountColor, fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
