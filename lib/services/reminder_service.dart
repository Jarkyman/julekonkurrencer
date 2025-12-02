import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone_plus/flutter_timezone_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class ReminderService {
  ReminderService() : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  static const _channelId = 'daily_reminder';
  static const _channelName = 'Daily reminder';
  static const _enabledKey = 'reminders_enabled';
  static const _promptSeenKey = 'reminders_prompt_seen';
  static const _timeHourKey = 'reminders_hour';
  static const _timeMinuteKey = 'reminders_minute';

  /// Initialize local notifications and timezone data.
  Future<void> init() async {
    await _configureLocalTimeZone();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(settings);
  }

  Future<bool> shouldShowOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_promptSeenKey) ?? false);
  }

  Future<void> markOnboardingShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_promptSeenKey, true);
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  /// Ask for notification permission (iOS + Android 13+).
  Future<bool> requestPermission() async {
    final iosImpl =
        _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    final macImpl =
        _plugin.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();
    final androidImpl =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    final iosGranted = await iosImpl?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        true;
    final macGranted = await macImpl?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        true;
    // Available on Android 13+; returns null on older API levels which we treat as granted.
    final androidGranted =
        await androidImpl?.requestNotificationsPermission() ?? true;

    return iosGranted && macGranted && androidGranted;
  }

  Future<void> openSettings() async {
    await openAppSettings();
  }

  Future<void> enableDailyReminders(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, true);
    await prefs.setInt(_timeHourKey, time.hour);
    await prefs.setInt(_timeMinuteKey, time.minute);
    await _scheduleDecemberReminders(time);
  }

  Future<void> disableReminders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
    await prefs.remove(_timeHourKey);
    await prefs.remove(_timeMinuteKey);
    await clearReminders();
  }

  Future<TimeOfDay> currentReminderTime(TimeOfDay fallback) async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt(_timeHourKey);
    final minute = prefs.getInt(_timeMinuteKey);
    if (hour == null || minute == null) return fallback;
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> clearReminders() async {
    // IDs 4001-4031 reserved for December reminders.
    for (var id = 4001; id <= 4031; id++) {
      await _plugin.cancel(id);
    }
  }

  Future<void> _scheduleDecemberReminders(TimeOfDay time) async {
    await clearReminders();

    final now = tz.TZDateTime.now(tz.local);
    final targetYear = now.month == 12 ? now.year : now.year;
    final firstDay = now.month == 12 ? now.day : 1;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Daily reminder to check your calendars.',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    for (var day = firstDay; day <= 31; day++) {
      final scheduled = tz.TZDateTime(
        tz.local,
        targetYear,
        12,
        day,
        time.hour,
        time.minute,
      );

      if (scheduled.isBefore(now)) {
        continue;
      }

      await _plugin.zonedSchedule(
        4000 + day,
        'Husk dine julekalendere',
        'Åbn appen og deltag i dagens konkurrencer.',
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );
    }
  }

  Future<void> _configureLocalTimeZone() async {
    tz.initializeTimeZones();
    try {
      final timeZoneName = await FlutterTimezone.getLocalTimezone();
      if (timeZoneName != null) {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      } else {
        tz.setLocalLocation(tz.getLocation('UTC'));
      }
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }
}
