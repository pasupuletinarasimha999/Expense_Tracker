import 'package:flutter/foundation.dart';

import '../local/daos/trip_dao.dart';
import '../local/daos/trip_expense_dao.dart';
import '../local/database.dart';
import '../preferences/user_preferences.dart';
import '../remote/drive_sync_manager.dart';

/// Repository for trip budgets and their expenses. Kept separate from
/// [TransactionRepository] — trip spending never touches the regular monthly transactions —
/// but, unlike the original Kotlin app (which deliberately excluded trips from Drive
/// backup), this app syncs trips/trip-expenses to Drive too, same as everything else.
/// Ported from `TripRepository.kt` with that sync behavior added.
class TripRepository {
  final TripDao _tripDao;
  final TripExpenseDao _tripExpenseDao;
  final DriveSyncManager _syncManager;
  final UserPreferences _preferences;

  TripRepository(this._tripDao, this._tripExpenseDao, this._syncManager, this._preferences);

  Stream<List<TripWithSpent>> watchAllTripsWithSpent() => _tripDao.watchAllTripsWithSpent();

  Stream<Trip?> watchTrip(int tripId) => _tripDao.watchTripById(tripId);

  Future<Trip?> getTripById(int tripId) => _tripDao.getTripById(tripId);

  Future<int> saveTrip(TripsCompanion trip) async {
    final id = await _tripDao.insertTrip(trip);
    _pushToGoogleCloud();
    return id;
  }

  /// Deletes the trip and its expenses, returning the deleted expenses so callers can
  /// cancel any scheduled reminders.
  Future<List<TripExpense>> deleteTrip(int tripId) async {
    final expenses = await _tripExpenseDao.getExpensesForTripSync(tripId);
    await _tripExpenseDao.deleteExpensesForTrip(tripId);
    await _tripDao.deleteTrip(tripId);
    _pushToGoogleCloud();
    return expenses;
  }

  Stream<List<TripExpense>> watchExpensesForTrip(int tripId) => _tripExpenseDao.watchExpensesForTrip(tripId);

  Future<int> saveExpense(TripExpensesCompanion expense) async {
    final id = await _tripExpenseDao.insertExpense(expense);
    _pushToGoogleCloud();
    return id;
  }

  Future<void> deleteExpense(int expenseId) async {
    await _tripExpenseDao.deleteExpense(expenseId);
    _pushToGoogleCloud();
  }

  void _pushToGoogleCloud() {
    final email = _preferences.userEmail;
    if (email.trim().isNotEmpty) {
      // ignore: discarded_futures
      _syncManager.pushUserData(email);
    } else {
      debugPrint('TripRepository: skipping auto-push, no signed-in email in preferences');
    }
  }
}
