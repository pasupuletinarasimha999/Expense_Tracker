import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import '../../app_providers.dart';
import '../../core/constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/remote/drive_sync_manager.dart';
import 'currency_picker_dialog.dart';
import 'recurring_manager_dialog.dart';
import 'settings_providers.dart';

/// Ported 1:1 from `SettingsFragment.kt` + `SettingsViewModel.kt`.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _syncing = false;
  String? _syncStatusOverride;
  Color? _syncStatusColor;

  Future<void> _syncNow() async {
    setState(() {
      _syncing = true;
      _syncStatusOverride = 'Syncing...';
      _syncStatusColor = null;
    });

    final result = await ref.read(authRepositoryProvider).syncGoogleCloudNow();
    ref.invalidate(lastSyncTimeProvider);

    if (!mounted) return;
    setState(() {
      _syncing = false;
      if (result is CloudSyncSuccess) {
        _syncStatusOverride = 'Connected & Up to Date';
        _syncStatusColor = AppColors.incomeGreenDark;
      } else if (result is CloudSyncError) {
        _syncStatusOverride = 'Sync Error';
        _syncStatusColor = AppColors.expenseRedDark;
      }
    });

    if (!mounted) return;
    if (result is CloudSyncSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Google Cloud sync complete!')));
    } else if (result is CloudSyncError) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    }
  }

  Future<void> _toggleAppLock(bool enabled) async {
    if (enabled) {
      final auth = LocalAuthentication();
      final supported = await auth.isDeviceSupported();
      if (!supported) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Set up a fingerprint, face, or PIN/pattern screen lock on this device first')),
          );
        }
        return;
      }
    }
    final preferences = ref.read(userPreferencesProvider);
    preferences.isAppLockEnabled = enabled;
    ref.read(appLockEnabledProvider.notifier).state = enabled;
  }

  Future<void> _exportToGmail() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating monthly report for Gmail...')));
    final success = await ref.read(reportExportServiceProvider).exportToGmail();
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to prepare Gmail export')));
    }
  }

  Future<void> _exportCsv() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exporting CSV spreadsheet...')));
    final file = await ref.read(reportExportServiceProvider).exportCsv();
    if (file == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to export CSV')));
    }
  }

  Future<void> _exportPdf() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating PDF report...')));
    final file = await ref.read(reportExportServiceProvider).exportPdf();
    if (file == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to export PDF')));
    }
  }

  Future<void> _resetData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset All Data'),
        content: const Text('This will permanently delete all your transactions. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(transactionRepositoryProvider).deleteAllTransactions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All transactions have been cleared')));
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign Out')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authRepositoryProvider).logout();
      ref.invalidate(userProfileProvider);
      ref.read(appLockSessionUnlockedProvider.notifier).state = false;
      if (mounted) context.go('/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final currencyCode = ref.watch(currencyCodeProvider);
    final currencySymbol = ref.watch(currencySymbolProvider);
    final currencyOption = AppConstants.availableCurrencies.firstWhere(
      (o) => o.code == currencyCode,
      orElse: () => AppConstants.availableCurrencies.first,
    );
    final isDarkMode = ref.watch(darkModeProvider);
    final isAppLockEnabled = ref.watch(appLockEnabledProvider);
    final lastSyncTime = ref.watch(lastSyncTimeProvider).valueOrNull ?? 'Never';

    final initials = profile.name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0])
        .join()
        .toUpperCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(child: Text(initials.isNotEmpty ? initials : 'U')),
              title: Text(profile.name),
              subtitle: Text(profile.email),
              trailing: IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Google Drive Backup & Sync', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Text(_syncStatusOverride ?? 'Not synced yet', style: TextStyle(color: _syncStatusColor)),
                  Text('Last Synced: $lastSyncTime', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _syncing ? null : _syncNow, child: const Text('Sync Now')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Currency'),
                  subtitle: Text(currencyOption.displayName),
                  trailing: Text(currencySymbol),
                  onTap: () => showCurrencyPickerDialog(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Recurring Expenses Manager'),
                  onTap: () => showRecurringManagerDialog(context, ref),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Dark Mode'),
                  value: isDarkMode,
                  onChanged: (value) {
                    ref.read(userPreferencesProvider).isDarkModeEnabled = value;
                    ref.read(darkModeProvider.notifier).state = value;
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('App Lock'),
                  subtitle: const Text('Require biometric/PIN unlock to open the app'),
                  value: isAppLockEnabled,
                  onChanged: _toggleAppLock,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(leading: const Icon(Icons.email_outlined), title: const Text('Export to Gmail'), onTap: _exportToGmail),
                const Divider(height: 1),
                ListTile(leading: const Icon(Icons.table_chart_outlined), title: const Text('Export CSV'), onTap: _exportCsv),
                const Divider(height: 1),
                ListTile(leading: const Icon(Icons.picture_as_pdf_outlined), title: const Text('Export PDF'), onTap: _exportPdf),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _resetData,
            style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error, minimumSize: const Size.fromHeight(48)),
            child: const Text('Reset All Data'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
