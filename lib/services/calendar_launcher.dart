import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/advent_calendar_entry.dart';

class CalendarLauncher {
  Future<void> openEntry(
    BuildContext context,
    AdventCalendarEntry entry,
  ) async {
    switch (entry.type) {
      case CalendarType.website:
        await _openWebsite(context, entry);
        break;
      case CalendarType.app:
        await _openApp(context, entry);
        break;
      case CalendarType.physical:
        _showInfoSheet(
          context,
          title: entry.name,
          message: entry.location?.isNotEmpty == true
              ? 'Sted: ${entry.location}\n\n${entry.note ?? ''}'.trim()
              : (entry.note?.isNotEmpty == true
                    ? entry.note!
                    : 'Tilføj en note så du husker, hvad der skal gøres.'),
        );
        break;
      case CalendarType.email:
        _showInfoSheet(
          context,
          title: entry.name,
          message: entry.note?.isNotEmpty == true
              ? entry.note!
              : 'Tjek din indbakke for dagens julekonkurrence.',
        );
        break;
    }
  }

  Future<void> _openWebsite(
    BuildContext context,
    AdventCalendarEntry entry,
  ) async {
    final uri = _parseUrl(entry.url);
    if (uri == null) {
      _showSnack(context, 'Ingen URL fundet for denne kalender.');
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched) {
      _showSnack(context, 'Kunne ikke åbne linket.');
    }
  }

  Future<void> _openApp(BuildContext context, AdventCalendarEntry entry) async {
    final link =
        entry.url ??
        _storeLinkFromPackage(
          appPackage: entry.appPackage,
          iosBundleId: entry.iosBundleId,
        );

    final uri = _parseUrl(link);
    if (uri == null) {
      _showSnack(context, 'Tilføj et link eller app-id for at åbne.');
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched) {
      _showSnack(context, 'Kunne ikke åbne app eller butik.');
    }
  }

  String? _storeLinkFromPackage({String? appPackage, String? iosBundleId}) {
    if ((appPackage ?? '').isNotEmpty) {
      return 'https://play.google.com/store/apps/details?id=$appPackage';
    }

    if ((iosBundleId ?? '').isNotEmpty) {
      return 'https://apps.apple.com/app/id$iosBundleId';
    }

    return null;
  }

  Uri? _parseUrl(String? link) {
    if (link == null || link.trim().isEmpty) {
      return null;
    }
    final trimmed = link.trim();
    final hasScheme = Uri.tryParse(trimmed)?.hasScheme ?? false;
    final candidate = hasScheme ? trimmed : 'https://$trimmed';
    final uri = Uri.tryParse(candidate);
    if (uri == null || !(uri.hasScheme && uri.host.isNotEmpty)) {
      return null;
    }
    return uri;
  }

  void _showInfoSheet(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Text(message),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Luk'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
