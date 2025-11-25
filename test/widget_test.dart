import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartglasses_seniorproject/main.dart';

void main() {
  testWidgets('ColorChanger widget smoke test', (WidgetTester tester) async {
    // Build the app
    await tester.pumpWidget(const SmartGlassesApp());

    // Verify initial color container is blue
    final containerFinder = find.byType(Container).first;
    Container container = tester.widget(containerFinder);
    expect(container.color, Colors.blue);

    // Tap the button
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    // Verify color changed to green
    container = tester.widget(containerFinder);
    expect(container.color, Colors.green);
  });
}
