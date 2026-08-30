import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../data/local/database.dart';

final tripProvider = StreamProvider.family<Trip?, int>((ref, tripId) {
  return ref.watch(tripRepositoryProvider).watchTrip(tripId);
});

final tripExpensesProvider = StreamProvider.family<List<TripExpense>, int>((ref, tripId) {
  return ref.watch(tripRepositoryProvider).watchExpensesForTrip(tripId);
});

final savedTowardTripProvider = StreamProvider.family<double, int>((ref, tripId) {
  return ref.watch(transactionRepositoryProvider).watchSavingsForTrip(tripId);
});
