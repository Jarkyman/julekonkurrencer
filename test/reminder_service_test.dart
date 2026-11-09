import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:julekonkurrencer/services/reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Restores existing reminders without exact alarm access', () async {
    SharedPreferences.setMockInitialValues({
      'reminders_enabled': true,
      'reminders_hour': 8,
      'reminders_minute': 30,
    });
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    const notifications = MethodChannel(
      'dexterous.com/flutter/local_notifications',
    );
    const timezone = MethodChannel('flutter_timezone');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final schedules = <Map<dynamic, dynamic>>[];
    messenger.setMockMethodCallHandler(
      timezone,
      (_) async => 'Europe/Copenhagen',
    );
    messenger.setMockMethodCallHandler(notifications, (call) async {
      if (call.method == 'initialize') return true;
      if (call.method == 'zonedSchedule') {
        schedules.add(call.arguments as Map<dynamic, dynamic>);
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(timezone, null);
      messenger.setMockMethodCallHandler(notifications, null);
    });

    final reminders = ReminderService();
    await reminders.restoreSchedule();
    await reminders.restoreSchedule();

    expect(
      schedules.map((schedule) => schedule['id']),
      List.generate(31, (index) => 4001 + index),
    );
    expect(
      schedules.map(
        (schedule) => schedule['platformSpecifics']['scheduleMode'],
      ),
      everyElement(AndroidScheduleMode.inexactAllowWhileIdle.name),
    );
    expect(
      await reminders.currentReminderTime(const TimeOfDay(hour: 9, minute: 0)),
      const TimeOfDay(hour: 8, minute: 30),
    );
  });
}
