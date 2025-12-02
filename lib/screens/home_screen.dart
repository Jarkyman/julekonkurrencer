import 'package:flutter/material.dart';

import '../models/advent_calendar_entry.dart';
import '../services/analytics_service.dart';
import '../services/calendar_launcher.dart';
import '../services/calendar_storage.dart';
import 'edit_entry_screen.dart';
import 'predefined_selection_screen.dart';
import '../services/predefined_calendar_loader.dart';
import '../services/reminder_service.dart';
import '../services/done_today_service.dart';
import 'onboarding_screen.dart';

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
  List<AdventCalendarEntry> _entries = [];
  bool _loading = true;
  CalendarType? _filter;
  static const _defaultReminderTime = TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _reminderTime = _defaultReminderTime;

  @override
  void initState() {
    super.initState();
    _loadEntries();
    _initReminders();
  }

  Future<void> _loadEntries() async {
    final entries = await _storage.loadEntries();
    await _doneToday.clearAllNotToday();
    final updated = <AdventCalendarEntry>[];
    for (final entry in entries) {
      final isDone = await _doneToday.isDone(entry.id);
      updated.add(entry.copyWith(doneToday: isDone));
    }
    final hasSeenOnboarding = await _storage.hasSeenOnboarding();
    final predefined =
        hasSeenOnboarding ? <AdventCalendarEntry>[] : await _predefinedLoader.load();

    if (!mounted) return;

    setState(() {
      _entries = _sorted(updated);
      _loading = false;
    });

    if (!hasSeenOnboarding) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startOnboarding(predefined);
      });
    }
  }

  Future<void> _initReminders() async {
    await _reminders.init();
    final seenOnboarding = await _storage.hasSeenOnboarding();
    if (!seenOnboarding) return;
    _reminderTime = await _reminders.currentReminderTime(_defaultReminderTime);
    final enabled = await _reminders.isEnabled();
    if (enabled) {
      final granted = await _reminders.requestPermission();
      if (granted) {
        await _reminders.enableDailyReminders(_reminderTime);
      }
      return;
    }
  }

  List<AdventCalendarEntry> _sorted(List<AdventCalendarEntry> entries) {
    final sorted = [...entries];
    sorted.sort((a, b) {
      if (a.isFavorite != b.isFavorite) {
        return a.isFavorite ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return sorted;
  }

  List<AdventCalendarEntry> _filtered(List<AdventCalendarEntry> entries) {
    if (_filter == null) return entries;
    return entries.where((entry) => entry.type == _filter).toList();
  }

  List<AdventCalendarEntry> _grouped(List<AdventCalendarEntry> entries) {
    final sorted = _sorted(entries);
    final notDone = sorted.where((e) => !e.doneToday).toList();
    final done = sorted.where((e) => e.doneToday).toList();
    return [...notDone, ...done];
  }

  Future<void> _persist() async {
    await _storage.saveEntries(_entries);
  }

  Future<void> _showPredefinedSelection(
    List<AdventCalendarEntry> predefined,
  ) async {
    await _storage.markPredefinedPromptSeen();
    if (!mounted || predefined.isEmpty) {
      return;
    }

    await widget.analytics.logViewPredefinedList();

    final alreadyAddedIds = _entries.map((entry) => entry.id).toSet();
    final selected = await Navigator.of(context).push<List<AdventCalendarEntry>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PredefinedSelectionScreen(
          entries: predefined,
          alreadyAddedIds: alreadyAddedIds,
        ),
      ),
    );

    if (selected == null || selected.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final newOnes = <AdventCalendarEntry>[];

    setState(() {
      for (final entry in selected) {
        final exists = _entries.any((item) => item.id == entry.id);
        if (exists) continue;

        final copy = entry.copyWith(
          isPredefined: true,
          updatedAt: now,
        );
        newOnes.add(copy);
        _entries.add(copy);
      }
      _entries = _sorted(_entries);
    });

    for (final entry in newOnes) {
      await widget.analytics.logAddPredefinedCalendar(entry);
    }

    if (newOnes.isNotEmpty) {
      await _persist();
    }
  }

  Future<void> _startOnboarding(List<AdventCalendarEntry> predefined) async {
    await _storage.markOnboardingSeen();
    await _storage.markPredefinedPromptSeen();
    if (!mounted) return;

    await widget.analytics.logViewPredefinedList();

    final result = await Navigator.of(context).push<OnboardingResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => OnboardingScreen(
          predefined: predefined,
          onOpenSettings: _reminders.openSettings,
          onRequestPermission: _reminders.requestPermission,
        ),
      ),
    );

    if (result == null) return;

    final now = DateTime.now();
    final newEntries = <AdventCalendarEntry>[];
    setState(() {
      for (final entry in result.selectedPredefined) {
        final exists = _entries.any((e) => e.id == entry.id);
        if (exists) continue;
        final copy = entry.copyWith(
          isPredefined: true,
          updatedAt: now,
        );
        newEntries.add(copy);
        _entries.add(copy);
      }
      _entries = _sorted(_entries);
    });

    for (final entry in newEntries) {
      await widget.analytics.logAddPredefinedCalendar(entry);
    }
    if (newEntries.isNotEmpty) {
      await _persist();
    }

    if (result.notificationsEnabled && result.reminderTime != null) {
      final granted = await _reminders.requestPermission();
      if (granted) {
        _reminderTime = result.reminderTime!;
        await _reminders.enableDailyReminders(_reminderTime);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tillad notifikationer i Indstillinger for at få daglige påmindelser.',
            ),
          ),
        );
      }
    }
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
      _entries = _sorted(_entries);
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
    await _launcher.openEntry(context, entry);
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
      _entries = _sorted(_entries);
    });
    if (updated != null) {
      await widget.analytics.logToggleFavorite(updated!);
    }
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    final visibleEntries = _filtered(_entries);

    return Scaffold(
      drawer: _buildDrawer(),
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
          ? _buildEmptyState()
          : Column(
              children: [
                _buildFilters(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _buildListCard(visibleEntries),
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

  Drawer _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ListTile(
              title: Text(
                'Indstillinger',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Påmindelser'),
              onTap: () {
                Navigator.of(context).pop();
                _reminders.openSettings();
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Om appen'),
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_month, size: 72),
            const SizedBox(height: 16),
            const Text(
              'Ingen kalendere endnu',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tilføj dine julekonkurrencer, så du nemt kan åbne dem hver dag.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _openEditor,
              icon: const Icon(Icons.add),
              label: const Text('Tilføj din første'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(CalendarType type) {
    switch (type) {
      case CalendarType.website:
        return Icons.public;
      case CalendarType.app:
        return Icons.phone_iphone;
      case CalendarType.physical:
        return Icons.store_mall_directory;
      case CalendarType.email:
        return Icons.mail_outline;
    }
  }

  Widget _buildFilters() {
    final labelStyle = Theme.of(context).textTheme.labelLarge;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text('Filter:', style: labelStyle),
          ),
          ChoiceChip(
            label: const Text('Alle'),
            selected: _filter == null,
            onSelected: (_) => setState(() => _filter = null),
          ),
          const SizedBox(width: 8),
          ...CalendarType.values.map(
            (type) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(_labelForType(type)),
                selected: _filter == type,
                onSelected: (_) => setState(() => _filter = type),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _labelForType(CalendarType type) {
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

  Widget _buildListCard(List<AdventCalendarEntry> visibleEntries) {
    final items = _grouped(visibleEntries);
    if (items.isEmpty) {
      return Center(
        child: Text(
          'Ingen kalendere matcher filteret.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x15000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: _buildSectionedList(items),
    );
  }

  Widget _buildSectionedList(List<AdventCalendarEntry> items) {
    final doneToday = items.where((e) => e.doneToday).toList();
    final notDone = items.where((e) => !e.doneToday).toList();
    final sections = <_Section>[
      if (notDone.isNotEmpty) _Section(label: 'I dag', entries: notDone),
      if (doneToday.isNotEmpty) _Section(label: 'Færdige i dag', entries: doneToday),
    ];

    final flattened = <_SectionEntry>[];
    for (final section in sections) {
      flattened.add(_SectionEntry.header(section.label));
      flattened.addAll(section.entries.map(_SectionEntry.item));
    }

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
      itemCount: flattened.length,
      onReorder: (oldIndex, newIndex) {
        // Prevent moving headers.
        final from = flattened[oldIndex];
        if (from.isHeader) return;
        if (flattened[newIndex.clamp(0, flattened.length - 1)].isHeader) return;
        if (oldIndex < newIndex) newIndex -= 1;

        final item = from.entry!;
        setState(() {
          _entries = _sorted(_entries);
          final current = List<AdventCalendarEntry>.from(_entries);
          current.removeWhere((e) => e.id == item.id);
          current.insert(newIndex ~/ 2, item); // approximate insert position
          _entries = _sorted(current);
        });
        _persist();
      },
      itemBuilder: (context, index) {
        final entry = flattened[index];
        if (entry.isHeader) {
          return Container(
            key: ValueKey('header-${entry.label}'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              entry.label!,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          );
        }

        final cal = entry.entry!;
        return Dismissible(
          key: ValueKey(cal.id),
          background: _swipeBackground(
            alignment: Alignment.centerLeft,
            icon: Icons.edit,
            color: Colors.blueGrey.shade100,
          ),
          secondaryBackground: _swipeBackground(
            alignment: Alignment.centerRight,
            icon: Icons.delete,
            color: Colors.red.shade100,
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              _openEditor(entry: cal);
              return false;
            } else {
              await _deleteEntry(cal);
              return false;
            }
          },
          child: ReorderableDelayedDragStartListener(
            index: index,
            child: ListTile(
              onTap: () => _openEntry(cal),
              leading: _leadingIcon(cal),
              title: Text(
                cal.name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  decoration: cal.doneToday
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                ),
              ),
              subtitle: Text(
                _secondaryText(cal),
                style: TextStyle(
                  color: Colors.black54,
                  decoration: cal.doneToday
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                ),
              ),
              trailing: IconButton(
                tooltip: cal.isFavorite ? 'Fjern favorit' : 'Markér som favorit',
                icon: Icon(
                  cal.isFavorite ? Icons.star : Icons.star_border_outlined,
                  color: cal.isFavorite
                      ? Theme.of(context).colorScheme.primary
                      : Colors.black54,
                ),
                onPressed: () => _toggleFavorite(cal),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _leadingIcon(AdventCalendarEntry entry) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        entry.doneToday ? Icons.check_circle : _iconForType(entry.type),
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _swipeBackground({
    required Alignment alignment,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: color,
      child: Icon(icon, color: Colors.black54),
    );
  }

  String _secondaryText(AdventCalendarEntry entry) {
    switch (entry.type) {
      case CalendarType.website:
        return 'Webkalender';
      case CalendarType.app:
        return 'App-kalender';
      case CalendarType.physical:
        return entry.location?.isNotEmpty == true
            ? entry.location!
            : 'Fysisk kalender';
      case CalendarType.email:
        return 'E-mail påmindelse';
    }
  }

  Future<void> _markDoneToday(AdventCalendarEntry entry) async {
    await _doneToday.setDone(entry.id, DateTime.now());
    setState(() {
      final index = _entries.indexWhere((e) => e.id == entry.id);
      if (index >= 0) {
        _entries[index] = entry.copyWith(doneToday: true);
      }
      _entries = _sorted(_entries);
    });
  }

}

class _Section {
  _Section({required this.label, required this.entries});
  final String label;
  final List<AdventCalendarEntry> entries;
}

class _SectionEntry {
  _SectionEntry.header(this.label)
      : entry = null,
        isHeader = true;

  _SectionEntry.item(this.entry)
      : label = null,
        isHeader = false;

  final String? label;
  final AdventCalendarEntry? entry;
  final bool isHeader;
}
