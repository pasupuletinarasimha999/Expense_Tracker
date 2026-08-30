import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_providers.dart';
import '../../data/local/daos/trip_dao.dart';
import '../../services/notifications/notification_service.dart';
import 'add_edit_trip_dialog.dart';
import 'trip_card.dart';
import 'trips_providers.dart';

/// Ported 1:1 from `TripsFragment.kt` + `TripsViewModel.kt`.
class TripsScreen extends ConsumerWidget {
  const TripsScreen({super.key});

  Future<void> _showOptions(BuildContext context, WidgetRef ref, TripWithSpent item) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.edit), title: const Text('Edit Trip'), onTap: () => Navigator.pop(context, 'edit')),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete Trip'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted) return;
    if (choice == 'edit') {
      showAddEditTripDialog(context, ref, editing: item.trip);
    } else if (choice == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Trip'),
          content: Text('Delete "${item.trip.name}" and all its budget items? This can\'t be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        final deletedExpenses = await ref.read(tripRepositoryProvider).deleteTrip(item.trip.id);
        for (final expense in deletedExpenses) {
          await NotificationService.instance.cancelReminder(expense.id);
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trip deleted')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencySymbol = ref.watch(currencySymbolProvider);
    final tripsAsync = ref.watch(tripsWithSpentProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trips'),
        actions: [
          TextButton.icon(
            onPressed: () => showAddEditTripDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('New Trip'),
          ),
        ],
      ),
      body: tripsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
        data: (trips) {
          if (trips.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('No trips yet. Tap "New Trip" to plan one!', style: TextStyle(color: Colors.grey)),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: trips.length,
            itemBuilder: (context, index) {
              final item = trips[index];
              return TripCard(
                item: item,
                currencySymbol: currencySymbol,
                onTap: () => context.go('/trips/${item.trip.id}'),
                onLongPress: () => _showOptions(context, ref, item),
              );
            },
          );
        },
      ),
    );
  }
}
