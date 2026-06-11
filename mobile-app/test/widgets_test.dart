import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:darsak_mobile/main.dart';
import 'package:darsak_mobile/widgets/stat_card.dart';
import 'package:darsak_mobile/widgets/empty_state.dart';
import 'package:darsak_mobile/widgets/error_state.dart';

void main() {
  group('App Entry', () {
    testWidgets('DarsakMobileApp creates MaterialApp', (WidgetTester tester) async {
      await tester.pumpWidget(const DarsakMobileApp());
      await tester.pump();
      expect(find.byType(DarsakMobileApp), findsOneWidget);
    });

    testWidgets('App shows splash screen while loading', (WidgetTester tester) async {
      await tester.pumpWidget(const DarsakMobileApp());
      await tester.pump();
      expect(find.text('DarsakAI'), findsOneWidget);
    });
  });

  group('StatCard Widget', () {
    testWidgets('renders label, value, and icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatCard(
              label: 'الحضور',
              value: '85%',
              icon: Icons.check_circle,
              color: Colors.green,
            ),
          ),
        ),
      );
      expect(find.text('الحضور'), findsOneWidget);
      expect(find.text('85%'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('applies custom valueFontSize', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatCard(
              label: 'Label',
              value: '100',
              icon: Icons.star,
              color: Colors.blue,
              valueFontSize: 24,
            ),
          ),
        ),
      );
      final text = tester.widget<Text>(find.text('100'));
      expect(text.style?.fontSize, 24);
    });
  });

  group('EmptyState Widget', () {
    testWidgets('renders title and icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.inbox,
              title: 'لا توجد بيانات',
            ),
          ),
        ),
      );
      expect(find.text('لا توجد بيانات'), findsOneWidget);
      expect(find.byIcon(Icons.inbox), findsOneWidget);
    });

    testWidgets('renders optional subtitle', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.inbox,
              title: 'لا توجد بيانات',
              subtitle: 'لم تتم إضافة أي عنصر بعد',
            ),
          ),
        ),
      );
      expect(find.text('لم تتم إضافة أي عنصر بعد'), findsOneWidget);
    });

    testWidgets('hides subtitle when null', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.inbox,
              title: 'Title',
            ),
          ),
        ),
      );
      expect(find.byType(Text), findsNWidgets(1));
    });
  });

  group('ErrorState Widget', () {
    testWidgets('renders error message', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorState(message: 'حدث خطأ في الاتصال'),
          ),
        ),
      );
      expect(find.text('حدث خطأ في الاتصال'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });

    testWidgets('shows retry button when onRetry provided', (WidgetTester tester) async {
      bool retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorState(
              message: 'Error',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );
      expect(find.text('إعادة المحاولة'), findsOneWidget);
      await tester.tap(find.text('إعادة المحاولة'));
      expect(retried, true);
    });

    testWidgets('hides retry button when onRetry is null', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorState(message: 'Error'),
          ),
        ),
      );
      expect(find.text('إعادة المحاولة'), findsNothing);
    });
  });
}
