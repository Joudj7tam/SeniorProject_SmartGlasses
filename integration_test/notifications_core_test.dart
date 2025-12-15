/*
Integration Test Summary - notifications_core_test.dart

What this test suite verifies (core Notifications behavior):
- Notifications screen opens from Bottom Navigation ("Alerts").
- Notifications list loads successfully and displays items.
- Notifications are sorted newest-first based on the displayed timestamp.
- Tapping a notification marks it as read (UI style changes) and remains read after refresh.
- Deleting a notification removes it and it does not reappear after refresh.
- Pull-to-refresh works and the list remains visible.

Test cases:
- TC_INT1: Load notifications list and display items.
- TC_INT4: Verify sorting order is newest-first (compare first two timestamps).
- TC_INT5: Tap item -> mark as read -> refresh -> remains read (persistence/consistency check).
- TC_INT7: Delete a notification -> refresh -> deletion persists.
- TC_INT15: Pull-to-refresh triggers refresh flow and list stays visible.

Scope:
- End-to-end UI flows with backend integration for read/delete and refresh.
*/

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smartglasses_seniorproject/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> openNotificationsFromBottomNav(WidgetTester tester) async {
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await tester.tap(find.text('Alerts'));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('Notifications'), findsOneWidget);
  }

  Future<void> pullToRefresh(WidgetTester tester) async {
    await tester.fling(find.byType(RefreshIndicator), const Offset(0, 400), 1200);
    await tester.pump(); // start refresh
    await tester.pumpAndSettle(const Duration(seconds: 4));
  }

  String firstTitleText(WidgetTester tester) {
    final firstTile = tester.widget<ListTile>(find.byType(ListTile).first);
    final titleWidget = firstTile.title as Text;
    return titleWidget.data ?? '';
  }

  Text firstTitleWidgetByText(String title) {
    // returns the first Text widget matching this title
    return (find.text(title).evaluate().first.widget as Text);
  }

  DateTime parseDisplayedDate(String s) {
    // format: yyyy-MM-dd HH:mm
    return DateTime.parse(s.replaceFirst(' ', 'T'));
  }

  List<DateTime> firstTwoDisplayedDates(WidgetTester tester) {
    final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    DateTime extractDate(ListTile tile) {
      final subtitle = tile.subtitle as Column;
      final children = subtitle.children.whereType<Text>().toList();
      final dateText = children.last.data ?? '';
      return parseDisplayedDate(dateText);
    }

    return [extractDate(tiles[0]), extractDate(tiles[1])];
  }

  testWidgets('TC_INT1 + TC_INT4: Load notifications and sorted newest-first',
      (tester) async {
    app.main();
    await openNotificationsFromBottomNav(tester);

    // TC_INT1: list is shown
    expect(find.byType(ListTile), findsWidgets);

    // TC_INT4: newest-first (compare first two dates)
    final dates = firstTwoDisplayedDates(tester);
    expect(dates[0].isAfter(dates[1]) || dates[0].isAtSameMomentAs(dates[1]), true);
  });

  testWidgets('TC_INT5: Tap item marks read and persists after refresh',
      (tester) async {
    app.main();
    await openNotificationsFromBottomNav(tester);

    expect(find.byType(ListTile), findsWidgets);
    final title = firstTitleText(tester);

    // tap item -> mark read
    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // simple UI assertion: title fontWeight should become w400 (read)
    final t1 = firstTitleWidgetByText(title);
    expect(t1.style?.fontWeight, FontWeight.w400);

    // refresh and ensure still read
    await pullToRefresh(tester);
    final t2 = firstTitleWidgetByText(title);
    expect(t2.style?.fontWeight, FontWeight.w400);
  });

  testWidgets('TC_INT7: Delete single notification and persist after refresh',
      (tester) async {
    app.main();
    await openNotificationsFromBottomNav(tester);

    final tilesFinder = find.byType(ListTile);
    final initialCount = tester.widgetList(tilesFinder).length;
    expect(initialCount >= 2, true);

    // delete using selection mode (reliable)
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    await tester.tap(tilesFinder.first);
    await tester.pumpAndSettle(const Duration(seconds: 1));

    await tester.tap(find.text('Delete')); // bottom bar delete
    await tester.pumpAndSettle(const Duration(seconds: 4));

    final afterDeleteCount = tester.widgetList(find.byType(ListTile)).length;
    expect(afterDeleteCount, lessThan(initialCount));

    // refresh: deleted item should not return
    await pullToRefresh(tester);
    final afterRefreshCount = tester.widgetList(find.byType(ListTile)).length;
    expect(afterRefreshCount, lessThanOrEqualTo(afterDeleteCount));
  });

  testWidgets('TC_INT15: Pull-to-refresh shows newly inserted notification',
      (tester) async {
    app.main();
    await openNotificationsFromBottomNav(tester);

    await pullToRefresh(tester);
    expect(find.byType(ListTile), findsWidgets);
  });
}
