import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_device_apps/flutter_device_apps.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/advent_calendar_entry.dart';
import '../services/analytics_service.dart';
import '../services/calendar_launcher.dart';
import '../services/calendar_storage.dart';
import '../widgets/widgets.dart';
import '../widgets/reminder_settings_sheet.dart';
import 'edit_entry_screen.dart';
import 'home/home_manager.dart';
import '../services/predefined_calendar_loader.dart';
import '../services/reminder_service.dart';
import '../services/done_today_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.analytics});

  final AnalyticsService analytics;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _storage = CalendarStorage();
  final _launcher = CalendarLauncher();
  final _predefinedLoader = PredefinedCalendarLoader();
  final _reminders = ReminderService();
  final _doneToday = DoneTodayService();
  late final HomeManager _manager;
  bool _manualOrder = false;
  bool _openMapsEnabled = true;
  List<AdventCalendarEntry> _entries = [];
  bool _loading = true;
  CalendarType? _filter;
  static const _defaultReminderTime = TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _reminderTime = _defaultReminderTime;

  @override
  void initState() {
    super.initState();
    _manager = HomeManager(
      storage: _storage,
      predefinedLoader: _predefinedLoader,
      doneToday: _doneToday,
      analytics: widget.analytics,
    );
    _loadEntries();
    _loadOpenSettings();
    _initReminders();
  }

  Future<void> _loadOpenSettings() async {
    final maps = await _storage.mapsOpenEnabled();
    if (!mounted) return;
    setState(() {
      _openMapsEnabled = maps;
    });
  }

  Future<void> _loadEntries() async {
    final result = await _manager.loadEntries();

    if (!mounted) return;

    setState(() {
      _entries = result.entries;
      _loading = false;
      _manualOrder = result.manualOrderEnabled;
    });

    if (!result.hasSeenOnboarding) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startOnboarding(result.predefined);
      });
    }
  }

  Future<void> _initReminders() async {
    await _reminders.init();
    final seenOnboarding = await _storage.hasSeenOnboarding();
    if (!seenOnboarding) return;
    _reminderTime = await _reminders.currentReminderTime(_defaultReminderTime);
  }

  Future<void> _openReminderSettings() async {
    final enabled = await _reminders.isEnabled();
    final currentTime = _reminderTime;

    if (!mounted) return;

    final result = await showReminderSettingsSheet(
      context: context,
      initialEnabled: enabled,
      initialTime: currentTime,
    );

    if (result == null) return;

    if (result.enabled) {
      final granted = await _reminders.requestPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Tillad notifikationer i Indstillinger for påmindelser.',
              ),
            ),
          );
        }
        return;
      }
      await _reminders.enableDailyReminders(result.time);
      setState(() {
        _reminderTime = result.time;
      });
    } else {
      await _reminders.disableReminders();
    }
  }

  Future<void> _persist() async {
    await _storage.saveEntries(_entries);
    await _storage.setManualOrderEnabled(_manualOrder);
  }

  void _alignManualOrder() {
    final favorites = <AdventCalendarEntry>[];
    final others = <AdventCalendarEntry>[];
    for (final entry in _entries) {
      if (entry.doneToday) continue;
      if (entry.isFavorite) {
        favorites.add(entry);
      } else {
        others.add(entry);
      }
    }
    final orderedNotDone = [...favorites, ...others];
    for (var i = 0; i < orderedNotDone.length; i++) {
      orderedNotDone[i] = orderedNotDone[i].copyWith(sortOrder: i);
    }

    final done = _entries.where((e) => e.doneToday).toList();
    _entries = [...orderedNotDone, ...done];
  }

  Future<void> _startOnboarding(List<AdventCalendarEntry> predefined) async {
    if (!mounted) return;
    final outcome = await _manager.startOnboarding(
      context: context,
      predefined: predefined,
      existingEntries: _entries,
      reminders: _reminders,
    );

    if (outcome == null) return;

    if (outcome.reminderTime != null) {
      _reminderTime = outcome.reminderTime!;
    }

    await _addNewEntries(outcome.newEntries);
  }

  Future<void> _openEditor({AdventCalendarEntry? entry}) async {
    final result = await Navigator.of(context).push<AdventCalendarEntry>(
      MaterialPageRoute(builder: (_) => EditEntryScreen(entry: entry)),
    );

    if (result == null) {
      return;
    }

    setState(() {
      final index = _entries.indexWhere((item) => item.id == result.id);
      if (index >= 0) {
        _entries[index] = result;
      } else {
        _entries.add(result);
      }
      if (!_manualOrder) {
        _entries = _manager.sortEntries(_entries);
      } else {
        _alignManualOrder();
      }
    });

    if (entry == null) {
      await widget.analytics.logAddCalendar(result);
    }

    await _persist();
  }

  Future<void> _deleteEntry(AdventCalendarEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Slet kalender'),
          content: Text('Er du sikker på, at du vil slette "${entry.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Fortryd'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Slet'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    setState(() {
      _entries.removeWhere((item) => item.id == entry.id);
    });
    await widget.analytics.logDeleteCalendar(entry);
    await _persist();
  }

  Future<void> _openEntry(AdventCalendarEntry entry) async {
    await _launcher.openEntry(
      context,
      entry,
      openMapsForPhysical: _openMapsEnabled,
    );
    await widget.analytics.logOpenCalendar(entry);
    await _markDoneToday(entry);
  }

  Future<void> _toggleFavorite(AdventCalendarEntry entry) async {
    AdventCalendarEntry? updated;
    setState(() {
      final index = _entries.indexWhere((item) => item.id == entry.id);
      if (index >= 0) {
        updated = entry.copyWith(
          isFavorite: !entry.isFavorite,
          updatedAt: DateTime.now(),
        );
        _entries[index] = updated!;
      }
      if (!_manualOrder) {
        _entries = _manager.sortEntries(_entries);
      } else {
        _alignManualOrder();
      }
    });
    if (updated != null) {
      await widget.analytics.logToggleFavorite(updated!);
    }
    await _persist();
  }

  void _onReorder(List<AdventCalendarEntry> reorderedNotDone) {
    setState(() {
      _manualOrder = true;
      final favorites = reorderedNotDone.where((e) => e.isFavorite).toList();
      final regular = reorderedNotDone.where((e) => !e.isFavorite).toList();
      final orderedNotDone = [...favorites, ...regular];

      for (var i = 0; i < orderedNotDone.length; i++) {
        orderedNotDone[i] = orderedNotDone[i].copyWith(sortOrder: i);
      }

      final done = _entries.where((e) => e.doneToday).toList();
      _entries = [...orderedNotDone, ...done];
    });
    _persist();
  }

  List<CalendarType> _availableTypes(List<AdventCalendarEntry> entries) {
    final types = <CalendarType>{};
    for (final entry in entries) {
      types.add(entry.type);
    }
    return types.toList()..sort(
      (a, b) => _manager.labelForType(a).compareTo(_manager.labelForType(b)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleEntries = _manager.filterByType(_entries, _filter);

    return Scaffold(
      drawer: AppDrawer(
        onOpenNotifications: _openReminderSettings,
        onOpenPredefined: _openPredefinedPicker,
        onShowAbout: () {},
        openMapsEnabled: _openMapsEnabled,
        onToggleOpenMaps: (value) async {
          setState(() => _openMapsEnabled = value);
          await _storage.setMapsOpenEnabled(value);
        },
      ),
      appBar: AppBar(
        title: const Text('Mine kalendere'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
          ? EmptyState(
              icon: Icons.calendar_month,
              title: 'Ingen kalendere endnu',
              message:
                  'Tilføj dine julekonkurrencer, så du nemt kan åbne dem hver dag.',
              actionLabel: 'Tilføj din første',
              onAction: _openEditor,
            )
          : Column(
              children: [
                CalendarFilterBar(
                  selected: _filter,
                  availableTypes: _availableTypes(_entries),
                  onSelected: (value) => setState(() => _filter = value),
                  labelBuilder: _manager.labelForType,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: CalendarListCard(
                      entries: _manager.groupByToday(visibleEntries),
                      allowReorder: _filter == null,
                      onOpen: _openEntry,
                      onEdit: (entry) => _openEditor(entry: entry),
                      onDelete: _deleteEntry,
                      onToggleFavorite: _toggleFavorite,
                      onReorder: _onReorder,
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openEditor,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _markDoneToday(AdventCalendarEntry entry) async {
    await _doneToday.setDone(entry.id, DateTime.now());
    setState(() {
      final index = _entries.indexWhere((e) => e.id == entry.id);
      if (index >= 0) {
        _entries[index] = entry.copyWith(doneToday: true);
      }
      if (!_manualOrder) {
        _entries = _manager.sortEntries(_entries);
      } else {
        _alignManualOrder();
      }
    });
  }

  Future<void> _addNewEntries(List<AdventCalendarEntry> newEntries) async {
    if (newEntries.isEmpty) return;
    setState(() {
      _entries = _manualOrder
          ? [..._entries, ...newEntries]
          : _manager.sortEntries([..._entries, ...newEntries]);
      if (_manualOrder) {
        _alignManualOrder();
      }
    });
    await _persist();
  }

  Future<void> _openPredefinedPicker() async {
    final allPredefined = await _predefinedLoader.load();
    final existingIds = _entries.map((e) => e.id).toSet();
    final available = allPredefined
        .where((entry) => !existingIds.contains(entry.id))
        .toList();
    if (available.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ingen nye kalender at tilføje.')),
        );
      }
      return;
    }

    if (!mounted) return;
    final newOnes = await _manager.selectPredefined(
      context: context,
      predefined: available,
      existingEntries: _entries,
    );

    await _addNewEntries(newOnes);
  }
}
