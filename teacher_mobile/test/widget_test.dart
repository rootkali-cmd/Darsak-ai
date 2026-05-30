import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:darsak_teacher/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const DarsakTeacherApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
