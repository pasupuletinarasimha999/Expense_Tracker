import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../data/local/database.dart';
import '../../data/preferences/user_preferences.dart';

final userProfileProvider = Provider<UserProfile>((ref) {
  return ref.watch(authRepositoryProvider).getCurrentUser();
});

/// Re-reads the last-sync timestamp every couple of seconds while Settings is open, so it
/// picks up background auto-syncs (triggered by adding/editing data elsewhere in the app)
/// without needing every mutation site to know how to invalidate this provider.
final lastSyncTimeProvider = StreamProvider<String>((ref) async* {
  final authRepository = ref.watch(authRepositoryProvider);
  yield authRepository.getLastSyncTime();
  yield* Stream.periodic(const Duration(seconds: 2), (_) => authRepository.getLastSyncTime());
});

final recurringTransactionsProvider = StreamProvider<List<Transaction>>((ref) {
  return ref.watch(transactionRepositoryProvider).watchRecurringTransactions();
});
