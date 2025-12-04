import 'dart:io';
import 'dart:typed_data';

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
  String _appSearch = '';
  Uint8List? _selectedAppIcon;
  String? _selectedAppIconUrl;
  String? _selectedIosStoreId;

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
    _selectedAppName = entry?.appPackage != null ? entry?.name : null;
    _selectedAppIcon = null;
    _selectedAppIconUrl = entry?.logo;
    _selectedIosStoreId = entry?.iosStoreLink;
    _appSearch = _nameController.text;
    _appPicker.warmUp();
    _loadSelectedAppDetails();
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
                initialValue: _type,
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
        return [_buildAppPicker(), const SizedBox(height: 16)];
      case CalendarType.physical:
        return [
          TextFormField(
            controller: _locationController,
            decoration: const InputDecoration(
              labelText: 'Lokation',
              hintText: 'Fx SuperBrugsen i Aarhus',
            ),
          ),
          const SizedBox(height: 16),
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
              iosStoreLink: _selectedIosStoreId?.isNotEmpty == true
                  ? _selectedIosStoreId
                  : null,
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
        ? 'Ingen app valgt'
        : (_selectedAppName ?? _selectedAppPackage!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (_selectedAppIcon != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  _selectedAppIcon!,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                ),
              )
            else if (_selectedAppIconUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  _selectedAppIconUrl!,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _appPlaceholder(),
                ),
              )
            else
              _appPlaceholder(),
            const SizedBox(width: 12),
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
        const SizedBox(height: 8),
      ],
    );
  }

  Future<void> _onSelectAppPressed() async {
    if (Platform.isIOS) {
      await _openIosAppPicker();
      return;
    }
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
    _appSearch = _nameController.text.trim();
    final searchController = TextEditingController(text: _appSearch);
    final choice = await showModalBottomSheet<AppChoice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final query = _appSearch.toLowerCase();
            final filtered = query.isEmpty
                ? apps
                : apps
                      .where(
                        (app) =>
                            app.name.toLowerCase().contains(query) ||
                            app.packageName.toLowerCase().contains(query),
                      )
                      .toList();

            return FractionallySizedBox(
              heightFactor: 0.8,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Søg efter app',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        setSheetState(() => _appSearch = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemBuilder: (context, index) {
                          final app = filtered[index];
                          final selected =
                              app.packageName == _selectedAppPackage;
                          return ListTile(
                            leading: app.iconBytes == null
                                ? const SizedBox.shrink()
                                : SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: Image.memory(
                                      app.iconBytes!,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                            title: Text(app.name),
                            subtitle: Text(app.packageName),
                            trailing: selected ? const Icon(Icons.check) : null,
                            onTap: () => Navigator.of(context).pop(app),
                          );
                        },
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemCount: filtered.length,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (choice != null) {
      setState(() {
        _selectedAppPackage = choice.packageName;
        _selectedAppName = choice.name;
        _selectedAppIcon = choice.iconBytes;
        _appPackageController.text = choice.packageName;
        _selectedIosStoreId = null;
      });
    }
  }

  Future<void> _openIosAppPicker() async {
    setState(() {
      _loadingApps = true;
    });
    List<AppChoice> results = await _appPicker.searchIosApps(
      _nameController.text.trim().isEmpty ? 'app' : _nameController.text.trim(),
    );
    setState(() {
      _loadingApps = false;
    });

    if (!mounted) return;
    _appSearch = _nameController.text.trim();
    final searchController = TextEditingController(text: _appSearch);

    final choice = await showModalBottomSheet<AppChoice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> runSearch(String query) async {
              setSheetState(() => _appSearch = query);
              final fetched = await _appPicker.searchIosApps(query);
              setSheetState(() {
                results = fetched;
              });
            }

            return FractionallySizedBox(
              heightFactor: 0.8,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Søg efter app',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) => runSearch(value),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: results.isEmpty
                          ? const Center(child: Text('Ingen apps fundet'))
                          : ListView.separated(
                              itemBuilder: (context, index) {
                                final app = results[index];
                                final selected =
                                    app.packageName == _selectedAppPackage;
                                return ListTile(
                                  leading: app.iconUrl == null
                                      ? const SizedBox.shrink()
                                      : ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: Image.network(
                                            app.iconUrl!,
                                            width: 32,
                                            height: 32,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const SizedBox.shrink(),
                                          ),
                                        ),
                                  title: Text(app.name),
                                  subtitle: Text(app.packageName),
                                  trailing:
                                      selected ? const Icon(Icons.check) : null,
                                  onTap: () => Navigator.of(context).pop(app),
                                );
                              },
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemCount: results.length,
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (choice != null && mounted) {
      setState(() {
        _selectedAppPackage = choice.packageName;
        _selectedAppName = choice.name;
        _selectedAppIcon = choice.iconBytes;
        _selectedAppIconUrl = choice.iconUrl;
        _appPackageController.text = choice.packageName;
        _iosBundleController.text = choice.packageName;
        if (choice.iosStoreId != null) {
          _selectedIosStoreId = 'id${choice.iosStoreId}';
        } else {
          _selectedIosStoreId = null;
        }
      });
    }
  }

  Future<void> _loadSelectedAppDetails() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    final package = _selectedAppPackage;
    if (package == null || package.isEmpty) return;
    if (Platform.isAndroid) {
      final apps = await _appPicker.loadInstalledApps();
      final match = apps
          .where((a) => a.packageName == package)
          .cast<AppChoice?>()
          .firstWhere((a) => a != null, orElse: () => null);
      if (!mounted || match == null) return;
      setState(() {
        _selectedAppName = match.name;
        _selectedAppIcon = match.iconBytes;
      });
    } else if (Platform.isIOS) {
      final app = await _appPicker.lookupIosApp(package);
      if (!mounted || app == null) return;
      setState(() {
        _selectedAppName = app.name;
        _selectedAppIconUrl = app.iconUrl;
        if (app.iosStoreId != null) {
          _selectedIosStoreId = 'id${app.iosStoreId}';
        }
      });
    }
  }

  Widget _appPlaceholder() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.apps, color: Colors.grey),
    );
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
  Widget _appPlaceholder() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.apps, color: Colors.grey),
    );
  }
