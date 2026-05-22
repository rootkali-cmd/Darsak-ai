import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _codeController = TextEditingController();
  final _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _pinController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      _codeController.text.trim(),
      _pinController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'خطأ في تسجيل الدخول'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.school, color: Colors.white, size: 40),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'تسجيل دخول الطالب',
                        style: TextStyle(
                          color: Color(0xFFF5F5F5),
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'أدخل كود الطالب ورقم PIN السري',
                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
                      ),
                      const SizedBox(height: 40),
                      TextFormField(
                        controller: _codeController,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFF5F5F5),
                          fontSize: 18,
                          letterSpacing: 2,
                        ),
                        decoration: InputDecoration(
                          labelText: 'كود الطالب',
                          hintText: 'STU-001',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          prefixIcon: const Icon(Icons.badge, color: Color(0xFF2563EB)),
                          filled: true,
                          fillColor: const Color(0xFF141414),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF2563EB)),
                          ),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (v) => v == null || v.trim().isEmpty ? 'أدخل كود الطالب' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _pinController,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.center,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        style: const TextStyle(
                          color: Color(0xFFF5F5F5),
                          fontSize: 24,
                          letterSpacing: 8,
                        ),
                        decoration: InputDecoration(
                          labelText: 'PIN',
                          hintText: '****',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          prefixIcon: const Icon(Icons.lock, color: Color(0xFF2563EB)),
                          filled: true,
                          fillColor: const Color(0xFF141414),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF2563EB)),
                          ),
                          counterText: '',
                        ),
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _login(),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'أدخل PIN';
                          if (v.trim().length != 4) return 'PIN يجب أن يكون 4 أرقام';
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            disabledBackgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.3),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('تسجيل الدخول', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
