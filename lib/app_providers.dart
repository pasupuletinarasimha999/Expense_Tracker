import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'data/local/daos/category_dao.dart';
import 'data/local/daos/trip_dao.dart';
import 'data/local/daos/trip_expense_dao.dart';
import 'data/local/daos/transaction_dao.dart';
import 'data/local/database.dart';
import 'data/preferences/user_preferences.dart';
import 'data/remote/drive_sync_manager.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/category_repository.dart';
import 'data/repositories/transaction_repository.dart';
import 'data/repositories/trip_repository.dart';
import 'services/report_export_service.dart';

/// [UserPreferences] must be constructed asynchronously (SharedPreferences.getInstance())
/// before `runApp`, so `main()` awaits [UserPreferences.init] and overrides this provider —
/// see `main.dart`. Every other provider below builds synchronously off of it.
final userPreferencesProvider = Provider<UserPreferences>((ref) {
  throw UnimplementedError('userPreferencesProvider must be overridden in main()');
});

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final transactionDaoProvider = Provider<TransactionDao>((ref) {
  return TransactionDao(ref.watch(databaseProvider));
});

final categoryDaoProvider = Provider<CategoryDao>((ref) {
  return CategoryDao(ref.watch(databaseProvider));
});

final tripDaoProvider = Provider<TripDao>((ref) {
  return TripDao(ref.watch(databaseProvider));
});

final tripExpenseDaoProvider = Provider<TripExpenseDao>((ref) {
  return TripExpenseDao(ref.watch(databaseProvider));
});

/// Scopes: `email` for the account identity, and Drive `appdata` for the private backup
/// file — matches the original's `GoogleSignInOptions` request.
final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  return GoogleSignIn(
    scopes: ['email', 'https://www.googleapis.com/auth/drive.appdata'],
  );
});

final driveSyncManagerProvider = Provider<DriveSyncManager>((ref) {
  final googleSignIn = ref.watch(googleSignInProvider);
  return DriveSyncManager(
    transactionDao: ref.watch(transactionDaoProvider),
    categoryDao: ref.watch(categoryDaoProvider),
    tripDao: ref.watch(tripDaoProvider),
    tripExpenseDao: ref.watch(tripExpenseDaoProvider),
    preferences: ref.watch(userPreferencesProvider),
    getAccessToken: () async {
      final account = googleSignIn.currentUser ?? await googleSignIn.signInSilently();
      if (account == null) return null;
      final auth = await account.authentication;
      return auth.accessToken;
    },
  );
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(
    ref.watch(transactionDaoProvider),
    ref.watch(userPreferencesProvider),
    ref.watch(driveSyncManagerProvider),
  );
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(
    ref.watch(categoryDaoProvider),
    ref.watch(driveSyncManagerProvider),
    ref.watch(userPreferencesProvider),
  );
});

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return TripRepository(
    ref.watch(tripDaoProvider),
    ref.watch(tripExpenseDaoProvider),
    ref.watch(driveSyncManagerProvider),
    ref.watch(userPreferencesProvider),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(userPreferencesProvider), ref.watch(driveSyncManagerProvider));
});

final reportExportServiceProvider = Provider<ReportExportService>((ref) {
  return ReportExportService(ref.watch(transactionRepositoryProvider), ref.watch(userPreferencesProvider));
});

/// Month currently selected on the Dashboard/Analytics month strip — shared between both
/// screens, mirroring the original's `SelectedMonthState` singleton.
final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

/// Whether dark mode is enabled — mirrors `UserPreferencesManager.isDarkModeEnabled`,
/// exposed as reactive state so toggling it in Settings updates `MaterialApp.themeMode`
/// immediately.
final darkModeProvider = StateProvider<bool>((ref) {
  return ref.watch(userPreferencesProvider).isDarkModeEnabled;
});

/// Currency symbol currently in effect — mirrors `UserPreferencesManager.currencySymbol`,
/// exposed as reactive state so changing it in Settings updates every formatted amount
/// on screen immediately.
final currencySymbolProvider = StateProvider<String>((ref) {
  return ref.watch(userPreferencesProvider).currencySymbol;
});

final currencyCodeProvider = StateProvider<String>((ref) {
  return ref.watch(userPreferencesProvider).currencyCode;
});

/// Whether the App Lock screen should gate the app — mirrors
/// `UserPreferencesManager.isAppLockEnabled`.
final appLockEnabledProvider = StateProvider<bool>((ref) {
  return ref.watch(userPreferencesProvider).isAppLockEnabled;
});

/// In-memory, process-lifetime "already unlocked" flag — mirrors
/// `ExpenseTrackerApplication.isSessionUnlocked`. Resets only on a cold app start, never on
/// background/foreground.
final appLockSessionUnlockedProvider = StateProvider<bool>((ref) => false);
