import 'package:flutter/material.dart';

/// No-op debug overlay. Does nothing.
class DebugOverlay extends StatelessWidget {
  const DebugOverlay({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
