import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:darsak_mobile/screens/login_screen.dart';
import 'package:darsak_mobile/providers/auth_provider.dart';
import 'package:darsak_mobile/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget createLoginScreen({String? teacherCode}) {
  SharedPreferences.setMockInitialValues({});
  return MaterialApp(
    home: MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: LoginScreen(teacherCode: teacherCode),
    ),
  );
}

void main() {
  group('LoginScreen', () {
    testWidgets('renders login form with code and PIN fields', (WidgetTester tester) async {
      await tester.pumpWidget(createLoginScreen());
      await tester.pumpAndSettle();

      expect(find.text('تسجيل دخول الطالب'), findsOneWidget);
      expect(find.text('أدخل كود الطالب ورقم PIN السري'), findsOneWidget);
      expect(find.byIcon(Icons.badge), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);
      expect(find.text('تسجيل الدخول'), findsOneWidget);
    });

    testWidgets('shows teacher barcode link when no teacherCode', (WidgetTester tester) async {
      await tester.pumpWidget(createLoginScreen());
      await tester.pumpAndSettle();
      expect(find.text('تسجيل عبر باركود المعلم'), findsOneWidget);
    });

    testWidgets('hides teacher barcode link when teacherCode provided', (WidgetTester tester) async {
      await tester.pumpWidget(createLoginScreen(teacherCode: 'TCH-123'));
      await tester.pumpAndSettle();
      expect(find.text('تسجيل عبر باركود المعلم'), findsNothing);
      expect(find.text('مرحباً بك في DarsakAI'), findsOneWidget);
    });

    testWidgets('validates empty code field', (WidgetTester tester) async {
      await tester.pumpWidget(createLoginScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('تسجيل الدخول'));
      await tester.pumpAndSettle();

      expect(find.text('هذا الحقل مطلوب'), findsWidgets);
    });

    testWidgets('validates empty PIN field', (WidgetTester tester) async {
      await tester.pumpWidget(createLoginScreen());
      await tester.pumpAndSettle();

      final codeField = find.byType(TextFormField).first;
      await tester.enterText(codeField, 'ST001');
      await tester.tap(find.text('تسجيل الدخول'));
      await tester.pumpAndSettle();

      expect(find.text('هذا الحقل مطلوب'), findsWidgets);
    });

    testWidgets('validates PIN length (6-8 chars)', (WidgetTester tester) async {
      await tester.pumpWidget(createLoginScreen());
      await tester.pumpAndSettle();

      final codeField = find.byType(TextFormField).first;
      final pinField = find.byType(TextFormField).last;
      await tester.enterText(codeField, 'ST001');
      await tester.enterText(pinField, '123');
      await tester.tap(find.text('تسجيل الدخول'));
      await tester.pumpAndSettle();

      expect(find.text('PIN يجب أن يكون 6-8 أحرف وأرقام'), findsOneWidget);
    });

    testWidgets('PIN field only accepts alphanumeric characters', (WidgetTester tester) async {
      await tester.pumpWidget(createLoginScreen());
      await tester.pumpAndSettle();

      final pinField = find.byType(TextFormField).last;
      await tester.enterText(pinField, '12345!@#');
      final text = tester.widget<TextFormField>(pinField);
      expect(text.controller?.text, '12345');
    });

    testWidgets('login button is enabled initially', (WidgetTester tester) async {
      await tester.pumpWidget(createLoginScreen());
      await tester.pumpAndSettle();

      final button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton).first,
      );
      expect(button.onPressed, isNotNull);
    });
  });
}
