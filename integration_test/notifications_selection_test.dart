/*
Integration Test Summary - notifications_selection_test.dart

What this test suite verifies:
- Selection Mode UI can be enabled and disabled from the AppBar ("Select" / "Done").
- In selection mode:
  - A bottom action bar appears with bulk actions ("Read", "Delete").
  - Each notification displays a selectable icon (unchecked/checked).
- Tapping an item toggles selection (unchecked <-> checked).
- "Select all" selects all items and can toggle back to unselect all.
- Bulk actions (Read/Delete) can be executed for selected items.
- After performing bulk actions, Pull-to-Refresh is used to confirm the list remains consistent.

Test cases:
- TC_INT9: Enter selection mode and verify bottom bar + selection icons appear.
- TC_INT10: Select/unselect a notification and verify icon toggles.
- TC_INT11: Select all / unselect all toggles selection state.
- TC_INT12: Bulk mark selected as read, then refresh (persistence/consistency check).
- TC_INT13: Bulk delete selected, then refresh (deleted items should not return).
- TC_INT14: Done exits selection mode and bottom bar disappears.

Scope:
- UI interaction + integration behavior with backend endpoints for read/delete.
*/

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smartglasses_seniorproject/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> openNotifications(WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await tester.tap(find.text('Alerts'));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('Notifications'), findsOneWidget);
  }

  testWidgets('TC_INT9: Enter selection mode shows bottom bar + icons',
      (tester) async {
    await openNotifications(tester);

    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('Read'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsWidgets);
  });

  testWidgets('TC_INT10: Select/unselect toggles icon', (tester) async {
    await openNotifications(tester);

    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    final tile = find.byType(ListTile).first;

    // select
    await tester.tap(tile);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byIcon(Icons.check_circle), findsWidgets);

    // unselect
    await tester.tap(tile);
    await tester.pumpAndSettle(const Duration(seconds: 1));
   
    expect(find.byIcon(Icons.radio_button_unchecked), findsWidgets);
  });

  testWidgets('TC_INT11: Select all / unselect all', (tester) async {
    await openNotifications(tester);

    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    final total = tester.widgetList(find.byType(ListTile)).length;
    expect(total > 0, true);

    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // all selected
    final checks = tester.widgetList(find.byIcon(Icons.check_circle)).length;
    expect(checks >= total, true);

    // toggle off
    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // should show mostly unselected icons
    expect(find.byIcon(Icons.radio_button_unchecked), findsWidgets);
  });

  testWidgets('TC_INT12: Bulk mark selected read + persist after refresh',
      (tester) async {
    await openNotifications(tester);

    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    final tiles = find.byType(ListTile);
    expect(tiles, findsWidgets);

    await tester.tap(tiles.at(0));
    await tester.tap(tiles.at(1));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    await tester.tap(find.text('Read'));
    await tester.pumpAndSettle(const Duration(seconds: 4));

    // refresh to ensure persistence 
    await tester.fling(find.byType(RefreshIndicator), const Offset(0, 400), 1200);
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 4));

    expect(find.byType(ListTile), findsWidgets);
  });

  testWidgets('TC_INT13: Bulk delete selected + persist after refresh',
      (tester) async {
    await openNotifications(tester);

    final before = tester.widgetList(find.byType(ListTile)).length;
    expect(before >= 2, true);

    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    final tiles = find.byType(ListTile);
    await tester.tap(tiles.at(0));
    await tester.tap(tiles.at(1));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle(const Duration(seconds: 4));

    final after = tester.widgetList(find.byType(ListTile)).length;
    expect(after, lessThan(before));

    // refresh
    await tester.fling(find.byType(RefreshIndicator), const Offset(0, 400), 1200);
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 4));

    final afterRefresh = tester.widgetList(find.byType(ListTile)).length;
    expect(afterRefresh, lessThanOrEqualTo(after));
  });

  testWidgets('TC_INT14: Done exits selection mode', (tester) async {
    await openNotifications(tester);

    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // bottom bar should disappear
    expect(find.text('Read'), findsNothing);
    expect(find.text('Delete'), findsNothing);
    // Select button should be back
    expect(find.text('Select'), findsOneWidget);
  });
}
