import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Schedules the local notification for a trip expense's reminder toggle — fires at 9 AM
/// on the expense's target date (or ~1 minute out if that time has already passed by the
/// time it's scheduled). Ported 1:1 from `TripReminderWorker.kt` + `TripReminderScheduler.kt`,
/// using `flutter_local_notifications`' `zonedSchedule` in place of a WorkManager one-time job.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  static const _channelId = 'trip_reminders';
  static const _channelName = 'Trip Reminders';
  static const _channelDescription = 'Reminders for planned trip expenses like bookings and deadlines';

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@drawable/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings);

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Cancels any existing reminder for this expense, then reschedules only if
  /// `reminderEnabled && !isPaid`.
  Future<void> scheduleTripReminder({
    required int expenseId,
    required String title,
    required String tripName,
    required int targetDateMillis,
    required bool reminderEnabled,
    required bool isPaid,
  }) async {
    await cancelReminder(expenseId);
    if (!reminderEnabled || isPaid) return;

    final scheduledDate = _computeFireTime(targetDateMillis);

    await _plugin.zonedSchedule(
      expenseId,
      title,
      'Due today for your $tripName trip',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          priority: Priority.high,
          importance: Importance.high,
          autoCancel: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelReminder(int expenseId) async {
    await _plugin.cancel(expenseId);
  }

  tz.TZDateTime _computeFireTime(int targetDateMillis) {
    final target = DateTime.fromMillisecondsSinceEpoch(targetDateMillis);
    final nineAm = tz.TZDateTime(tz.local, target.year, target.month, target.day, 9, 0, 0);
    final now = tz.TZDateTime.now(tz.local);
    return nineAm.isAfter(now) ? nineAm : now.add(const Duration(minutes: 1));
  }
}
