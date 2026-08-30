import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants.dart';

class UserProfile {
  final String id;
  final String name;
  final String email;
  final bool isLoggedIn;

  const UserProfile({
    this.id = 'user_current',
    this.name = '',
    this.email = '',
    this.isLoggedIn = false,
  });
}

/// Ported 1:1 from `UserPreferencesManager.kt`. Backed by `shared_preferences`;
/// since that API is async, values are cached in memory after [init] so callers
/// get the same synchronous-feeling get/set surface as the original.
class UserPreferences {
  static const _keyCurrencySymbol = 'key_currency_symbol';
  static const _keyCurrencyCode = 'key_currency_code';
  static const _keyDarkMode = 'key_dark_mode';
  static const _keyAppLockEnabled = 'key_app_lock_enabled';
  static const _keyUserLoggedIn = 'key_user_logged_in';
  static const _keyUserName = 'key_user_name';
  static const _keyUserEmail = 'key_user_email';
  static const _keyLastRecurringSync = 'key_last_recurring_sync';
  static const _keyLastSyncTimestamp = 'key_last_sync_timestamp';

  final SharedPreferences _prefs;

  UserPreferences._(this._prefs);

  static Future<UserPreferences> init() async {
    final prefs = await SharedPreferences.getInstance();
    return UserPreferences._(prefs);
  }

  String get currencySymbol => _prefs.getString(_keyCurrencySymbol) ?? AppConstants.defaultCurrencySymbol;
  set currencySymbol(String value) => _prefs.setString(_keyCurrencySymbol, value);

  String get currencyCode => _prefs.getString(_keyCurrencyCode) ?? AppConstants.defaultCurrencyCode;
  set currencyCode(String value) => _prefs.setString(_keyCurrencyCode, value);

  bool get isDarkModeEnabled => _prefs.getBool(_keyDarkMode) ?? false;
  set isDarkModeEnabled(bool value) => _prefs.setBool(_keyDarkMode, value);

  bool get isAppLockEnabled => _prefs.getBool(_keyAppLockEnabled) ?? false;
  set isAppLockEnabled(bool value) => _prefs.setBool(_keyAppLockEnabled, value);

  bool get isLoggedIn => _prefs.getBool(_keyUserLoggedIn) ?? false;
  set isLoggedIn(bool value) => _prefs.setBool(_keyUserLoggedIn, value);

  String get userName => _prefs.getString(_keyUserName) ?? '';
  set userName(String value) => _prefs.setString(_keyUserName, value);

  String get userEmail => _prefs.getString(_keyUserEmail) ?? '';
  set userEmail(String value) => _prefs.setString(_keyUserEmail, value);

  int get lastRecurringSync => _prefs.getInt(_keyLastRecurringSync) ?? 0;
  set lastRecurringSync(int value) => _prefs.setInt(_keyLastRecurringSync, value);

  int get lastSyncTimestamp => _prefs.getInt(_keyLastSyncTimestamp) ?? 0;
  set lastSyncTimestamp(int value) => _prefs.setInt(_keyLastSyncTimestamp, value);

  UserProfile getUserProfile() {
    return UserProfile(name: userName, email: userEmail, isLoggedIn: isLoggedIn);
  }

  Future<void> saveUserProfile(String name, String email) async {
    await _prefs.setString(_keyUserName, name);
    await _prefs.setString(_keyUserEmail, email);
    await _prefs.setBool(_keyUserLoggedIn, true);
  }

  Future<void> logout() async {
    await _prefs.setBool(_keyUserLoggedIn, false);
  }
}
