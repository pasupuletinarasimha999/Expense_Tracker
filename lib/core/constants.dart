import 'package:flutter/material.dart';

enum TransactionType { income, expense }

extension TransactionTypeX on TransactionType {
  String get storageName => this == TransactionType.income ? 'INCOME' : 'EXPENSE';

  static TransactionType fromStorage(String value) {
    return value == 'INCOME' ? TransactionType.income : TransactionType.expense;
  }
}

/// Fixed set of payment methods a transaction can be tagged with.
/// Ported from `PaymentMethod.kt`.
class PaymentMethod {
  PaymentMethod._();

  static const cash = 'Cash';
  static const creditCard = 'Credit Card';
  static const debitCard = 'Debit Card';
  static const upi = 'UPI';
  static const netBanking = 'Net Banking';
  static const wallet = 'Wallet';
  static const other = 'Other';

  static const all = [cash, creditCard, debitCard, upi, netBanking, wallet, other];

  static const _colors = [
    '#64748B', // Cash - Slate
    '#6366F1', // Credit Card - Indigo
    '#0EA5E9', // Debit Card - Sky Blue
    '#10B981', // UPI - Emerald
    '#F97316', // Net Banking - Orange
    '#EC4899', // Wallet - Pink
    '#8B5CF6', // Other - Purple
  ];

  static String colorFor(String method) {
    final index = all.indexOf(method);
    return index >= 0 ? _colors[index] : _colors.last;
  }
}

/// A currency option offered in Settings. Ported from `Constants.kt`.
class CurrencyOption {
  final String code;
  final String symbol;
  final String displayName;

  const CurrencyOption(this.code, this.symbol, this.displayName);
}

class AppConstants {
  AppConstants._();

  static const defaultCurrencySymbol = r'$';
  static const defaultCurrencyCode = 'USD';

  static const availableCurrencies = [
    CurrencyOption('USD', r'$', 'USD (\$) - US Dollar'),
    CurrencyOption('INR', '₹', 'INR (₹) - Indian Rupee'),
    CurrencyOption('EUR', '€', 'EUR (€) - Euro'),
    CurrencyOption('GBP', '£', 'GBP (£) - British Pound'),
    CurrencyOption('JPY', '¥', 'JPY (¥) - Japanese Yen'),
    CurrencyOption('CAD', 'C\$', 'CAD (C\$) - Canadian Dollar'),
    CurrencyOption('AUD', 'A\$', 'AUD (A\$) - Australian Dollar'),
  ];

  /// Selecting this category on the Add/Edit Transaction sheet reveals the
  /// "Tag to Trip" dropdown.
  static const tripSavingsCategoryName = 'Trip Savings';
}

class CategoryDefault {
  final String name;
  final String iconName;
  final String colorHex;
  final TransactionType type;

  const CategoryDefault(this.name, this.iconName, this.colorHex, this.type);
}

/// Default categories seeded into the database on first run.
/// Ported from `Category.kt` `DEFAULT_EXPENSE_CATEGORIES` / `DEFAULT_INCOME_CATEGORIES`.
class DefaultCategories {
  DefaultCategories._();

  static const expense = [
    CategoryDefault('Food & Dining', 'ic_food', '#F97316', TransactionType.expense),
    CategoryDefault('Rent & Housing', 'ic_rent', '#6366F1', TransactionType.expense),
    CategoryDefault('Utilities & Bills', 'ic_utilities', '#0EA5E9', TransactionType.expense),
    CategoryDefault('Entertainment', 'ic_entertainment', '#EC4899', TransactionType.expense),
    CategoryDefault('Travel & Commute', 'ic_travel', '#14B8A6', TransactionType.expense),
    CategoryDefault('Shopping', 'ic_shopping', '#8B5CF6', TransactionType.expense),
    CategoryDefault('Health & Medical', 'ic_health', '#EF4444', TransactionType.expense),
    CategoryDefault('Education', 'ic_education', '#3B82F6', TransactionType.expense),
    CategoryDefault('Miscellaneous', 'ic_misc', '#64748B', TransactionType.expense),
    CategoryDefault(AppConstants.tripSavingsCategoryName, 'ic_wallet', '#D97706', TransactionType.expense),
  ];

  static const income = [
    CategoryDefault('Salary', 'ic_salary', '#10B981', TransactionType.income),
    CategoryDefault('Freelance / Gig', 'ic_freelance', '#059669', TransactionType.income),
    CategoryDefault('Investments', 'ic_investment', '#EAB308', TransactionType.income),
    CategoryDefault('Other Income', 'ic_misc', '#64748B', TransactionType.income),
  ];

