import 'package:flutter/material.dart';

import '../models/advent_calendar_entry.dart';
import '../theme/app_theme.dart';

class PredefinedCard extends StatelessWidget {
  const PredefinedCard({
    super.key,
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final AdventCalendarEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? AppColors.primary : AppColors.selection;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? AppColors.selection : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
          boxShadow: const [
            BoxShadow(
              color: Color(0x11000000),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PredefinedLogo(entry: entry, selected: selected),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                entry.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PredefinedLogo extends StatelessWidget {
  const PredefinedLogo({super.key, required this.entry, required this.selected});

  final AdventCalendarEntry entry;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final hasLogo = (entry.logo ?? '').isNotEmpty;
    final border = Border.all(
      color: selected ? AppColors.primary : AppColors.selection,
    );
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.selection,
        borderRadius: BorderRadius.circular(16),
        border: border,
      ),
      clipBehavior: Clip.antiAlias,
      child: hasLogo
          ? Image.network(
              entry.logo!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _fallbackIcon(),
            )
          : _fallbackIcon(),
    );
  }

  Widget _fallbackIcon() {
    return Icon(_icon(entry.type), color: AppColors.primary, size: 32);
  }

  IconData _icon(CalendarType type) {
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
