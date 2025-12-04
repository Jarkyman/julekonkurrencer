import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_device_apps/flutter_device_apps.dart';
import 'package:http/http.dart' as http;

class AppPickerService {
  static Future<List<AppChoice>>? _cache;

  /// Preload apps at startup for faster popups.
  Future<void> warmUp() async {
    if (!Platform.isAndroid) return;
    _cache ??= _loadInstalledApps();
    await _cache;
  }

  Future<List<AppChoice>> loadInstalledApps() async {
    if (!Platform.isAndroid) {
      return const [];
    }
    _cache ??= _loadInstalledApps();
    return _cache!;
  }

  Future<List<AppChoice>> _loadInstalledApps() async {
    final apps = await FlutterDeviceApps.listApps(
      includeSystem: false,
      onlyLaunchable: true,
      includeIcons: true,
    );

    final choices = <AppChoice>[];

    for (final app in apps) {
      final name = app.appName ?? '';
      final package = app.packageName ?? '';
      if (name.isEmpty || package.isEmpty) continue;

      final iconBytes = app.iconBytes;

      choices.add(
        AppChoice(
          name: name,
          packageName: package,
          iconBytes: iconBytes,
        ),
      );
    }

    choices.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    return choices;
  }

  Future<List<AppChoice>> searchIosApps(String term) async {
    if (!Platform.isIOS) return const [];
    final query = Uri.encodeComponent(term.trim().isEmpty ? 'app' : term.trim());
    final url = Uri.parse(
      'https://itunes.apple.com/search?term=$query&country=dk&entity=software&limit=10',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode != 200) return const [];
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final results = decoded['results'] as List<dynamic>? ?? [];
      return results.map((item) {
        final map = item as Map<String, dynamic>;
        final trackName = map['trackName'] as String? ?? '';
        final bundleId = map['bundleId'] as String? ?? '';
        if (trackName.isEmpty || bundleId.isEmpty) {
          return null;
        }
        final trackId = map['trackId']?.toString();
        final iconUrl = map['artworkUrl100'] as String?;
        return AppChoice(
          name: trackName,
          packageName: bundleId,
          iconBytes: null,
          iconUrl: iconUrl,
          iosStoreId: trackId,
        );
      }).whereType<AppChoice>().toList();
    } catch (_) {
      return const [];
    }
  }

  Future<AppChoice?> lookupIosApp(String bundleId) async {
    if (!Platform.isIOS) return null;
    final url = Uri.parse(
      'https://itunes.apple.com/lookup?bundleId=$bundleId&country=dk',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final results = decoded['results'] as List<dynamic>? ?? [];
      if (results.isEmpty) return null;
      final map = results.first as Map<String, dynamic>;
      final trackName = map['trackName'] as String? ?? '';
      final trackId = map['trackId']?.toString();
      final iconUrl = map['artworkUrl100'] as String?;
      return AppChoice(
        name: trackName.isEmpty ? bundleId : trackName,
        packageName: bundleId,
        iconBytes: null,
        iconUrl: iconUrl,
        iosStoreId: trackId,
      );
    } catch (_) {
      return null;
    }
  }
}

class AppChoice {
  const AppChoice({
    required this.name,
    required this.packageName,
    this.iconBytes,
    this.iconUrl,
    this.iosStoreId,
  });

  final String name;
  final String packageName;
  final Uint8List? iconBytes;
  final String? iconUrl;
  final String? iosStoreId;
}
