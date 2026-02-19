import 'package:flutter_test/flutter_test.dart';
import 'package:elongacion_musical/main.dart';
import 'package:elongacion_musical/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final settingsService = await SettingsService.init();

    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(settingsService: settingsService));

    // Verify that the app builds (Menu Screen usually shows up)
    // We can just check for something generic or just that it doesn't crash
    expect(find.byType(MyApp), findsOneWidget);
  });
}
