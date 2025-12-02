import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/advent_calendar_entry.dart';

class CalendarStorage {
  static const _storageKey = 'calendar_entries';
  static const _predefinedSeenKey = 'predefined_seen';

  Future<List<AdventCalendarEntry>> loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map(
            (entry) =>
                AdventCalendarEntry.fromJson(entry as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      await prefs.remove(_storageKey);
      return [];
    }
  }

  Future<void> saveEntries(List<AdventCalendarEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(
      entries.map((entry) => entry.toJson()).toList(growable: false),
    );
    await prefs.setString(_storageKey, payload);
  }

  Future<bool> hasSeenPredefinedPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_predefinedSeenKey) ?? false;
  }

  Future<void> markPredefinedPromptSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_predefinedSeenKey, true);
  }
}
