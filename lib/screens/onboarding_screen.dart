import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/advent_calendar_entry.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';

class OnboardingResult {
  OnboardingResult({
    required this.selectedPredefined,
    required this.notificationsEnabled,
    this.reminderTime,
  });

  final List<AdventCalendarEntry> selectedPredefined;
  final bool notificationsEnabled;
  final TimeOfDay? reminderTime;
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.predefined,
    this.onOpenSettings,
    this.onRequestPermission,
  });

  final List<AdventCalendarEntry> predefined;
  final Future<void> Function()? onOpenSettings;
  final Future<bool> Function()? onRequestPermission;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with WidgetsBindingObserver {
  final _pageController = PageController();
  final Set<String> _selected = {};
  int _page = 0;
  bool _notificationsAllowed = false;
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  Timer? _pollTimer;

  @override
  void dispose() {
    _pageController.dispose();
    _stopPolling();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _page == 2) {
      _askPermissionIfNeeded();
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = Responsive.screenPadding(context);
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(padding.left, 24, padding.right, 12),
              child: Text(
                'Velkommen til JuleKonkurrencer',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.text.withOpacity(0.7),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                children: [
                  _buildIntro(padding),
                  _buildPredefined(padding),
                  _buildNotifications(padding),
                ],
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildIntro(EdgeInsets padding) {
    return Padding(
      padding: EdgeInsets.fromLTRB(padding.left, 32, padding.right, 24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Text(
            'Velkommen til\nJuleKonkurrencer',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.text,
              fontSize: 26,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Saml alle dine julekonkurrencer ét sted – apps, hjemmesider og fysiske kalendere – så du husker at deltage hver dag.',
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          _primaryButton(label: 'Kom i gang', onPressed: _nextPage),
        ],
      ),
    );
  }

  Widget _buildPredefined(EdgeInsets padding) {
    final entries = widget.predefined;
    return Padding(
      padding: EdgeInsets.fromLTRB(padding.left, 16, padding.right, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Vælg kalendere',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            'Vælg de kalendere du vil følge. Du kan altid tilføje flere senere.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.15,
              ),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                final selected = _selected.contains(entry.id);
                return _PredefinedCard(
                  entry: entry,
                  selected: selected,
                  onTap: () => setState(() {
                    if (selected) {
                      _selected.remove(entry.id);
                    } else {
                      _selected.add(entry.id);
                    }
                  }),
                );
              },
            ),
          ),
          _primaryButton(label: 'Fortsæt', onPressed: _nextPage),
        ],
      ),
    );
  }

  Widget _buildNotifications(EdgeInsets padding) {
    return Padding(
      padding: EdgeInsets.fromLTRB(padding.left, 16, padding.right, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Opsæt påmindelser',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            'Gå ikke glip af noget. Vælg et tidspunkt, så sender vi en daglig påmindelse.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _timePickerCard(),
          const Spacer(),
          _primaryButton(label: 'Færdig', onPressed: _finish),
        ],
      ),
    );
  }

  Widget _timePickerCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.selection.withOpacity(
          _notificationsAllowed ? 0.4 : 0.25,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.selection),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          SizedBox(
            height: 160,
            child: IgnorePointer(
              ignoring: !_notificationsAllowed,
              child: Opacity(
                opacity: _notificationsAllowed ? 1 : 0.35,
                child: CupertinoTimerPicker(
                  mode: CupertinoTimerPickerMode.hm,
                  initialTimerDuration: Duration(
                    hours: _time.hour,
                    minutes: _time.minute,
                  ),
                  onTimerDurationChanged: (duration) {
                    setState(() {
                      _time = TimeOfDay(
                        hour: duration.inHours % 24,
                        minute: duration.inMinutes % 60,
                      );
                    });
                  },
                ),
              ),
            ),
          ),
          if (!_notificationsAllowed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton(
                onPressed: _openSettings,
                child: const Text('Open settings to enable'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              final active = index == _page;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: active ? 18 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _finish() {
    Navigator.of(context).pop(
      OnboardingResult(
        selectedPredefined: _selectedPredefinedEntries(),
        notificationsEnabled: _notificationsAllowed,
        reminderTime: _notificationsAllowed ? _time : null,
      ),
    );
  }

  List<AdventCalendarEntry> _selectedPredefinedEntries() {
    return widget.predefined
        .where((entry) => _selected.contains(entry.id))
        .toList(growable: false);
  }

  void _onPageChanged(int index) {
    setState(() => _page = index);
    if (index == 2) {
      _askPermissionIfNeeded();
      _startPolling();
    } else {
      _stopPolling();
    }
  }

  Future<void> _askPermissionIfNeeded() async {
    bool granted = false;
    if (widget.onRequestPermission != null) {
      granted = await widget.onRequestPermission!();
    }
    if (!granted) {
      final status = await Permission.notification.status;
      granted = status.isGranted || status.isLimited;
    }
    setState(() {
      _notificationsAllowed = granted;
    });

    if (_notificationsAllowed) {
      _stopPolling();
    }
  }

  Future<void> _openSettings() async {
    await widget.onOpenSettings?.call();
    await _askPermissionIfNeeded();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _askPermissionIfNeeded();
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }
}

class _PredefinedCard extends StatelessWidget {
  const _PredefinedCard({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final AdventCalendarEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? AppColors.primary : AppColors.selection;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? AppColors.selection : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
          boxShadow: const [
            BoxShadow(
              color: Color(0x11000000),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LogoOrIcon(entry: entry, selected: selected),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                entry.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoOrIcon extends StatelessWidget {
  const _LogoOrIcon({required this.entry, required this.selected});

  final AdventCalendarEntry entry;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final hasLogo = (entry.logo ?? '').isNotEmpty;
    final border = Border.all(
      color: selected ? AppColors.primary : AppColors.selection,
    );
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.selection,
        borderRadius: BorderRadius.circular(16),
        border: border,
      ),
      clipBehavior: Clip.antiAlias,
      child: hasLogo
          ? Image.network(
              entry.logo!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallbackIcon(),
            )
          : _fallbackIcon(),
    );
  }

  Widget _fallbackIcon() {
    return Icon(_icon(entry.type), color: AppColors.primary, size: 32);
  }

  IconData _icon(CalendarType type) {
    switch (type) {
      case CalendarType.website:
        return Icons.public;
      case CalendarType.app:
        return Icons.phone_iphone;
      case CalendarType.physical:
        return Icons.store_mall_directory;
      case CalendarType.email:
        return Icons.mail_outline;
    }
  }
}
