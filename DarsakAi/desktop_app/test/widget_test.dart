import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:darsak_desktop/core/theme/app_theme.dart';

void main() {
  testWidgets('AppTheme dark creates valid MaterialApp', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(body: Center(child: Text('Test'))),
      ),
    );
    expect(find.text('Test'), findsOneWidget);
  });

  testWidgets('AppTheme light creates valid MaterialApp', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: Center(child: Text('Test'))),
      ),
    );
    expect(find.text('Test'), findsOneWidget);
  });
}
