import 'package:flutter/material.dart';

import '../models/advent_calendar_entry.dart';
import '../services/app_picker.dart';

class EditEntryScreen extends StatefulWidget {
  const EditEntryScreen({super.key, this.entry});

  final AdventCalendarEntry? entry;

  @override
  State<EditEntryScreen> createState() => _EditEntryScreenState();
}

class _EditEntryScreenState extends State<EditEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late final TextEditingController _appPackageController;
  late final TextEditingController _iosBundleController;
  late final TextEditingController _locationController;
  late final TextEditingController _noteController;
  late CalendarType _type;
  final _appPicker = AppPickerService();
  String? _selectedAppPackage;
  String? _selectedAppName;
  bool _loadingApps = false;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _type = entry?.type ?? CalendarType.website;
    _nameController = TextEditingController(text: entry?.name ?? '');
    _urlController = TextEditingController(text: entry?.url ?? '');
    _appPackageController = TextEditingController(
      text: entry?.appPackage ?? '',
    );
    _iosBundleController = TextEditingController(
      text: entry?.iosBundleId ?? '',
    );
    _locationController = TextEditingController(text: entry?.location ?? '');
    _noteController = TextEditingController(text: entry?.note ?? '');
    _selectedAppPackage = entry?.appPackage;
    _selectedAppName = entry?.name;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _appPackageController.dispose();
    _iosBundleController.dispose();
    _locationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.entry != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Rediger kalender' : 'Ny kalender'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Navn',
                  hintText: 'Fx Coop julekalender',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Navn er påkrævet.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<CalendarType>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: CalendarType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(_labelForType(type)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _type = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              ..._buildTypeFields(),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  hintText: 'Sådan deltager du eller andre detaljer',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _onSave,
                  child: const Text('Gem'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTypeFields() {
    switch (_type) {
      case CalendarType.website:
        return [
          TextFormField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'Link',
              hintText: 'https://...',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Link er påkrævet for web-kalendere.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
        ];
      case CalendarType.app:
        return [
          _buildAppPicker(),
          const SizedBox(height: 16),
          TextFormField(
            controller: _iosBundleController,
            decoration: const InputDecoration(
              labelText: 'iOS bundle id (valgfri)',
              hintText: 'com.firma.appnavn',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'Butik eller deep link (valgfri)',
            ),
          ),
        ];
      case CalendarType.physical:
        return [
          TextFormField(
            controller: _locationController,
            decoration: const InputDecoration(
              labelText: 'Lokation',
              hintText: 'Fx SuperBrugsen i Aarhus',
            ),
          ),
        ];
      case CalendarType.email:
        return [];
    }
  }

  void _onSave() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final now = DateTime.now();
    final existing = widget.entry;
    final trimmedName = _nameController.text.trim();

    final payload =
        (existing ?? AdventCalendarEntry.create(name: trimmedName, type: _type))
            .copyWith(
              name: trimmedName,
              type: _type,
              url: _urlController.text.trim().isEmpty
                  ? null
                  : _urlController.text.trim(),
              appPackage: _selectedAppPackage?.isNotEmpty == true
                  ? _selectedAppPackage
                  : null,
              iosBundleId: _iosBundleController.text.trim().isEmpty
                  ? null
                  : _iosBundleController.text.trim(),
              location: _locationController.text.trim().isEmpty
                  ? null
                  : _locationController.text.trim(),
              note: _noteController.text.trim().isEmpty
                  ? null
                  : _noteController.text.trim(),
              updatedAt: now,
            );

    Navigator.of(context).pop(payload);
  }

  Widget _buildAppPicker() {
    final selectionText = _selectedAppPackage == null
        ? 'Ingen app valgt (kun Android)'
        : (_selectedAppName ?? _selectedAppPackage!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                selectionText,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: _loadingApps ? null : _onSelectAppPressed,
              child: _loadingApps
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Vælg app'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Vi kan vise installerede apps på Android. På iOS skal du evt. bruge et link eller note.',
          style: TextStyle(fontSize: 12),
        ),
        if (_selectedAppPackage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Pakke: $_selectedAppPackage',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
      ],
    );
  }

  Future<void> _onSelectAppPressed() async {
    setState(() {
      _loadingApps = true;
    });
    final apps = await _appPicker.loadInstalledApps();
    setState(() {
      _loadingApps = false;
    });

    if (apps.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Kun Android understøtter liste over installerede apps.',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    final choice = await showModalBottomSheet<AppChoice>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final app = apps[index];
            final selected = app.packageName == _selectedAppPackage;
            return ListTile(
              title: Text(app.name),
              subtitle: Text(app.packageName),
              trailing: selected ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(context).pop(app),
            );
          },
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemCount: apps.length,
        );
      },
    );

    if (choice != null) {
      setState(() {
        _selectedAppPackage = choice.packageName;
        _selectedAppName = choice.name;
        _appPackageController.text = choice.packageName;
      });
    }
  }

  String _labelForType(CalendarType type) {
    switch (type) {
      case CalendarType.website:
        return 'Web';
      case CalendarType.app:
        return 'App';
      case CalendarType.physical:
        return 'Fysisk';
      case CalendarType.email:
        return 'E-mail';
    }
  }
}
