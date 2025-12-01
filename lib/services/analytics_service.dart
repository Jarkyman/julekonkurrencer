import 'package:firebase_analytics/firebase_analytics.dart';

import '../models/advent_calendar_entry.dart';

class AnalyticsService {
  FirebaseAnalytics? _analytics;

  Future<void> init() async {
    _analytics = FirebaseAnalytics.instance;
  }

  Future<void> logAddCalendar(AdventCalendarEntry entry) async {
    await _analytics?.logEvent(
      name: 'add_calendar',
      parameters: _eventParams(
        entry,
        extra: {'is_predefined': entry.isPredefined},
      ),
    );
  }

  Future<void> logOpenCalendar(AdventCalendarEntry entry) async {
    await _analytics?.logEvent(
      name: 'open_calendar',
      parameters: _eventParams(entry),
    );
  }

  Future<void> logDeleteCalendar(AdventCalendarEntry entry) async {
    await _analytics?.logEvent(
      name: 'delete_calendar',
      parameters: _eventParams(entry),
    );
  }

  Future<void> logToggleFavorite(AdventCalendarEntry entry) async {
    await _analytics?.logEvent(
      name: 'toggle_favorite',
      parameters: _eventParams(entry, extra: {'is_favorite': entry.isFavorite}),
    );
  }

  Map<String, Object> _eventParams(
    AdventCalendarEntry entry, {
    Map<String, Object> extra = const {},
  }) {
    final base = <String, Object>{
      'calendar_id': entry.id,
      'type': entry.type.name,
      'is_predefined': entry.isPredefined ? 1 : 0,
    };

    final normalizedExtra = extra.map(
      (key, value) => MapEntry(key, _normalizeValue(value)),
    );

    return {...base, ...normalizedExtra};
  }

  Object _normalizeValue(Object value) {
    if (value is bool) return value ? 1 : 0;
    if (value is num || value is String) return value;
    return value.toString();
  }
}
