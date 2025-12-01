import 'package:flutter/material.dart';

import '../models/advent_calendar_entry.dart';
import '../services/analytics_service.dart';
import '../services/calendar_launcher.dart';
import '../services/calendar_storage.dart';
import 'edit_entry_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.analytics});

  final AnalyticsService analytics;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _storage = CalendarStorage();
  final _launcher = CalendarLauncher();
  List<AdventCalendarEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final entries = await _storage.loadEntries();
    setState(() {
      _entries = _sorted(entries);
      _loading = false;
    });
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

  Future<void> _persist() async {
    await _storage.saveEntries(_entries);
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
    return Scaffold(
      appBar: AppBar(title: const Text('JuleKonkurrencer')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 96),
              itemBuilder: (context, index) {
                final entry = _entries[index];
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
              itemCount: _entries.length,
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
