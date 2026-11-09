import 'package:flutter_test/flutter_test.dart';
import 'package:julekonkurrencer/main.dart';
import 'package:julekonkurrencer/services/analytics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Returning user sees the empty calendar list', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_seen': true});

    await tester.pumpWidget(JulekonkurrencerApp(analytics: AnalyticsService()));
    await tester.pumpAndSettle();

    expect(find.text('Ingen kalendere endnu'), findsOneWidget);
  });
}
