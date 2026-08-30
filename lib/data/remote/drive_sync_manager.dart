import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../local/daos/category_dao.dart';
import '../local/daos/trip_dao.dart';
import '../local/daos/trip_expense_dao.dart';
import '../local/daos/transaction_dao.dart';
import '../local/database.dart';
import '../preferences/user_preferences.dart';

/// Result of a Drive sync/pull operation. Ported from `CloudSyncResult` in `DriveSyncManager.kt`.
sealed class CloudSyncResult {}

class CloudSyncSuccess extends CloudSyncResult {
  final int transactionCount;
  final int categoryCount;
  final bool isNewUser;

  CloudSyncSuccess({required this.transactionCount, required this.categoryCount, required this.isNewUser});
}

class CloudSyncError extends CloudSyncResult {
  final String message;

  CloudSyncError(this.message);
}

/// Real Google Drive backup/restore of transactions, categories, trips, trip expenses, and
/// currency settings, scoped to the signed-in Google account's own Drive `appDataFolder` (a
/// private space only this app — and only that account — can see). Originally ported 1:1
/// from `DriveSyncManager.kt`, then extended at the user's request to also back up trips and
/// trip expenses — the original Kotlin app deliberately excluded those, but this app backs up
/// everything.
///
/// There is no Drive SDK for Dart, so this hand-rolls the same REST calls the original did
/// with `HttpURLConnection`: find/download/create/update a single JSON file. Sync is
/// last-write-wins in both directions — no merge/diff logic.
class DriveSyncManager {
  static const _backupFileName = 'expense_tracker_backup.json';
  static const _filesEndpoint = 'https://www.googleapis.com/drive/v3/files';
  static const _uploadEndpoint = 'https://www.googleapis.com/upload/drive/v3/files';
  static const _maxTimestamp = 9223372036854775807; // Long.MAX_VALUE equivalent

  final TransactionDao transactionDao;
  final CategoryDao categoryDao;
  final TripDao tripDao;
  final TripExpenseDao tripExpenseDao;
  final UserPreferences preferences;

  /// Supplies a short-lived OAuth access token scoped to `drive.appdata`, obtained from
  /// `google_sign_in`'s `GoogleSignInAuthentication.accessToken` — the Flutter equivalent of
  /// the original's `GoogleAuthUtil.getToken(...)` call.
  final Future<String?> Function() getAccessToken;

  final http.Client _client;

