import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

Future<void> showAboutAppDialog(BuildContext context) async {
  final info = await PackageInfo.fromPlatform();
  if (!context.mounted) return;

  showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('${info.appName} v${info.version}'),
        content: const Text(
          'JuleKonkurrencer samler dine julekalendere ét sted, så du nemt kan åbne web, apps, fysiske og e-mail kalendere hver dag. '
          'Tilføj egne eller vælg fra listen, markér som favorit, og få daglige påmindelser.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Luk'),
          ),
        ],
      );
    },
  );
}
