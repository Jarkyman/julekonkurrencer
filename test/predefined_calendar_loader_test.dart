import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:julekonkurrencer/services/predefined_calendar_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  PredefinedCalendarLoader loaderWithFeed(String updatedAt) {
    return PredefinedCalendarLoader(
      client: MockClient((_) async {
        final json = jsonEncode({
          'updatedAt': updatedAt,
          'calendars': [
            {
              'id': 'remote',
              'name': 'Ny julekalender',
              'kind': 'website',
              'url': 'https://example.com',
            },
          ],
        });
        return http.Response.bytes(utf8.encode(json), 200);
      }),
    );
  }

  test('A stale remote feed cannot replace the bundled season', () async {
    final calendars = await loaderWithFeed('2025-12-03T16:30:00Z').load();

    expect(
      calendars.map((calendar) => calendar.id),
      contains('bogide_julekalender_2026'),
    );
  });

  test('A newer remote feed can update the bundled season', () async {
    final calendars = await loaderWithFeed('2026-11-10T00:00:00Z').load();

    expect(calendars.single.name, 'Ny julekalender');
  });

  test('The bundled season is available when the remote feed fails', () async {
    final loader = PredefinedCalendarLoader(
      client: MockClient((_) async => http.Response('', 503)),
    );
    final calendars = await loader.load();

    expect(
      calendars.map((calendar) => calendar.id),
      contains('bogide_julekalender_2026'),
    );
  });
}
