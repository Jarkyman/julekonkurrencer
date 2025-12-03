import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'about_dialog.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.onOpenNotifications,
    required this.onOpenPredefined,
    required this.onShowAbout,
    required this.openMapsEnabled,
    required this.onToggleOpenMaps,
  });

  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenPredefined;
  final VoidCallback onShowAbout;
  final bool openMapsEnabled;
  final ValueChanged<bool> onToggleOpenMaps;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                title: const Text('Åbn kort automatisk'),
                subtitle: const Text('Søg efter lokation i Maps'),
                value: openMapsEnabled,
                onChanged: onToggleOpenMaps,
              ),
              ListTile(
                leading: const Icon(Icons.notifications),
                title: const Text('Påmindelser'),
                onTap: () {
                  Navigator.of(context).pop();
                  onOpenNotifications();
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month_outlined),
                title: const Text('Kalender'),
                onTap: () {
                  Navigator.of(context).pop();
                  onOpenPredefined();
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Om appen'),
                onTap: () {
                  Navigator.of(context).pop();
                  showAboutAppDialog(context);
                },
              ),
              const Spacer(),
              Align(
                alignment: Alignment.center,
                child: FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    final info = snapshot.data;
                    final appName = info?.appName ?? 'App';
                    final version = info?.version ?? '';
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            version.isNotEmpty ? '$appName v$version' : appName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Text(
                              'Hartvig Solutions ©',
                              style: TextStyle(fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
