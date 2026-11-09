import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../models/advent_calendar_entry.dart';

class PredefinedCalendarLoader {
  PredefinedCalendarLoader({http.Client? client})
    : _get = client?.get ?? http.get;

  final Future<http.Response> Function(Uri) _get;
  static const _assetPath = 'assets/predefined_calendars.json';
  static const _gistUrl =
      'https://gist.githubusercontent.com/Jarkyman/6bdd0d0b99f06e8f8878b4309a181e82/raw/predefined_calendars.json';

  Future<List<AdventCalendarEntry>> load() async {
    final remoteLoad = _tryLoadFromGist();
    final bundled = await _loadFromAssets();
    final remote = await remoteLoad;
    final bundledDate = bundled?.updatedAt;
    final remoteDate = remote?.updatedAt;
    if (remote != null &&
        (bundledDate == null ||
            (remoteDate != null && !remoteDate.isBefore(bundledDate)))) {
      return remote.entries;
    }
    return bundled?.entries ?? [];
  }

  Future<_CalendarFeed?> _tryLoadFromGist() async {
    try {
      final uri = Uri.parse(_gistUrl);
      final response = await _get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;
      return _parseFeed(utf8.decode(response.bodyBytes));
    } catch (_) {
      return null;
    }
  }

  Future<_CalendarFeed?> _loadFromAssets() async {
    try {
      final content = await rootBundle.loadString(_assetPath);
      return _parseFeed(content);
    } catch (_) {
      return null;
    }
  }

  _CalendarFeed? _parseFeed(String content) {
    final decoded = jsonDecode(content) as Map<String, dynamic>;
    final calendars =
        (decoded['calendars'] as List<dynamic>?) ??
        (decoded['entries'] as List<dynamic>?) ??
        <dynamic>[];

    final entries = calendars
        .map((item) => _toEntry(item as Map<String, dynamic>))
        .whereType<AdventCalendarEntry>()
        .toList(growable: false);
    if (entries.isEmpty) return null;
    final updatedAt = decoded['updatedAt'] ?? decoded['generatedAt'];
    return (
      entries: entries,
      updatedAt: updatedAt is String ? DateTime.tryParse(updatedAt) : null,
    );
  }

  AdventCalendarEntry? _toEntry(Map<String, dynamic> json) {
    final typeName = (json['kind'] ?? json['type'] ?? '').toString();
    final type = _mapKind(typeName);
    if (type == null) return null;

    final logo = json['logo'] ?? json['Logo'] ?? _faviconFromUrl(json['url']);
    final mapped = {
      'id': json['id'],
      'name': json['name'],
      'type': type.name,
      'logo': logo,
      'url': json['url'],
      'appPackage': json['androidPackage'] ?? json['appPackage'],
      'iosBundleId': json['iosBundleId'],
      'iosStoreLink': json['iosStoreLink'] ?? json['iosStorLink'],
      'note': json['note'],
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };

    return AdventCalendarEntry.fromJson(mapped);
  }

  CalendarType? _mapKind(String kind) {
    switch (kind.toLowerCase()) {
      case 'website':
      case 'web':
        return CalendarType.website;
      case 'app':
        return CalendarType.app;
      case 'email':
        return CalendarType.email;
      case 'physical':
        return CalendarType.physical;
      default:
        return null;
    }
  }

  String? _faviconFromUrl(String? url) {
    if (url == null) return null;
    final uri = Uri.tryParse(url);
    final host = uri?.host ?? '';
    if (host.isEmpty) return null;
    return 'https://www.google.com/s2/favicons?domain=$host&sz=128';
  }
}

typedef _CalendarFeed = ({
  List<AdventCalendarEntry> entries,
  DateTime? updatedAt,
});
