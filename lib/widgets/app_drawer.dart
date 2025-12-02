import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.onOpenNotifications,
    required this.onShowAbout,
  });

  final VoidCallback onOpenNotifications;
  final VoidCallback onShowAbout;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ListTile(
              title: Text(
                'Indstillinger',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
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
              leading: const Icon(Icons.info_outline),
              title: const Text('Om appen'),
              onTap: () {
                Navigator.of(context).pop();
                onShowAbout();
              },
            ),
          ],
        ),
      ),
    );
  }
}
