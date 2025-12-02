import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../models/advent_calendar_entry.dart';

class PredefinedCalendarLoader {
  static const _assetPath = 'assets/predefined_calendars.json';
  static const _gistUrl =
      'https://gist.githubusercontent.com/Jarkyman/6bdd0d0b99f06e8f8878b4309a181e82/raw/predefined_calendars.json';

  Future<List<AdventCalendarEntry>> load() async {
    final fromGist = await _tryLoadFromGist();
    if (fromGist.isNotEmpty) {
      return fromGist;
    }
    return _loadFromAssets();
  }

  Future<List<AdventCalendarEntry>> _tryLoadFromGist() async {
    try {
      final response = await http
          .get(Uri.parse(_gistUrl))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return [];
      return _parseEntries(response.body);
    } catch (_) {
      return [];
    }
  }

  Future<List<AdventCalendarEntry>> _loadFromAssets() async {
    try {
      final content = await rootBundle.loadString(_assetPath);
      return _parseEntries(content);
    } catch (_) {
      return [];
    }
  }

  List<AdventCalendarEntry> _parseEntries(String content) {
    final decoded = jsonDecode(content) as Map<String, dynamic>;
    final entries = decoded['entries'] as List<dynamic>? ?? [];

    return entries
        .map(
          (item) => AdventCalendarEntry.fromJson(
            _withLogoFallback(item as Map<String, dynamic>),
          ),
        )
        .toList(growable: false);
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
