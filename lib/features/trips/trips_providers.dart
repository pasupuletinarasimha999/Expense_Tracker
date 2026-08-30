import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../data/local/daos/trip_dao.dart';

final tripsWithSpentProvider = StreamProvider<List<TripWithSpent>>((ref) {
  return ref.watch(tripRepositoryProvider).watchAllTripsWithSpent();
});
