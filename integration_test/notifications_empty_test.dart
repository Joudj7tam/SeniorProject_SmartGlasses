/*
Integration Test Summary - notifications_empty_test.dart

What this test verifies:
- When there are no notifications returned from the backend, the UI shows an empty state message.

Test case:
- TC_INT2: Open Notifications and verify "No notifications yet." is displayed.

Scope:
- UI empty-state handling (requires backend to return an empty list or no data).
*/

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smartglasses_seniorproject/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TC_INT2: Empty state appears when no notifications exist',
      (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await tester.tap(find.text('Alerts'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text('No notifications yet.'), findsOneWidget);
  });
}
