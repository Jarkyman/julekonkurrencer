import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_device_apps/flutter_device_apps.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/advent_calendar_entry.dart';

class CalendarLauncher {
  Future<void> openEntry(
    BuildContext context,
    AdventCalendarEntry entry,
    {required bool openMapsForPhysical}) async {
    switch (entry.type) {
      case CalendarType.website:
        await _openWebsite(context, entry);
        break;
      case CalendarType.app:
        await _openApp(context, entry);
        break;
      case CalendarType.physical:
        await _handlePhysical(context, entry, openMapsForPhysical);
        break;
      case CalendarType.email:
        await _handleEmail();
        break;
    }
  }

  Future<void> _handlePhysical(
    BuildContext context,
    AdventCalendarEntry entry,
    bool openMapsForPhysical,
  ) async {
    final location = entry.location ?? '';
    final opened = await _maybeLaunchMaps(location, openMapsForPhysical);
    if (opened) return;
    if (!context.mounted) return;
    // Ingen popup når maps er slukket; lad caller håndtere done-markering.
  }

  Future<bool> _maybeLaunchMaps(String location, bool enabled) async {
    if (!enabled || location.isEmpty) return false;

    final query = Uri.encodeComponent(location);
    final candidates = [
      Uri.parse('geo:0,0?q=$query'),
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$query'),
      Uri.parse('https://maps.apple.com/?q=$query'),
    ];

    for (final uri in candidates) {
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return true;
      } catch (_) {}
    }
    return false;
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

    if (!context.mounted) return;
    if (!launched) {
      _showSnack(context, 'Kunne ikke åbne linket.');
    }
  }

  Future<void> _openApp(BuildContext context, AdventCalendarEntry entry) async {
    if (Platform.isAndroid && (entry.appPackage ?? '').isNotEmpty) {
      final launched = await FlutterDeviceApps.openApp(entry.appPackage!);
      if (launched) return;
    }

    // Fallback 1: butik fra app/bundle id (kun Android -> Play Store; iOS åbner direkte link).
    String? storeLink;
    if (Platform.isAndroid && (entry.appPackage ?? '').isNotEmpty) {
      storeLink = _storeLinkFromPackage(
        appPackage: entry.appPackage,
        iosBundleId: null,
      );
    }
    final storeUri = _parseUrl(storeLink);
    if (storeUri != null && Platform.isAndroid) {
      final storeLaunched = await launchUrl(
        storeUri,
        mode: LaunchMode.externalApplication,
      );
      if (storeLaunched) return;
    }

    // Fallback 2: deep link / manuel url.
    final uri = _parseUrl(entry.url);
    if (uri == null) {
      if (context.mounted) {
        _showSnack(context, 'Tilføj et link eller app-id for at åbne.');
      }
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!context.mounted) return;
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

  Future<void> _handleEmail(
  ) async {
    if (Platform.isAndroid) {
      final intent = Uri.parse(
        'intent:#Intent;action=android.intent.action.MAIN;category=android.intent.category.APP_EMAIL;end',
      );
      try {
        await launchUrl(intent, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
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

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
