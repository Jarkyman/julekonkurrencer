import 'package:flutter/material.dart';

import '../models/advent_calendar_entry.dart';

class PredefinedSelectionScreen extends StatefulWidget {
  const PredefinedSelectionScreen({
    super.key,
    required this.entries,
    this.alreadyAddedIds = const {},
  });

  final List<AdventCalendarEntry> entries;
  final Set<String> alreadyAddedIds;

  @override
  State<PredefinedSelectionScreen> createState() =>
      _PredefinedSelectionScreenState();
}

class _PredefinedSelectionScreenState
    extends State<PredefinedSelectionScreen> {
  late final Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = {};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vælg dine kalendere'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(<AdventCalendarEntry>[]),
            child: const Text(
              'Spring over',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Tryk på et logo for at vælge de kalendere du allerede bruger.',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 4),
                Text(
                  'Du kan altid tilføje flere senere.',
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.9,
              ),
              itemCount: widget.entries.length,
              itemBuilder: (context, index) {
                final entry = widget.entries[index];
                final disabled = widget.alreadyAddedIds.contains(entry.id);
                final selected = _selectedIds.contains(entry.id);
                return _PredefinedTile(
                  entry: entry,
                  selected: selected,
                  disabled: disabled,
                  onTap: disabled ? null : () => _toggle(entry.id),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selectedIds.isEmpty ? null : _submit,
                  child: Text('Tilføj ${_selectedIds.length} valgte'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggle(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _submit() {
    final chosen = widget.entries
        .where((entry) => _selectedIds.contains(entry.id))
        .toList(growable: false);
    Navigator.of(context).pop(chosen);
  }
}

class _PredefinedTile extends StatelessWidget {
  const _PredefinedTile({
    required this.entry,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final AdventCalendarEntry entry;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        selected ? Theme.of(context).colorScheme.primary : Colors.black12;
    final overlayColor = disabled
        ? Colors.black.withOpacity(0.3)
        : selected
        ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
        : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x11000000),
              blurRadius: 6,
              offset: Offset(0, 3),
            )
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: ColoredBox(
                        color: Colors.grey.shade100,
                        child: _LogoImage(url: entry.logo),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      color: overlayColor,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: selected ? 1 : 0,
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: const Icon(Icons.check, color: Colors.white),
                      ),
                    ),
                  ),
                  if (disabled)
                    const Positioned.fill(
                      child: Center(
                        child: Icon(
                          Icons.lock_outline,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _typeLabel(entry.type),
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(CalendarType type) {
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
}

class _LogoImage extends StatelessWidget {
  const _LogoImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return _fallback();
    }

    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _fallback(),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
    );
  }

  Widget _fallback() {
    return const Center(
      child: Icon(Icons.image_not_supported_outlined, size: 40),
    );
  }
}
