import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_device_apps/flutter_device_apps.dart';

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
        AppChoice(name: name, packageName: package, iconBytes: iconBytes),
      );
    }

    choices.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    return choices;
  }
}

class AppChoice {
  const AppChoice({
    required this.name,
    required this.packageName,
    this.iconBytes,
  });

  final String name;
  final String packageName;
  final Uint8List? iconBytes;
}
