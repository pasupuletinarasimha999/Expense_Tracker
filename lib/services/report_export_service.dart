import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/utils/csv_exporter.dart';
import '../core/utils/date_time_utils.dart';
import '../core/utils/pdf_report_exporter.dart';
import '../core/utils/share_helper.dart';
import '../data/preferences/user_preferences.dart';
import '../data/repositories/transaction_repository.dart';

/// Ported 1:1 from `SettingsViewModel.exportToGmail/exportCsv/exportPdf`. Shared between
/// the Dashboard's "Email Report" quick action and the Settings export rows — always
/// reports on the *current* calendar month, regardless of which month is selected on
/// Dashboard/Analytics (matches the original).
class ReportExportService {
  final TransactionRepository _transactionRepository;
  final UserPreferences _preferences;

  ReportExportService(this._transactionRepository, this._preferences);

  Future<bool> exportToGmail() async {
    try {
      final now = DateTime.now();
      final monthName = DateTimeUtils.formatMonthYear(now);
      final start = DateTimeUtils.getStartOfMonthTimestamp(now);
      final end = DateTimeUtils.getEndOfMonthTimestamp(now);

      final transactions = await _transactionRepository.getTransactionsBetweenSync(start, end);
      final summary = await _transactionRepository.watchMonthlySummary(start, end).first;
      final currency = _preferences.currencySymbol;
      final userEmail = _preferences.userEmail;

      final csvFile = await CsvExporter.exportTransactionsToCsv(
        transactions: transactions,
        monthName: monthName,
        summary: summary,
        currencySymbol: currency,
      );
      final pdfFile = await PdfReportExporter.generateMonthlyPdf(
        transactions: transactions,
        monthName: monthName,
        summary: summary,
        currencySymbol: currency,
        userEmail: userEmail,
      );

      await ShareHelper.sendReportViaEmail(
        recipientEmail: userEmail,
        monthName: monthName,
        summary: summary,
        currencySymbol: currency,
        attachedFiles: [pdfFile, csvFile],
      );
      return true;
    } catch (e, stackTrace) {
      debugPrint('ReportExportService.exportToGmail failed: $e\n$stackTrace');
      return false;
    }
  }

  Future<File?> exportCsv() async {
    try {
      final now = DateTime.now();
      final monthName = DateTimeUtils.formatMonthYear(now);
      final start = DateTimeUtils.getStartOfMonthTimestamp(now);
      final end = DateTimeUtils.getEndOfMonthTimestamp(now);

      final transactions = await _transactionRepository.getTransactionsBetweenSync(start, end);
      final summary = await _transactionRepository.watchMonthlySummary(start, end).first;
      final currency = _preferences.currencySymbol;

      final csvFile = await CsvExporter.exportTransactionsToCsv(
        transactions: transactions,
        monthName: monthName,
        summary: summary,
        currencySymbol: currency,
      );
      await ShareHelper.shareFile(csvFile, 'text/csv', 'Monthly Expense CSV - $monthName');
      return csvFile;
    } catch (e, stackTrace) {
      debugPrint('ReportExportService.exportCsv failed: $e\n$stackTrace');
      return null;
    }
  }

  Future<File?> exportPdf() async {
    try {
      final now = DateTime.now();
      final monthName = DateTimeUtils.formatMonthYear(now);
      final start = DateTimeUtils.getStartOfMonthTimestamp(now);
      final end = DateTimeUtils.getEndOfMonthTimestamp(now);

      final transactions = await _transactionRepository.getTransactionsBetweenSync(start, end);
      final summary = await _transactionRepository.watchMonthlySummary(start, end).first;
      final currency = _preferences.currencySymbol;
      final userEmail = _preferences.userEmail;

      final pdfFile = await PdfReportExporter.generateMonthlyPdf(
        transactions: transactions,
        monthName: monthName,
        summary: summary,
        currencySymbol: currency,
        userEmail: userEmail,
      );
      await ShareHelper.shareFile(pdfFile, 'application/pdf', 'Monthly Expense PDF - $monthName');
      return pdfFile;
    } catch (e, stackTrace) {
      debugPrint('ReportExportService.exportPdf failed: $e\n$stackTrace');
      return null;
    }
  }
}
