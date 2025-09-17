// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:stepwars_app/main.dart';

void main() {
  testWidgets('StepWars app loads correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const StepWarsApp());

    // Verify that the app loads without crashing.
    // Note: This app requires permissions and Firebase setup,
    // so we just check that it builds without throwing errors.
    await tester.pump();
    
    // The app should build successfully
    expect(find.byType(StepWarsApp), findsOneWidget);
  });
}
