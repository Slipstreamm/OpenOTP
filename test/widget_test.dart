// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:openotp/main.dart';

void main() {
  testWidgets('App starts with empty OTP list', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that we have the empty state message
    expect(find.text('No OTP entries yet. Add one to get started!'), findsOneWidget);

    // Verify that we have an add button
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
