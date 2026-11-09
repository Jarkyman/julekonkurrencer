import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class ReminderService {
  ReminderService() : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _initialization;
  static const _channelId = 'daily_reminder';
  static const _channelName = 'Daily reminder';
  static const _enabledKey = 'reminders_enabled';
  static const _promptSeenKey = 'reminders_prompt_seen';
  static const _timeHourKey = 'reminders_hour';
  static const _timeMinuteKey = 'reminders_minute';
  static const _scheduledTimeZoneKey = 'reminders_scheduled_time_zone';

  Future<void> init() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    await _configureLocalTimeZone();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(settings: settings);
  }

  Future<void> restoreSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_enabledKey) != true) return;
    await init();
    if (prefs.getString(_scheduledTimeZoneKey) == tz.local.name) return;
    final time = await currentReminderTime(const TimeOfDay(hour: 9, minute: 0));
    await enableDailyReminders(time);
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
    await init();
    final iosImpl = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final macImpl = _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    final iosGranted =
        await iosImpl?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        true;
    final macGranted =
        await macImpl?.requestPermissions(
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
    await init();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_scheduledTimeZoneKey);
    try {
      await _scheduleDecemberReminders(time);
    } catch (_) {
      await _clearReminders();
      rethrow;
    }
    await prefs.setInt(_timeHourKey, time.hour);
    await prefs.setInt(_timeMinuteKey, time.minute);
    await prefs.setBool(_enabledKey, true);
    await prefs.setString(_scheduledTimeZoneKey, tz.local.name);
  }

  Future<void> disableReminders() async {
    await init();
    await _clearReminders();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
    await prefs.remove(_timeHourKey);
    await prefs.remove(_timeMinuteKey);
    await prefs.remove(_scheduledTimeZoneKey);
  }

  Future<TimeOfDay> currentReminderTime(TimeOfDay fallback) async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt(_timeHourKey);
    final minute = prefs.getInt(_timeMinuteKey);
    if (hour == null || minute == null) return fallback;
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> _clearReminders() async {
    // IDs 4001-4031 reserved for December reminders.
    for (var id = 4001; id <= 4031; id++) {
      await _plugin.cancel(id: id);
    }
  }

  Future<void> _scheduleDecemberReminders(TimeOfDay time) async {
    final now = tz.TZDateTime.now(tz.local);

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

    for (var day = 1; day <= 31; day++) {
      var scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        12,
        day,
        time.hour,
        time.minute,
      );

      if (!scheduled.isAfter(now)) {
        scheduled = tz.TZDateTime(
          tz.local,
          now.year + 1,
          12,
          day,
          time.hour,
          time.minute,
        );
      }

      await _plugin.zonedSchedule(
        id: 4000 + day,
        title: 'Husk dine julekalendere',
        body: 'Åbn appen og deltag i dagens konkurrencer.',
        scheduledDate: scheduled,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );
    }
  }

  Future<void> _configureLocalTimeZone() async {
    tz.initializeTimeZones();
    var location = tz.getLocation('Europe/Copenhagen');
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      location = tz.timeZoneDatabase.locations[timezone.identifier] ?? location;
    } on PlatformException {
      // Use the default Danish timezone if the device lookup fails.
    } on MissingPluginException {
      // Native plugins are unavailable in widget tests.
    }
    tz.setLocalLocation(location);
  }
}
