import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Light/dark ThemeData ported from the original app's `themes.xml` /
/// `values-night/themes.xml` (Material3 DayNight pastel theme).
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: AppColors.white,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        onSecondary: AppColors.white,
        secondaryContainer: AppColors.secondaryContainer,
        background: AppColors.backgroundLight,
        surface: AppColors.surfaceLight,
        surfaceVariant: AppColors.surfaceVariantLight,
        onSurface: AppColors.textPrimaryLight,
        onSurfaceVariant: AppColors.textSecondaryLight,
        cardStroke: AppColors.cardStrokeLight,
        divider: AppColors.dividerLight,
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        primary: AppColors.primaryDarkTheme,
        onPrimary: AppColors.onPrimaryDarkTheme,
        primaryContainer: AppColors.primaryContainerDarkTheme,
        onPrimaryContainer: AppColors.onPrimaryContainerDarkTheme,
        secondary: AppColors.secondaryDarkTheme,
        onSecondary: AppColors.onSecondaryDarkTheme,
        secondaryContainer: AppColors.secondaryContainerDarkTheme,
        background: AppColors.backgroundDark,
        surface: AppColors.surfaceDark,
        surfaceVariant: AppColors.surfaceVariantDark,
        onSurface: AppColors.textPrimaryDark,
        onSurfaceVariant: AppColors.textSecondaryDark,
        cardStroke: AppColors.cardStrokeDark,
        divider: AppColors.dividerDark,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color primary,
    required Color onPrimary,
    required Color primaryContainer,
    required Color onPrimaryContainer,
    required Color secondary,
    required Color onSecondary,
    required Color secondaryContainer,
    required Color background,
    required Color surface,
    required Color surfaceVariant,
    required Color onSurface,
    required Color onSurfaceVariant,
    required Color cardStroke,
    required Color divider,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      secondary: secondary,
      onSecondary: onSecondary,
      secondaryContainer: secondaryContainer,
      onSecondaryContainer: onPrimaryContainer,
      error: AppColors.expenseRedDark,
      onError: AppColors.white,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: surfaceVariant,
      onSurfaceVariant: onSurfaceVariant,
      outline: divider,
      outlineVariant: cardStroke,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: brightness == Brightness.light ? 2 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: brightness == Brightness.dark
              ? BorderSide(color: cardStroke)
              : BorderSide.none,
        ),
        margin: EdgeInsets.zero,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: AppColors.pastelLilac.withValues(alpha: brightness == Brightness.dark ? 0.3 : 1),
        surfaceTintColor: Colors.transparent,
        // Default Material 3 label size wraps "Transactions" onto two lines at 5 tabs wide.
        labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 10.5)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.btnActionAccent,
        foregroundColor: AppColors.white,
      ),
      dividerTheme: DividerThemeData(color: divider, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      textTheme: ThemeData(brightness: brightness).textTheme.apply(
            bodyColor: onSurface,
            displayColor: onSurface,
          ),
    );
  }
}
