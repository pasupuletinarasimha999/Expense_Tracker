import 'dart:io';

import 'package:share_plus/share_plus.dart';

import '../../data/models.dart';
import 'currency_utils.dart';

/// Ported from `GmailShareHelper.kt`. `share_plus` opens the same Android share-sheet
/// chooser as the original's `Intent.createChooser`, but has no direct equivalent of
/// `Intent.EXTRA_EMAIL` — the recipient can't be pre-addressed, only the subject/body/files.
class ShareHelper {
  ShareHelper._();

  static Future<void> sendReportViaEmail({
    required String recipientEmail,
    required String monthName,
    required MonthlySummary summary,
    required String currencySymbol,
    required List<File> attachedFiles,
  }) async {
    final subject = 'Expense Tracker Monthly Financial Statement - $monthName';
    final body = StringBuffer()
      ..write('Hello,\n\n')
      ..write('Here is your monthly financial summary report for $monthName from Expense Tracker:\n\n')
      ..write('• Total Income:   ${CurrencyUtils.formatAmount(summary.totalIncome, currencySymbol)}\n')
      ..write('• Total Expenses: ${CurrencyUtils.formatAmount(summary.totalExpense, currencySymbol)}\n')
      ..write('• Net Balance:    ${CurrencyUtils.formatBalance(summary.balance, currencySymbol)}\n\n')
      ..write('Attached are your itemized CSV and PDF report statements.\n\n')
      ..write('Best regards,\nExpense Tracker App');

    await Share.shareXFiles(
      attachedFiles.map((f) => XFile(f.path)).toList(),
      subject: subject,
      text: body.toString(),
    );
  }

  static Future<void> shareFile(File file, String mimeType, String subject) async {
    await Share.shareXFiles([XFile(file.path, mimeType: mimeType)], subject: subject);
  }
}
