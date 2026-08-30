/// Small value types ported from `Models.kt`.
library;

class MonthlySummary {
  final double totalIncome;
  final double totalExpense;
  final double balance;

  const MonthlySummary({this.totalIncome = 0.0, this.totalExpense = 0.0, this.balance = 0.0});
}

class FiscalYearSummary {
  final String fiscalYearLabel;
  final double totalIncome;
  final double totalExpense;
  final double netSavings;
  final double savingsRatePercentage;
  final int startTimestamp;
  final int endTimestamp;

  const FiscalYearSummary({
    required this.fiscalYearLabel,
    this.totalIncome = 0.0,
    this.totalExpense = 0.0,
    this.netSavings = 0.0,
    this.savingsRatePercentage = 0.0,
    this.startTimestamp = 0,
    this.endTimestamp = 0,
  });
}

class CategorySummary {
  final String categoryName;
  final double totalAmount;
  final double percentage;
  final String colorHex;
  final int transactionCount;

  const CategorySummary({
    required this.categoryName,
    required this.totalAmount,
    required this.percentage,
    required this.colorHex,
    required this.transactionCount,
  });
}

class MonthlyTrend {
  final String monthLabel;
  final double totalIncome;
  final double totalExpense;
  final int timestamp;

  const MonthlyTrend({
    required this.monthLabel,
    required this.totalIncome,
    required this.totalExpense,
    required this.timestamp,
  });
}
