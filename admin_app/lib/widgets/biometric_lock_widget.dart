import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class BiometricLockWidget extends StatelessWidget {
  final Widget child;

  const BiometricLockWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isAuthenticated && !auth.isBiometricVerified) {
          return _LockScreen(onVerified: () => auth.authenticateWithBiometrics());
        }
        return child;
      },
    );
  }
}

class _LockScreen extends StatefulWidget {
  final Future<bool> Function() onVerified;

  const _LockScreen({required this.onVerified});

  @override
  State<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<_LockScreen> {
  bool _loading = false;

  Future<void> _verify() async {
    setState(() => _loading = true);
    final ok = await widget.onVerified();
    setState(() => _loading = false);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل التحقق البيومتري')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0A0A),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.fingerprint,
              size: 72,
              color: Color(0xFFD4AF37),
            ),
            const SizedBox(height: 24),
            const Text(
              'التحقق البيومتري مطلوب',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 32),
            _loading
                ? const CircularProgressIndicator(color: Color(0xFFD4AF37))
                : SizedBox(
                    width: 200,
                    height: 48,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFD4AF37)),
                      ),
                      child: TextButton(
                        onPressed: _verify,
                        child: const Text(
                          'تحقق الآن',
                          style: TextStyle(color: Color(0xFFD4AF37)),
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
