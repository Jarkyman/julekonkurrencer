import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/advent_calendar_entry.dart';

class CalendarStorage {
  static const _storageKey = 'calendar_entries';
  static const _predefinedSeenKey = 'predefined_seen';
  static const _onboardingSeenKey = 'onboarding_seen';
  static const _manualOrderKey = 'manual_order_enabled';
  static const _mapsEnabledKey = 'open_maps_enabled';

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

  Future<bool> manualOrderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_manualOrderKey) ?? false;
  }

  Future<void> setManualOrderEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_manualOrderKey, enabled);
  }

  Future<bool> mapsOpenEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_mapsEnabledKey) ?? true;
  }

  Future<void> setMapsOpenEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_mapsEnabledKey, enabled);
  }

  Future<bool> hasSeenPredefinedPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_predefinedSeenKey) ?? false;
  }

  Future<void> markPredefinedPromptSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_predefinedSeenKey, true);
  }

  Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingSeenKey) ?? false;
  }

  Future<void> markOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingSeenKey, true);
  }
}
