import 'package:flutter/material.dart';

import '../models/advent_calendar_entry.dart';

class CalendarFilterBar extends StatelessWidget {
  const CalendarFilterBar({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.labelBuilder,
    required this.availableTypes,
  });

  final CalendarType? selected;
  final ValueChanged<CalendarType?> onSelected;
  final String Function(CalendarType type) labelBuilder;
  final List<CalendarType> availableTypes;

  @override
  Widget build(BuildContext context) {
    if (availableTypes.isEmpty) {
      return const SizedBox.shrink();
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Icon(Icons.filter_alt_outlined, size: 20),
          ),
          ChoiceChip(
            label: const Text('Alle'),
            selected: selected == null,
            onSelected: (_) => onSelected(null),
          ),
          const SizedBox(width: 8),
          ...availableTypes.map(
            (type) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(labelBuilder(type)),
                selected: selected == type,
                onSelected: (_) => onSelected(type),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
