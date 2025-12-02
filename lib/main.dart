import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'services/analytics_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final analytics = AnalyticsService();
  await _initFirebase(analytics);
  runApp(JulekonkurrencerApp(analytics: analytics));
}

Future<void> _initFirebase(AnalyticsService analytics) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await analytics.init();
  } catch (error) {
    debugPrint('Firebase init skipped: $error');
  }
}

class JulekonkurrencerApp extends StatelessWidget {
  const JulekonkurrencerApp({super.key, required this.analytics});

  final AnalyticsService analytics;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'JuleKonkurrencer',
      theme: AppTheme.light(),
      home: HomeScreen(analytics: analytics),
    );
  }
}
