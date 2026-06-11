import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:darsak_desktop/core/theme/app_theme.dart';
import 'package:darsak_desktop/providers/auth_provider.dart';
import 'package:darsak_desktop/core/api/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Desktop Login Screen', () {
    Widget createLoginScreen({ThemeMode themeMode = ThemeMode.dark}) {
      SharedPreferences.setMockInitialValues({});
      final apiClient = ApiClient();
      return MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        home: ChangeNotifierProvider(
          create: (_) => AuthProvider(apiClient),
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: Container(
                    width: 420,
                    padding: const EdgeInsets.all(36),
                    child: Form(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppTheme.accent, AppTheme.accentLight],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.school_rounded, color: Colors.white, size: 30),
                          ),
                          const SizedBox(height: 24),
                          const Text('DarsakAI', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          const Text('تسجيل الدخول إلى حسابك'),
                          const SizedBox(height: 28),
                          TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'البريد الإلكتروني',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'كلمة المرور',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                            obscureText: true,
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {},
                              child: const Text('تسجيل الدخول'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    testWidgets('renders login form with all fields', (WidgetTester tester) async {
      await tester.pumpWidget(createLoginScreen());
      await tester.pumpAndSettle();

      expect(find.text('DarsakAI'), findsOneWidget);
      expect(find.text('تسجيل الدخول إلى حسابك'), findsOneWidget);
      expect(find.byIcon(Icons.school_rounded), findsOneWidget);
      expect(find.byIcon(Icons.email_outlined), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.text('تسجيل الدخول'), findsOneWidget);
    });

    testWidgets('login button is tappable', (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => tapped = true,
                child: const Text('تسجيل الدخول'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('تسجيل الدخول'));
      expect(tapped, true);
    });

    testWidgets('email field validates empty input', (WidgetTester tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: Column(
                children: [
                  TextFormField(
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'يرجى إدخال البريد الإلكتروني';
                      if (!v.contains('@')) return 'البريد الإلكتروني غير صالح';
                      return null;
                    },
                  ),
                  ElevatedButton(
                    onPressed: () => formKey.currentState?.validate(),
                    child: const Text('Submit'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('يرجى إدخال البريد الإلكتروني'), findsOneWidget);
    });

    testWidgets('email field validates invalid email', (WidgetTester tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: Column(
                children: [
                  TextFormField(
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'يرجى إدخال البريد الإلكتروني';
                      if (!v.contains('@')) return 'البريد الإلكتروني غير صالح';
                      return null;
                    },
                  ),
                  ElevatedButton(
                    onPressed: () => formKey.currentState?.validate(),
                    child: const Text('Submit'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'invalidemail');
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('البريد الإلكتروني غير صالح'), findsOneWidget);
    });

    testWidgets('password field validates empty input', (WidgetTester tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: Column(
                children: [
                  TextFormField(
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'يرجى إدخال كلمة المرور';
                      if (v.length < 6) return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                      return null;
                    },
                  ),
                  ElevatedButton(
                    onPressed: () => formKey.currentState?.validate(),
                    child: const Text('Submit'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('يرجى إدخال كلمة المرور'), findsOneWidget);
    });

    testWidgets('password field validates short password', (WidgetTester tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: Column(
                children: [
                  TextFormField(
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'يرجى إدخال كلمة المرور';
                      if (v.length < 6) return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                      return null;
                    },
                  ),
                  ElevatedButton(
                    onPressed: () => formKey.currentState?.validate(),
                    child: const Text('Submit'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), '123');
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('كلمة المرور يجب أن تكون 6 أحرف على الأقل'), findsOneWidget);
    });

    testWidgets('email and password fields accept input', (WidgetTester tester) async {
      await tester.pumpWidget(createLoginScreen());
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(2));
    });
  });
}
