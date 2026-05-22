import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:darsak_desktop/main.dart';

void main() {
  testWidgets('App loads correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const DarsakApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
