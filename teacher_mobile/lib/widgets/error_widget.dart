import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';

class AppErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const AppErrorWidget({
    super.key,
    this.message = 'حدث خطأ أثناء تحميل البيانات',
    this.onRetry,
  });

  bool get _isAuthError => message.contains('يجب تسجيل الدخول') ||
      message.contains('Invalid') ||
      message.contains('token');

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isAuthError ? Icons.lock_outline : Icons.error_outline,
              size: 64,
              color: _isAuthError ? const Color(0xFFf59e0b) : const Color(0xFFdc2626),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 20),
            if (_isAuthError)
              ElevatedButton.icon(
                onPressed: () {
                  Provider.of<AuthProvider>(context, listen: false).logout();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.login),
                label: const Text('تسجيل الدخول'),
              )
            else if (onRetry != null)
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
          ],
        ),
      ),
    );
  }
}
