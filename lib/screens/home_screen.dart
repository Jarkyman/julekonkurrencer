import 'package:flutter/material.dart';

import '../models/advent_calendar_entry.dart';
import '../services/analytics_service.dart';
import '../services/calendar_launcher.dart';
import '../services/calendar_storage.dart';
import 'edit_entry_screen.dart';
import 'predefined_selection_screen.dart';
import '../services/predefined_calendar_loader.dart';

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
  List<AdventCalendarEntry> _entries = [];
  bool _loading = true;
  CalendarType? _filter;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final entries = await _storage.loadEntries();
    final hasSeenPredefined = await _storage.hasSeenPredefinedPrompt();
    final predefined =
        hasSeenPredefined ? <AdventCalendarEntry>[] : await _predefinedLoader.load();

    if (!mounted) return;

    setState(() {
      _entries = _sorted(entries);
      _loading = false;
    });

    if (!hasSeenPredefined) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPredefinedSelection(predefined);
      });
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
      appBar: AppBar(title: const Text('JuleKonkurrencer')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
          ? _buildEmptyState()
          : Column(
              children: [
                _buildFilters(),
                if (visibleEntries.isEmpty)
                  Expanded(
                    child: Center(
                      child: Text(
                        'Ingen kalendere matcher filteret.',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemBuilder: (context, index) {
                        final entry = visibleEntries[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            child: Icon(_iconForType(entry.type)),
                          ),
                          title: Text(entry.name),
                          subtitle: Text(_secondaryText(entry)),
                          onTap: () => _openEntry(entry),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: entry.isFavorite
                                    ? 'Fjern favorit'
                                    : 'Markér som favorit',
                                icon: Icon(
                                  entry.isFavorite
                                      ? Icons.star
                                      : Icons.star_border_outlined,
                                ),
                                onPressed: () => _toggleFavorite(entry),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  switch (value) {
                                    case 'edit':
                                      _openEditor(entry: entry);
                                      break;
                                    case 'delete':
                                      _deleteEntry(entry);
                                      break;
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Rediger'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Slet'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemCount: visibleEntries.length,
                    ),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openEditor,
        icon: const Icon(Icons.add),
        label: const Text('Tilføj kalender'),
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
}
