import 'dart:io';

import 'package:device_apps/device_apps.dart';

class AppPickerService {
  Future<List<AppChoice>> loadInstalledApps() async {
    if (!Platform.isAndroid) {
      return [];
    }

    final apps = await DeviceApps.getInstalledApplications(
      includeSystemApps: false,
      includeAppIcons: false,
    );

    return apps
        .map(
          (app) => AppChoice(name: app.appName, packageName: app.packageName),
        )
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }
}

class AppChoice {
  AppChoice({required this.name, required this.packageName});

  final String name;
  final String packageName;
}
