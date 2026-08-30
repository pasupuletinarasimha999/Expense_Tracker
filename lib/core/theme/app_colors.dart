import 'package:flutter/material.dart';

/// Dreamy pastel palette, ported 1:1 from the original app's `colors.xml`.
class AppColors {
  AppColors._();

  // Primary — Soft Lavender
  static const primary = Color(0xFF7C6FEC);
  static const primaryDark = Color(0xFF5B4FC7);
  static const primaryLight = Color(0xFFEDE8FF);
  static const primaryContainer = Color(0xFFDDD6FE);
  static const onPrimaryContainer = Color(0xFF3B2E8A);

  // Secondary — Soft Rose
  static const secondary = Color(0xFFE879A6);
  static const secondaryContainer = Color(0xFFFCEEF5);

  // Prominent action button — Coral Rose gradient
  static const btnActionAccent = Color(0xFFF06292);
  static const btnActionAccentDark = Color(0xFFD84679);
  static const btnActionAccentLight = Color(0xFFFCE4EC);

  // Semantic financial colors
  static const incomeGreen = Color(0xFF4DB6AC);
  static const incomeGreenDark = Color(0xFF00897B);
  static const incomeGreenLight = Color(0xFFE0F2F1);
  static const incomeGreenSubtle = Color(0xFFE8F8F5);

  static const expenseRed = Color(0xFFF48FB1);
  static const expenseRedDark = Color(0xFFE91E63);
  static const expenseRedLight = Color(0xFFFCE4EC);
  static const expenseRedSubtle = Color(0xFFFFF0F5);

  static const balanceBlue = Color(0xFF64B5F6);
  static const balanceBlueLight = Color(0xFFE3F2FD);

  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);

  // Light theme surfaces
  static const backgroundLight = Color(0xFFFBF8FF);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceVariantLight = Color(0xFFF5F0FF);
  static const cardStrokeLight = Color(0xFFE8E0F0);
  static const dividerLight = Color(0xFFE8E0F0);

  static const textPrimaryLight = Color(0xFF1A1625);
  static const textSecondaryLight = Color(0xFF6B6180);
  static const textTertiaryLight = Color(0xFF9E94B3);

  // Dark theme surfaces
  static const backgroundDark = Color(0xFF211E2E);
  static const surfaceDark = Color(0xFF2A2740);
  static const surfaceVariantDark = Color(0xFF383253);
  static const cardStrokeDark = Color(0xFF4A4368);
  static const dividerDark = Color(0xFF4A4368);

  static const textPrimaryDark = Color(0xFFF5F0FF);
  static const textSecondaryDark = Color(0xFFB6ACD1);
  static const textTertiaryDark = Color(0xFF8C81A8);

  // Dark theme primary/secondary overrides
  static const primaryDarkTheme = Color(0xFFB3A9F7);
  static const onPrimaryDarkTheme = Color(0xFF2C2650);
  static const primaryContainerDarkTheme = Color(0xFF4B4374);
  static const onPrimaryContainerDarkTheme = Color(0xFFE7E2FF);

  static const secondaryDarkTheme = Color(0xFFF0AFCF);
  static const onSecondaryDarkTheme = Color(0xFF4A1F35);
  static const secondaryContainerDarkTheme = Color(0xFF5C3A52);

  // Pastel quick-action card colors
  static const pastelMint = Color(0xFFC8F7E8);
  static const pastelMintText = Color(0xFF00796B);
  static const pastelPeach = Color(0xFFFFE0E6);
  static const pastelPeachText = Color(0xFFC62828);
  static const pastelSky = Color(0xFFD6ECFF);
  static const pastelSkyText = Color(0xFF1565C0);
  static const pastelLilac = Color(0xFFEAE0FF);
  static const pastelLilacText = Color(0xFF5B4FC7);

  // Dashboard summary cards
  static const pastelIncomeCard = Color(0xFFE0F7EE);
  static const pastelExpenseCard = Color(0xFFFFF0F5);

  /// Parses a `#RRGGBB` hex string (as stored on categories/payment methods)
  /// into a [Color], falling back to slate gray on failure — mirrors
  /// `Color.parseColor` fallback behavior in the original chart views.
  static Color fromHex(String hex, {Color fallback = const Color(0xFF64748B)}) {
    try {
      var value = hex.replaceFirst('#', '');
      if (value.length == 6) value = 'FF$value';
      return Color(int.parse(value, radix: 16));
    } catch (_) {
      return fallback;
    }
  }
}
