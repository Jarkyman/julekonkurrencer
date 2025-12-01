import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'services/analytics_service.dart';

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
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFB22222),
      brightness: Brightness.light,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'JuleKonkurrencer',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF8F5EF),
        appBarTheme: AppBarTheme(
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
        ),
      ),
      home: HomeScreen(analytics: analytics),
    );
  }
}
