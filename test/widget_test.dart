// This is a basic Flutter widget test.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astraa/main.dart';

void main() {
  testWidgets('App starts without crashing', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const AstraApp());
    
    // Verify the app builds successfully
    expect(find.byType(Scaffold), findsWidgets);
  });
}
