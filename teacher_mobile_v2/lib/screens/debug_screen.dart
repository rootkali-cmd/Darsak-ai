import 'package:flutter/material.dart';
import '../core/glass_theme.dart';

class DebugScreen extends StatelessWidget {
  const DebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlassTheme.glassAppBar('Debug'),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Text(
          'Debug',
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
