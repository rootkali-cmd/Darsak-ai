import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../core/app_theme.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import 'login_screen.dart';
import 'onboarding/onboarding_screen.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showError('جميع الحقول مطلوبة');
      return;
    }
    if (!email.contains('@')) {
      _showError('بريد إلكتروني غير صالح');
      return;
    }
    if (password.length < 6) {
      _showError('كلمة المرور 6 أحرف على الأقل');
      return;
    }

    setState(() => _loading = true);
    try {
      final api = ApiService();
      final resp = await api.dio.post('/auth/register', data: {
        'full_name': name,
        'email': email,
        'password': password,
      });

      // Auto-login after register
      final auth = context.read<AuthProvider>();
      final success = await auth.login(email, password);

      if (!mounted) return;
      if (success) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          (route) => false,
        );
      } else {
        _showError('تم إنشاء الحساب. يرجى تسجيل الدخول');
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError) {
        _showError('أنت غير متصل بالإنترنت');
      } else {
        final detail = e.response?.data is Map ? (e.response!.data as Map)['detail'] : null;
        _showError(detail?.toString() ?? 'فشل إنشاء الحساب');
      }
    } catch (e) {
      _showError('حدث خطأ: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.danger));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)]),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 72, height: 72,
                  decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(18)),
                  child: const Icon(Icons.person_add, size: 36, color: AppTheme.accent)),
                const SizedBox(height: 24),
                const Text('إنشاء حساب جديد', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                const Text('أنشئ حسابك وابدأ إدارة سنترك', style: TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
                const SizedBox(height: 36),
                TextField(
                  controller: _nameCtrl, textInputAction: TextInputAction.next,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'الاسم الكامل', prefixIcon: const Icon(Icons.person),
                    filled: true, fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _emailCtrl, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'البريد الإلكتروني', prefixIcon: const Icon(Icons.email),
                    filled: true, fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passwordCtrl, obscureText: _obscure, textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _register(),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور', prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: AppTheme.textSecondary), onPressed: () => setState(() => _obscure = !_obscure)),
                    filled: true, fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _register,
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: _loading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text('إنشاء الحساب', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('لديك حساب؟ ', style: TextStyle(color: AppTheme.textSecondary)),
                  GestureDetector(
                    onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                    child: const Text('تسجيل الدخول', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
