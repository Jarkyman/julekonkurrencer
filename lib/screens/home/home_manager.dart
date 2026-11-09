import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/advent_calendar_entry.dart';
import '../../services/analytics_service.dart';
import '../../services/calendar_storage.dart';
import '../../services/done_today_service.dart';
import '../../services/predefined_calendar_loader.dart';
import '../../services/reminder_service.dart';
import '../onboarding_screen.dart';
import '../predefined_selection_screen.dart';

class HomeLoadResult {
  HomeLoadResult({
    required this.entries,
    required this.predefined,
    required this.hasSeenOnboarding,
    required this.manualOrderEnabled,
  });

  final List<AdventCalendarEntry> entries;
  final List<AdventCalendarEntry> predefined;
  final bool hasSeenOnboarding;
  final bool manualOrderEnabled;
}

class OnboardingOutcome {
  OnboardingOutcome({
    required this.newEntries,
    this.reminderTime,
  });

  final List<AdventCalendarEntry> newEntries;
  final TimeOfDay? reminderTime;
}

class HomeManager {
  HomeManager({
    required this.storage,
    required this.predefinedLoader,
    required this.doneToday,
    required this.analytics,
  });

  final CalendarStorage storage;
  final PredefinedCalendarLoader predefinedLoader;
  final DoneTodayService doneToday;
  final AnalyticsService analytics;

  Future<HomeLoadResult> loadEntries() async {
    final entries = await storage.loadEntries();
    final manualOrder = await storage.manualOrderEnabled();
    await doneToday.clearAllNotToday();
    final updated = <AdventCalendarEntry>[];
    for (final entry in entries) {
      final isDone = await doneToday.isDone(entry.id);
      updated.add(entry.copyWith(doneToday: isDone));
    }
    final hasSeenOnboarding = await storage.hasSeenOnboarding();
    final predefined =
        hasSeenOnboarding ? <AdventCalendarEntry>[] : await predefinedLoader.load();

    final ordered = manualOrder ? applyManualOrder(updated) : sortEntries(updated);

    return HomeLoadResult(
      entries: ordered,
      predefined: predefined,
      hasSeenOnboarding: hasSeenOnboarding,
      manualOrderEnabled: manualOrder,
    );
  }

  List<AdventCalendarEntry> sortEntries(List<AdventCalendarEntry> entries) {
    final sorted = [...entries];
    sorted.sort((a, b) {
      if (a.isFavorite != b.isFavorite) {
        return a.isFavorite ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return sorted;
  }

  List<AdventCalendarEntry> applyManualOrder(List<AdventCalendarEntry> entries) {
    final indexed = entries.asMap().entries.toList();
    indexed.sort((a, b) {
      final orderA = a.value.sortOrder;
      final orderB = b.value.sortOrder;
      if (orderA != null && orderB != null) return orderA.compareTo(orderB);
      if (orderA != null) return -1;
      if (orderB != null) return 1;
      return a.key.compareTo(b.key);
    });
    return indexed.map((e) => e.value).toList();
  }

  List<AdventCalendarEntry> filterByType(
    List<AdventCalendarEntry> entries,
    CalendarType? filter,
  ) {
    if (filter == null) return entries;
    return entries.where((entry) => entry.type == filter).toList();
  }

  List<AdventCalendarEntry> groupByToday(List<AdventCalendarEntry> entries) {
    final favorites = <AdventCalendarEntry>[];
    final notFavorites = <AdventCalendarEntry>[];
    final done = <AdventCalendarEntry>[];

    for (final entry in entries) {
      if (entry.doneToday) {
        done.add(entry);
      } else if (entry.isFavorite) {
        favorites.add(entry);
      } else {
        notFavorites.add(entry);
      }
    }

    done.sort((a, b) {
      if (a.isFavorite != b.isFavorite) {
        return a.isFavorite ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return [...favorites, ...notFavorites, ...done];
  }

  String labelForType(CalendarType type) {
    switch (type) {
      case CalendarType.website:
        return 'Web';
      case CalendarType.app:
        return 'App';
      case CalendarType.physical:
        return 'Fysisk';
      case CalendarType.email:
        return 'E-mail';
    }
  }

  String? _chooseInitialAppPackage(AdventCalendarEntry entry) {
    if (!Platform.isAndroid) return entry.appPackage;
    if ((entry.appPackage ?? '').isNotEmpty) {
      return entry.appPackage;
    }
    return null;
  }

  Future<List<AdventCalendarEntry>> selectPredefined({
    required BuildContext context,
    required List<AdventCalendarEntry> predefined,
    required List<AdventCalendarEntry> existingEntries,
  }) async {
    await storage.markPredefinedPromptSeen();
    if (predefined.isEmpty) {
      return [];
    }

    await analytics.logViewPredefinedList();

    if (!context.mounted) return [];
    final alreadyAddedIds = existingEntries.map((entry) => entry.id).toSet();
    final navigator = Navigator.of(context);
    final selected = await navigator.push<List<AdventCalendarEntry>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PredefinedSelectionScreen(
          entries: predefined,
          alreadyAddedIds: alreadyAddedIds,
        ),
      ),
    );

    if (!context.mounted) return [];
    if (selected == null || selected.isEmpty) {
      return [];
    }

    final now = DateTime.now();
    final newEntries = <AdventCalendarEntry>[];

    for (final entry in selected) {
      final exists = existingEntries.any((item) => item.id == entry.id);
      if (exists) continue;

      final copy = entry.copyWith(
        isPredefined: true,
        updatedAt: now,
        appPackage: _chooseInitialAppPackage(entry),
      );
      newEntries.add(copy);
      await analytics.logAddPredefinedCalendar(copy);
    }

    return newEntries;
  }

  Future<OnboardingOutcome?> startOnboarding({
    required BuildContext context,
    required List<AdventCalendarEntry> predefined,
    required List<AdventCalendarEntry> existingEntries,
    required ReminderService reminders,
  }) async {
    await storage.markOnboardingSeen();
    await storage.markPredefinedPromptSeen();

    await analytics.logViewPredefinedList();

    if (!context.mounted) return null;
    final navigator = Navigator.of(context);
    final result = await navigator.push<OnboardingResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => OnboardingScreen(
          predefined: predefined,
          onOpenSettings: reminders.openSettings,
          onRequestPermission: reminders.requestPermission,
        ),
      ),
    );

    if (!context.mounted) return null;
    if (result == null) return null;

    final now = DateTime.now();
    final newEntries = <AdventCalendarEntry>[];
    for (final entry in result.selectedPredefined) {
      final exists = existingEntries.any((e) => e.id == entry.id);
      if (exists) continue;
      final copy = entry.copyWith(
        isPredefined: true,
        updatedAt: now,
        appPackage: _chooseInitialAppPackage(entry),
      );
      newEntries.add(copy);
      await analytics.logAddPredefinedCalendar(copy);
    }

    if (result.notificationsEnabled && result.reminderTime != null) {
      final granted = await reminders.requestPermission();
      if (granted) {
        try {
          await reminders.enableDailyReminders(result.reminderTime!);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Kunne ikke planlægge påmindelser. Prøv igen under Indstillinger.',
                ),
              ),
            );
          }
        }
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tillad notifikationer i Indstillinger for at få daglige påmindelser.',
            ),
          ),
        );
      }
    }

    return OnboardingOutcome(
      newEntries: newEntries,
      reminderTime: result.notificationsEnabled ? result.reminderTime : null,
    );
  }
}
