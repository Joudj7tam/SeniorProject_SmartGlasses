/*
Integration Test Summary - notifications_error_retry_test.dart

What this test verifies:
- When the backend is unreachable, the Notifications screen shows an error state.
- The user is presented with a "Try again" button (retry UI).

Test case:
- TC_INT3: Open Notifications while backend is down/unreachable and verify error UI is shown.

Scope:
- UI behavior under network/server failure.
*/

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smartglasses_seniorproject/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TC_INT3: Error UI appears when backend unreachable',
      (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await tester.tap(find.text('Alerts'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Should show Try again button
    expect(find.text('Try again'), findsOneWidget);
  });
}
