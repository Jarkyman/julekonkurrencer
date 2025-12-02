import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/advent_calendar_entry.dart';

class PredefinedCalendarLoader {
  static const _assetPath = 'assets/predefined_calendars.json';

  Future<List<AdventCalendarEntry>> load() async {
    try {
      final content = await rootBundle.loadString(_assetPath);
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      final entries = decoded['entries'] as List<dynamic>? ?? [];

      return entries
          .map(
            (item) => AdventCalendarEntry.fromJson(
              _withLogoFallback(item as Map<String, dynamic>),
            ),
          )
          .toList(growable: false);
    } catch (error) {
      // If parsing fails we return an empty list to avoid crashing startup.
      return [];
    }
  }

  Map<String, dynamic> _withLogoFallback(Map<String, dynamic> json) {
    final logo = json['logo'] ?? json['Logo'] ?? _faviconFromUrl(json['url']);
    return {
      ...json,
      'logo': logo,
    };
  }

  String? _faviconFromUrl(String? url) {
    if (url == null) return null;
    final uri = Uri.tryParse(url);
    final host = uri?.host ?? '';
    if (host.isEmpty) return null;
    return 'https://www.google.com/s2/favicons?domain=$host&sz=128';
  }
}