  static List<CategoryDefault> get all => [...expense, ...income];
}

/// Ported from `Category.findByName` — looks up a default category's icon/color by name
/// (case-insensitive), falling back to a generic "misc" appearance for custom/unknown
/// category names (e.g. a category that was later deleted but still appears on old
/// transactions).
CategoryDefault findDefaultCategoryByName(String name) {
  for (final cat in DefaultCategories.all) {
    if (cat.name.toLowerCase() == name.toLowerCase()) return cat;
  }
  return CategoryDefault(name, 'ic_misc', '#64748B', TransactionType.expense);
}

/// Icons available in the custom-category picker. Ported from `Category.AVAILABLE_ICONS`.
const availableCategoryIcons = [
  'ic_food', 'ic_shopping', 'ic_cart', 'ic_travel', 'ic_car', 'ic_rent',
  'ic_utilities', 'ic_entertainment', 'ic_health', 'ic_education', 'ic_salary',
  'ic_freelance', 'ic_investment', 'ic_gift', 'ic_heart', 'ic_star', 'ic_receipt',
  'ic_calendar', 'ic_notes', 'ic_currency', 'ic_recurring', 'ic_wallet', 'ic_misc',
];

/// Colors available in the custom-category picker. Ported from `Category.AVAILABLE_COLORS`.
const availableCategoryColors = [
  '#F97316', '#6366F1', '#0EA5E9', '#EC4899', '#14B8A6', '#8B5CF6', '#EF4444',
  '#3B82F6', '#10B981', '#059669', '#EAB308', '#D97706', '#64748B', '#F472B6',
  '#34D399', '#22D3EE', '#A78BFA',
];

/// Default categories offered when adding a Trip expense — a separate,
/// travel-flavored set from the app's regular monthly expense categories.
/// Ported from `TripCategory.kt`.
class TripCategoryDefault {
  final String name;
  final String iconName;

  const TripCategoryDefault(this.name, this.iconName);
}

class TripCategories {
  TripCategories._();

  static const all = [
    TripCategoryDefault('Flights & Transport', 'ic_travel'),
    TripCategoryDefault('Hotel & Stay', 'ic_rent'),
    TripCategoryDefault('Local Transport', 'ic_car'),
    TripCategoryDefault('Food & Dining', 'ic_food'),
    TripCategoryDefault('Sightseeing & Activities', 'ic_star'),
    TripCategoryDefault('Shopping', 'ic_cart'),
    TripCategoryDefault('Visa & Documents', 'ic_notes'),
    TripCategoryDefault('Travel Insurance', 'ic_receipt'),
    TripCategoryDefault('Miscellaneous', 'ic_misc'),
  ];

  static String iconFor(String categoryName) {
    return all
        .firstWhere(
          (c) => c.name == categoryName,
          orElse: () => const TripCategoryDefault('', 'ic_misc'),
        )
        .iconName;
  }
}

/// Maps the original drawable icon names onto Material icons, since the
/// Flutter rewrite uses the built-in icon font instead of per-icon vector
/// drawables.
IconData iconForName(String iconName) {
  switch (iconName) {
    case 'ic_food':
      return Icons.restaurant;
    case 'ic_rent':
      return Icons.house;
    case 'ic_utilities':
      return Icons.bolt;
    case 'ic_entertainment':
      return Icons.movie;
    case 'ic_travel':
      return Icons.flight;
    case 'ic_shopping':
      return Icons.shopping_bag;
    case 'ic_cart':
      return Icons.shopping_cart;
    case 'ic_car':
      return Icons.directions_car;
    case 'ic_health':
      return Icons.local_hospital;
    case 'ic_education':
      return Icons.school;
    case 'ic_salary':
      return Icons.payments;
    case 'ic_freelance':
      return Icons.work;
    case 'ic_investment':
      return Icons.trending_up;
    case 'ic_gift':
      return Icons.card_giftcard;
    case 'ic_heart':
      return Icons.favorite;
    case 'ic_star':
      return Icons.star;
    case 'ic_receipt':
      return Icons.receipt_long;
    case 'ic_calendar':
      return Icons.calendar_today;
    case 'ic_notes':
      return Icons.note;
    case 'ic_currency':
      return Icons.attach_money;
    case 'ic_wallet':
      return Icons.account_balance_wallet;
    case 'ic_recurring':
      return Icons.autorenew;
    case 'ic_email':
      return Icons.email;
    default:
      return Icons.category;
  }
}