  DriveSyncManager({
    required this.transactionDao,
    required this.categoryDao,
    required this.tripDao,
    required this.tripExpenseDao,
    required this.preferences,
    required this.getAccessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<CloudSyncResult> pullUserData(String userEmail) async {
    try {
      final token = await _requireToken();
      final fileId = await _findBackupFileId(token);

      if (fileId != null) {
        final jsonString = await _downloadFile(token, fileId);
        final map = jsonDecode(jsonString) as Map<String, dynamic>;

        final txnMaps = (map['transactions'] as List? ?? const []).cast<Map<String, dynamic>>();
        final catMaps = (map['categories'] as List? ?? const []).cast<Map<String, dynamic>>();
        final tripMaps = (map['trips'] as List? ?? const []).cast<Map<String, dynamic>>();
        final tripExpenseMaps = (map['tripExpenses'] as List? ?? const []).cast<Map<String, dynamic>>();
        final currencySymbol = (map['currencySymbol'] as String?) ?? '';

        // Clear previous local session data to guarantee account isolation.
        await transactionDao.deleteAllTransactions();
        await tripDao.deleteAllTrips();
        await tripExpenseDao.deleteAllExpenses();

        if (txnMaps.isNotEmpty) {
          final companions = txnMaps.map((m) => Transaction.fromJson(m).toCompanion(false)).toList();
          await transactionDao.insertAll(companions);
        }

        if (catMaps.isNotEmpty) {
          final companions = catMaps.map((m) => Category.fromJson(m).toCompanion(false)).toList();
          await categoryDao.insertAll(companions);
        } else {
          await _seedDefaultCategoriesIfEmpty();
        }

        if (tripMaps.isNotEmpty) {
          final companions = tripMaps.map((m) => Trip.fromJson(m).toCompanion(false)).toList();
          await tripDao.insertAll(companions);
        }

        if (tripExpenseMaps.isNotEmpty) {
          final companions = tripExpenseMaps.map((m) => TripExpense.fromJson(m).toCompanion(false)).toList();
          await tripExpenseDao.insertAll(companions);
        }

        if (currencySymbol.isNotEmpty) {
          preferences.currencySymbol = currencySymbol;
        }
        preferences.lastSyncTimestamp = DateTime.now().millisecondsSinceEpoch;

        return CloudSyncSuccess(
          transactionCount: txnMaps.length,
          categoryCount: catMaps.length,
          isNewUser: false,
        );
      } else {
        // First time this Google account has signed in on any device: seed defaults
        // locally and create its Drive backup file.
        await transactionDao.deleteAllTransactions();
        await tripDao.deleteAllTrips();
        await tripExpenseDao.deleteAllExpenses();
        await _seedDefaultCategoriesIfEmpty();
        await pushUserData(userEmail);

        return CloudSyncSuccess(
          transactionCount: 0,
          categoryCount: DefaultCategories.all.length,
          isNewUser: true,
        );
      }
    } catch (e, stackTrace) {
      debugPrint('DriveSyncManager.pullUserData failed: $e\n$stackTrace');
      return CloudSyncError(e.toString());
    }
  }

  /// Set by [pushUserData] on failure so [syncNow] can surface a real error message
  /// instead of a generic one.
  String? lastPushError;

  Future<bool> pushUserData(String userEmail) async {
    if (userEmail.trim().isEmpty) return false;

    try {
      final token = await _requireToken();
      final allTransactions = await transactionDao.getTransactionsBetweenSync(0, _maxTimestamp);
      final allCategories = await categoryDao.getAllCategoriesSync();
      final allTrips = await tripDao.getAllTripsSync();
      final allTripExpenses = await tripExpenseDao.getAllExpensesSync();

      final backupTimestamp = DateTime.now().millisecondsSinceEpoch;
      final payload = {
        'userEmail': userEmail.toLowerCase().trim(),
        'backupTimestamp': backupTimestamp,
        'currencySymbol': preferences.currencySymbol,
        'transactions': allTransactions.map((t) => t.toJson()).toList(),
        'categories': allCategories.map((c) => c.toJson()).toList(),
        'trips': allTrips.map((t) => t.toJson()).toList(),
        'tripExpenses': allTripExpenses.map((e) => e.toJson()).toList(),
      };
      final json = jsonEncode(payload);

      final existingFileId = await _findBackupFileId(token);
      if (existingFileId != null) {
        await _updateFile(token, existingFileId, json);
      } else {
        await _createFile(token, json);
      }

      preferences.lastSyncTimestamp = backupTimestamp;
      lastPushError = null;
      debugPrint('DriveSyncManager.pushUserData succeeded for $userEmail at $backupTimestamp '
          '(${allTransactions.length} transactions, ${allCategories.length} categories, '
          '${allTrips.length} trips, ${allTripExpenses.length} trip expenses)');
      return true;
    } catch (e, stackTrace) {
      lastPushError = e.toString();
      debugPrint('DriveSyncManager.pushUserData failed: $e\n$stackTrace');
      return false;
    }
  }

  Future<CloudSyncResult> syncNow(String userEmail) async {
    final success = await pushUserData(userEmail);
    if (success) {
      final allTxns = await transactionDao.getTransactionsBetweenSync(0, _maxTimestamp);
      return CloudSyncSuccess(transactionCount: allTxns.length, categoryCount: 0, isNewUser: false);
    }
    return CloudSyncError(lastPushError ?? 'Could not sync with Google Drive');
  }

  Future<void> _seedDefaultCategoriesIfEmpty() async {
    if (await categoryDao.getCount() == 0) {
      final companions = DefaultCategories.all
          .map((c) => CategoriesCompanion.insert(
                name: c.name,
                iconName: Value(c.iconName),
                colorHex: Value(c.colorHex),
                type: Value(c.type.storageName),
              ))
          .toList();
      await categoryDao.insertAll(companions);
    }
  }

  String getLastSyncTimeFormatted() {
    final timestamp = preferences.lastSyncTimestamp;
    if (timestamp <= 0) return 'Never';
    return DateFormat("MMM dd, yyyy 'at' hh:mm a").format(DateTime.fromMillisecondsSinceEpoch(timestamp));
  }

  Future<String> _requireToken() async {
    final token = await getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not signed in to Google — please sign in again to grant Drive access.');
    }
    return token;
  }

  Future<String?> _findBackupFileId(String token) async {
    final query = Uri.encodeQueryComponent("name='$_backupFileName' and trashed=false");
    final url = Uri.parse('$_filesEndpoint?spaces=appDataFolder&q=$query&fields=files(id)');
    final response = await _client.get(url, headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final files = (body['files'] as List?) ?? const [];
    if (files.isEmpty) return null;
    return (files.first as Map<String, dynamic>)['id'] as String?;
  }

  Future<String> _downloadFile(String token, String fileId) async {
    final url = Uri.parse('$_filesEndpoint/$fileId?alt=media');
    final response = await _client.get(url, headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Drive download failed: HTTP ${response.statusCode} ${response.body}');
    }
    return response.body;
  }

  Future<String> _createFile(String token, String jsonContent) async {
    final boundary = 'expense_tracker_boundary_${DateTime.now().millisecondsSinceEpoch}';
    final metadata = jsonEncode({
      'name': _backupFileName,
      'parents': ['appDataFolder'],
    });

    final body = StringBuffer()
      ..write('--$boundary\r\n')
      ..write('Content-Type: application/json; charset=UTF-8\r\n\r\n')
      ..write(metadata)
      ..write('\r\n--$boundary\r\n')
      ..write('Content-Type: application/json\r\n\r\n')
      ..write(jsonContent)
      ..write('\r\n--$boundary--');

    final url = Uri.parse('$_uploadEndpoint?uploadType=multipart&fields=id');
    final response = await _client.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'multipart/related; boundary=$boundary',
      },
      body: utf8.encode(body.toString()),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Drive create failed: HTTP ${response.statusCode} ${response.body}');
    }
    return (jsonDecode(response.body) as Map<String, dynamic>)['id'] as String;
  }

  Future<void> _updateFile(String token, String fileId, String jsonContent) async {
    // Plain http POST rejects an actual PATCH verb reliably on some setups, so use the
    // override header Drive's API documents for this case — matches the original's approach.
    final url = Uri.parse('$_uploadEndpoint/$fileId?uploadType=media');
    final response = await _client.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'X-HTTP-Method-Override': 'PATCH',
      },
      body: utf8.encode(jsonContent),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Drive update failed: HTTP ${response.statusCode} ${response.body}');
    }
  }
}
