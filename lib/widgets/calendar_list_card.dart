import 'package:flutter/material.dart';

import '../models/advent_calendar_entry.dart';

typedef CalendarEntryCallback =
    Future<void> Function(AdventCalendarEntry entry);
typedef CalendarReorderCallback =
    void Function(List<AdventCalendarEntry> reorderedNotDone);

class CalendarListCard extends StatelessWidget {
  const CalendarListCard({
    super.key,
    required this.entries,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleFavorite,
    required this.onReorder,
    this.allowReorder = true,
  });

  final List<AdventCalendarEntry> entries;
  final CalendarEntryCallback onOpen;
  final CalendarEntryCallback onEdit;
  final CalendarEntryCallback onDelete;
  final CalendarEntryCallback onToggleFavorite;
  final CalendarReorderCallback onReorder;
  final bool allowReorder;

  @override
  Widget build(BuildContext context) {
    final sections = _sections(entries);
    if (sections.isEmpty) {
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
          BoxShadow(
            color: Color(0x15000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: _CalendarSectionedList(
        sections: sections,
        onOpen: onOpen,
        onEdit: onEdit,
        onDelete: onDelete,
        onToggleFavorite: onToggleFavorite,
        onReorder: onReorder,
        allowReorder: allowReorder,
      ),
    );
  }

  List<_Section> _sections(List<AdventCalendarEntry> items) {
    final favorites = items.where((e) => e.isFavorite && !e.doneToday).toList();
    final notDone = items.where((e) => !e.doneToday && !e.isFavorite).toList();
    final doneToday = items.where((e) => e.doneToday).toList();
    return [
      if (favorites.isNotEmpty)
        _Section(label: 'Favoritter', entries: favorites),
      if (notDone.isNotEmpty) _Section(label: 'I dag', entries: notDone),
      if (doneToday.isNotEmpty)
        _Section(label: 'Færdige i dag', entries: doneToday),
    ];
  }
}

class _CalendarSectionedList extends StatelessWidget {
  const _CalendarSectionedList({
    required this.sections,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleFavorite,
    required this.onReorder,
    required this.allowReorder,
  });

  final List<_Section> sections;
  final CalendarEntryCallback onOpen;
  final CalendarEntryCallback onEdit;
  final CalendarEntryCallback onDelete;
  final CalendarEntryCallback onToggleFavorite;
  final CalendarReorderCallback onReorder;
  final bool allowReorder;

  @override
  Widget build(BuildContext context) {
    final flattened = <_SectionEntry>[];
    for (final section in sections) {
      flattened.add(_SectionEntry.header(section.label));
      flattened.addAll(section.entries.map(_SectionEntry.item));
    }

    if (!allowReorder) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
        itemCount: flattened.length,
        itemBuilder: (context, index) => _buildItem(flattened[index], index),
      );
    }

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
      itemCount: flattened.length,
      onReorder: (oldIndex, newIndex) {
        final from = flattened[oldIndex];
        if (from.isHeader || from.entry!.doneToday) return;

        if (oldIndex < newIndex) newIndex -= 1;

        final movingFavorite = from.entry!.isFavorite;

        final favorites = flattened
            .where(
              (item) =>
                  !item.isHeader &&
                  !item.entry!.doneToday &&
                  item.entry!.isFavorite,
            )
            .map((item) => item.entry!)
            .toList();

        final regular = flattened
            .where(
              (item) =>
                  !item.isHeader &&
                  !item.entry!.doneToday &&
                  !item.entry!.isFavorite,
            )
            .map((item) => item.entry!)
            .toList();

        List<AdventCalendarEntry> working = movingFavorite
            ? favorites
            : regular;

        final currentIndex = working.indexWhere((e) => e.id == from.entry!.id);
        if (currentIndex == -1) return;

        // Count how many items in the same section appear before the target slot.
        int targetIndex = 0;
        for (var i = 0; i < flattened.length; i++) {
          if (i == newIndex) break;
          final item = flattened[i];
          if (!item.isHeader &&
              !item.entry!.doneToday &&
              item.entry!.isFavorite == movingFavorite) {
            targetIndex++;
          }
        }

        // If dropping onto a header/done item, place at end of the section.
        final toItem = flattened[newIndex.clamp(0, flattened.length - 1)];
        final sameSection =
            !toItem.isHeader &&
            !toItem.entry!.doneToday &&
            toItem.entry!.isFavorite == movingFavorite;
        if (!sameSection) {
          targetIndex = working.length - 1;
        }

        targetIndex = targetIndex.clamp(0, working.length - 1);

        working = List<AdventCalendarEntry>.from(working);
        final moved = working.removeAt(currentIndex);
        working.insert(targetIndex, moved);

        final reorderedNotDone = movingFavorite
            ? [...working, ...regular]
            : [...favorites, ...working];

        onReorder(reorderedNotDone);
      },
      itemBuilder: (context, index) =>
          _buildItem(flattened[index], index, true),
    );
  }

  Widget _buildItem(_SectionEntry entry, int index, [bool draggable = false]) {
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
    final tile = CalendarListTile(
      entry: cal,
      onTap: () => onOpen(cal),
      onToggleFavorite: () => onToggleFavorite(cal),
    );

    final content = draggable
        ? ReorderableDelayedDragStartListener(index: index, child: tile)
        : tile;

    return Dismissible(
      key: ValueKey(cal.id),
      background: const _SwipeBackground(
        alignment: Alignment.centerLeft,
        icon: Icons.edit,
        color: Color(0xFFE0E7ED),
      ),
      secondaryBackground: const _SwipeBackground(
        alignment: Alignment.centerRight,
        icon: Icons.delete,
        color: Color(0xFFFFE1E1),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await onEdit(cal);
          return false;
        } else {
          await onDelete(cal);
          return false;
        }
      },
      child: content,
    );
  }
}

class CalendarListTile extends StatelessWidget {
  const CalendarListTile({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final AdventCalendarEntry entry;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final textDecoration = entry.doneToday
        ? TextDecoration.lineThrough
        : TextDecoration.none;
    return ListTile(
      onTap: onTap,
      leading: _LeadingIcon(entry: entry),
      title: Text(
        entry.name,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          decoration: textDecoration,
        ),
      ),
      subtitle: Text(
        _secondaryText(entry),
        style: TextStyle(color: Colors.black54, decoration: textDecoration),
      ),
      trailing: IconButton(
        tooltip: entry.isFavorite ? 'Fjern favorit' : 'Markér som favorit',
        icon: Icon(
          entry.isFavorite ? Icons.star : Icons.star_border_outlined,
          color: entry.isFavorite
              ? Theme.of(context).colorScheme.primary
              : Colors.black54,
        ),
        onPressed: onToggleFavorite,
      ),
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
}

class _LeadingIcon extends StatelessWidget {
  const _LeadingIcon({required this.entry});

  final AdventCalendarEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        entry.doneToday ? Icons.check_circle : _iconForType(entry.type),
        color: Theme.of(context).colorScheme.primary,
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
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.icon,
    required this.color,
  });

  final Alignment alignment;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: color,
      child: Icon(icon, color: Colors.black54),
    );
  }
}

class _Section {
  _Section({required this.label, required this.entries});
  final String label;
  final List<AdventCalendarEntry> entries;
}

class _SectionEntry {
  _SectionEntry.header(this.label) : entry = null, isHeader = true;

  _SectionEntry.item(this.entry) : label = null, isHeader = false;

  final String? label;
  final AdventCalendarEntry? entry;
  final bool isHeader;
}
