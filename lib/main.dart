import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'app_providers.dart';
import 'data/preferences/user_preferences.dart';
import 'services/notifications/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferences = await UserPreferences.init();
  try {
    // Notification setup must never block the app from starting — a failure here (e.g. a
    // misconfigured icon resource) would otherwise throw before runApp(), leaving the
    // native splash screen on-screen forever with no visible error.
    await NotificationService.instance.init();
  } catch (error, stackTrace) {
    debugPrint('NotificationService.init failed (continuing without it): $error\n$stackTrace');
  }

  runApp(
    ProviderScope(
      overrides: [
        userPreferencesProvider.overrideWithValue(preferences),
      ],
      child: const ExpenseTrackerApp(),
    ),
  );
}
