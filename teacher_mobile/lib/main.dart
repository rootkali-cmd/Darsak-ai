import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DarsakTeacherApp());
}

class DarsakTeacherApp extends StatelessWidget {
  const DarsakTeacherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        title: 'DarsakAI Teacher',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFdc2626),
            secondary: Color(0xFFef4444),
            surface: Color(0xFF1a1a2e),
          ),
          scaffoldBackgroundColor: const Color(0xFF0f0f1a),
          cardTheme: const CardThemeData(
            color: Color(0xFF1a1a2e),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1a1a2e),
            elevation: 0,
            centerTitle: true,
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: Color(0xFF1a1a2e),
            selectedItemColor: Color(0xFFdc2626),
            unselectedItemColor: Color(0xFF6b7280),
            type: BottomNavigationBarType.fixed,
          ),
        ),
        home: const SplashScreen(),
        builder: (context, child) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          );
        },
      ),
    );
  }
}
