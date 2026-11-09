import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ReminderSettingsResult {
  ReminderSettingsResult({required this.enabled, required this.time});

  final bool enabled;
  final TimeOfDay time;
}

Future<ReminderSettingsResult?> showReminderSettingsSheet({
  required BuildContext context,
  required bool initialEnabled,
  required TimeOfDay initialTime,
}) {
  var localEnabled = initialEnabled;
  var localTime = initialTime;

  return showModalBottomSheet<ReminderSettingsResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Daglig påmindelse',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Switch(
                      value: localEnabled,
                      onChanged: (value) {
                        setSheetState(() => localEnabled = value);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 180,
                  child: IgnorePointer(
                    ignoring: !localEnabled,
                    child: Opacity(
                      opacity: localEnabled ? 1 : 0.35,
                      child: CupertinoTimerPicker(
                        mode: CupertinoTimerPickerMode.hm,
                        initialTimerDuration: Duration(
                          hours: localTime.hour,
                          minutes: localTime.minute,
                        ),
                        onTimerDurationChanged: (duration) {
                          setSheetState(() {
                            localTime = TimeOfDay(
                              hour: duration.inHours % 24,
                              minute: duration.inMinutes % 60,
                            );
                          });
                        },
                      ),
                    ),
                  ),
                ),
                if (localEnabled &&
                    defaultTargetPlatform == TargetPlatform.android)
                  const Text(
                    'Android kan levere påmindelsen lidt efter det valgte tidspunkt.',
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop(
                        ReminderSettingsResult(
                          enabled: localEnabled,
                          time: localTime,
                        ),
                      );
                    },
                    child: const Text('Gem'),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
