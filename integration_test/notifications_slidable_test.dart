/*
Integration Test Summary - notifications_slidable_test.dart

What this test suite verifies:
- The Notifications screen can be opened from the Bottom Navigation ("Alerts").
- Each notification item supports swipe (Slidable) actions.
- "Read" Slidable action can be triggered without crashing and keeps the list visible.
- "Delete" Slidable action removes an item from the list (list count decreases).

Test cases:
- TC_INT6: Swipe left on the first notification and tap "Read".
- TC_INT8: Swipe left on the first notification and tap "Delete", then verify the item count decreases.

Scope:
- UI interaction + integration behavior (backend is expected to respond for delete/read actions).
*/

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smartglasses_seniorproject/main.dart' as app;
import 'package:flutter/material.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> openNotifications(WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await tester.tap(find.text('Alerts'));
    await tester.pumpAndSettle(const Duration(seconds: 3));
  }
   testWidgets('TC_INT6: Slidable Read action marks item read', (tester) async {
    await openNotifications(tester);

    final tile = find.byType(ListTile).first;
    expect(tile, findsOneWidget);

    // swipe left to reveal actions
    await tester.drag(tile, const Offset(-350, 0));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // tap Read action label
    await tester.tap(find.text( 'Read').first);
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // no crash + still list visible
    expect(find.byType(ListTile), findsWidgets);
  });

  testWidgets('TC_INT8: Slidable Delete action removes item', (tester) async {
    await openNotifications(tester);

    final before = tester.widgetList(find.byType(ListTile)).length;

    final tile = find.byType(ListTile).first;
    await tester.drag(tile, const Offset(-350, 0));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.text('Delete').first);
    await tester.pumpAndSettle(const Duration(seconds: 4));

    final after = tester.widgetList(find.byType(ListTile)).length;
    expect(after, lessThan(before));
  });
}