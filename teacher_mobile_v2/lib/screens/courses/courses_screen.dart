import 'package:flutter/material.dart';
import '../../core/glass_theme.dart';

class CoursesScreen extends StatelessWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlassTheme.glassAppBar('الكورسات'),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Text(
          'الكورسات',
          style: TextStyle(
            fontSize: 18,
            color: GlassTheme.textPrimary(context),
            fontFamily: 'Cairo',
          ),
        ),
      ),
    );
  }
}
