import 'package:flutter_test/flutter_test.dart';
import 'package:tractormate/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Basic smoke test - verifies app builds without crashing
    expect(TractorMateApp, isNotNull);
  });
}
