import 'package:google_sign_in/google_sign_in.dart';

import '../preferences/user_preferences.dart';
import '../remote/drive_sync_manager.dart';

/// Handles user authentication state and triggers Google Drive data sync.
/// Ported 1:1 from `AuthRepository.kt`.
class AuthRepository {
  final UserPreferences _preferences;
  final DriveSyncManager _syncManager;

  AuthRepository(this._preferences, this._syncManager);

  UserProfile getCurrentUser() => _preferences.getUserProfile();

  bool isLoggedIn() => _preferences.isLoggedIn;

  Future<UserProfile> handleGoogleSignIn(GoogleSignInAccount account) async {
    final rawEmail = account.email.trim().toLowerCase();
    if (rawEmail.isEmpty) {
      throw StateError('Google account has no email address');
    }
    final name = account.displayName?.isNotEmpty == true
        ? account.displayName!
        : _capitalizeWords(rawEmail.split('@').first.replaceAll('.', ' '));

    await _preferences.saveUserProfile(name, rawEmail);

    // Best-effort restore from this account's private Drive appdata folder. A failure
    // here (e.g. offline) shouldn't block sign-in — the user can retry via "Sync Now".
    await _syncManager.pullUserData(rawEmail);

    return _preferences.getUserProfile();
  }

  Future<CloudSyncResult> syncGoogleCloudNow() {
    return _syncManager.syncNow(_preferences.userEmail);
  }

  String getLastSyncTime() => _syncManager.getLastSyncTimeFormatted();

  Future<void> logout() => _preferences.logout();

  String _capitalizeWords(String input) {
    return input
        .split(' ')
        .map((word) => word.isEmpty ? word : word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }
}
